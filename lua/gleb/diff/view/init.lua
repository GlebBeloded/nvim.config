-- Public API and state for the owned two-side diff view.
-- Source comparison happens before opening windows so empty/error branches leave the editor untouched.

local engine = require("gleb.diff.engine")
local layout = require("gleb.diff.view.layout")
local patch = require("gleb.diff.patch")
local render = require("gleb.diff.view.render")
local settings = require("gleb.diff.settings").load()
local stage = require("gleb.diff.stage")
local windows = require("gleb.diff.view.windows")

---@type table<gleb.diff.view.View, { cursor?: { win: integer, line: integer, col: integer }, scroll?: { win: integer, topline: integer, topfill: integer, leftcol: integer } }>
local sync_states = setmetatable({}, { __mode = "k" })

local M = {
	config = {
		context = 4,
		debounce_ms = 150,
		timeout_ms = 1000,
		policy = settings.policy,
		highlight = settings.highlight,
	},
	state = {
		by_path = {},
		by_win = {},
	},
}

---@class gleb.diff.view.Spec
---@field path string
---@field left string[]
---@field right string[]
---@field labels { left: string, right: string }
---@field right_buf? integer
---@field relpath? string
---@field root? string
---@field filetype? string
---@field actionable? boolean
---@field head_final_newline? boolean
---@field on_next_file? function

---@class gleb.diff.view.View
---@field path string
---@field relpath string
---@field root? string
---@field left string[]
---@field right string[]
---@field labels { left: string, right: string }
---@field filetype string
---@field actionable boolean
---@field head_final_newline boolean
---@field right_buf integer
---@field left_buf integer
---@field left_win integer
---@field right_win integer
---@field tab integer
---@field augroup integer
---@field ns integer
---@field fragments gleb.diff.LineFragment[]
---@field action_fragments gleb.diff.LineFragment[]
---@field moves gleb.diff.Move[]
---@field layout gleb.diff.view.Layout
---@field on_next_file? function
---@field owns_tab boolean
---@field origin_win integer
---@field right_restore? { buf: integer, options: table<string, unknown> }
---@field mappings? table<integer, { lhs: string, previous: table }[]>
---@field closing? boolean
---@field approximate? boolean
---@field index? gleb.diff.Index
---@field syncing? boolean
---@field timer? uv.uv_timer_t
---@field changedtick integer
---@field attached? boolean
---@field ufo_attached? boolean

---@param lines string[]
---@return integer
local function readonly_buffer(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	return buf
end

---@param lhs string
---@param previous table
local function replay_mapping(lhs, previous)
	if next(previous) == nil then
		local count = vim.v.count > 0 and tostring(vim.v.count) or ""
		vim.api.nvim_feedkeys(vim.keycode(count .. lhs), "n", false)
		return
	end
	if previous.callback then
		local result = previous.callback()
		if previous.expr == 1 and type(result) == "string" then
			vim.api.nvim_feedkeys(vim.keycode(result), previous.noremap == 1 and "n" or "m", false)
		end
		return
	end
	local count = vim.v.count > 0 and tostring(vim.v.count) or ""
	vim.api.nvim_feedkeys(vim.keycode(count .. previous.rhs), previous.noremap == 1 and "n" or "m", false)
end

---@param view gleb.diff.view.View
local function set_mappings(view)
	local actions = require("gleb.actions")
	local adapter = require("gleb.actions.adapters.gleb_diff")
	local catalog = assert(actions.state.applicator, "actions are not set up").catalog
	local shortcuts = assert(actions.state.store, "actions are not set up").last_good
	local mappings = adapter.mappings(catalog, shortcuts)
	view.mappings = {}
	for _, buf in ipairs({ view.left_buf, view.right_buf }) do
		local saved = {}
		view.mappings[buf] = saved
		vim.api.nvim_buf_call(buf, function()
			for lhs, mapping in pairs(mappings) do
				local previous = vim.fn.maparg(lhs, "n", false, true)
				local is_leader = vim.keycode(lhs) == vim.g.mapleader
				table.insert(saved, { lhs = lhs, previous = previous })
				vim.keymap.set("n", lhs, function()
					if M.state.by_win[vim.api.nvim_get_current_win()] == view then
						mapping.callback()
					else
						replay_mapping(lhs, previous)
					end
				end, {
					buffer = buf,
					desc = mapping.desc,
					nowait = not is_leader,
					silent = true,
				})
			end
		end)
	end
end

---@param left string[]
---@param right string[]
---@return gleb.diff.Result
local function compare(left, right)
	return engine.compare_lines(left, right, {
		policy = M.config.policy,
		highlight = M.config.highlight,
		moves = true,
		limits = { timeout_ms = M.config.timeout_ms },
	})
end

---@param left string[]
---@param right string[]
---@return gleb.diff.Result
local function compare_default(left, right)
	return engine.compare_lines(left, right, {
		policy = "default",
		highlight = "by_line",
		limits = { timeout_ms = M.config.timeout_ms },
	})
end

---@param view gleb.diff.view.View
---@param fragments gleb.diff.LineFragment[]
---@param right string[]
---@return string[]?
local function checkbox_states(view, fragments, right)
	if not view.index then
		return nil
	end
	return patch.states(view.left, view.index.lines, right, fragments)
end

---@param displayed gleb.diff.LineFragment[]
---@param actionable gleb.diff.LineFragment[]
---@param states string[]?
---@return string[]?
local function displayed_states(displayed, actionable, states)
	if not states then
		return nil
	end
	local result = {}
	local function ranges_overlap(start1, end1, start2, end2)
		if start1 == end1 then
			return start2 <= start1 and start1 <= end2
		end
		if start2 == end2 then
			return start1 <= start2 and start2 <= end1
		end
		return start1 < end2 and start2 < end1
	end
	local function fragments_overlap(first, second)
		return ranges_overlap(first.start1, first.end1, second.start1, second.end1)
			and ranges_overlap(first.start2, first.end2, second.start2, second.end2)
	end
	for display_index, fragment in ipairs(displayed) do
		for action_index, action in ipairs(actionable) do
			if fragments_overlap(fragment, action) then
				local state = states[action_index]
				if result[display_index] and result[display_index] ~= state then
					result[display_index] = "󰡖"
					break
				end
				result[display_index] = state
			end
		end
	end
	return result
end

---@param view gleb.diff.view.View
---@return { start: integer, finish: integer }[]
local function open_fold_ranges(view)
	if not vim.api.nvim_win_is_valid(view.right_win) then
		return {}
	end
	return vim.api.nvim_win_call(view.right_win, function()
		local ranges = {}
		for _, fold in ipairs(view.layout.folds) do
			if vim.fn.foldclosed(fold.start2) == -1 then
				ranges[#ranges + 1] = { start = fold.start2, finish = fold.end2 }
			end
		end
		return ranges
	end)
end

---@param view gleb.diff.view.View
local function redraw(view)
	if view.closing or not vim.api.nvim_buf_is_valid(view.right_buf) then
		return
	end
	local open_ranges = open_fold_ranges(view)
	local right = vim.api.nvim_buf_get_lines(view.right_buf, 0, -1, false)
	local comparison = compare(view.left, right)
	local action_comparison = compare_default(view.left, right)
	view.right = right
	view.changedtick = vim.api.nvim_buf_get_changedtick(view.right_buf)
	view.fragments = comparison.fragments
	view.action_fragments = action_comparison.fragments
	view.moves = comparison.moves
	view.layout = layout.build(
		comparison.fragments,
		#view.left,
		#right,
		M.config.context,
		displayed_states(
			comparison.fragments,
			action_comparison.fragments,
			checkbox_states(view, action_comparison.fragments, right)
		),
		comparison.moves
	)
	view.approximate = comparison.too_big or comparison.timed_out
	render.draw(view)
	windows.add_folds(view, open_ranges)
	windows.update_labels(view)
end

---@param view gleb.diff.view.View
local function redraw_now(view)
	if view.timer then
		view.timer:stop()
	end
	redraw(view)
end

---@param view gleb.diff.view.View
local function refresh_before_action(view)
	local redraw_pending = view.timer and view.timer:is_active()
	if redraw_pending or view.changedtick ~= vim.api.nvim_buf_get_changedtick(view.right_buf) then
		redraw_now(view)
	end
end

---@param view gleb.diff.view.View
local function refresh_index(view)
	if not view.root then
		return
	end
	local current = stage.read(view.root, view.relpath)
	if current then
		view.index = current
		redraw_now(view)
	end
end

---@param view gleb.diff.view.View
local function schedule_redraw(view)
	if view.closing then
		return
	end
	view.timer = view.timer or assert(vim.uv.new_timer())
	view.timer:stop()
	view.timer:start(M.config.debounce_ms, 0, function()
		vim.schedule(function()
			redraw(view)
		end)
	end)
end

---@param view gleb.diff.view.View
local function attach(view)
	local function on_lines()
		if view.closing then
			return true
		end
		schedule_redraw(view)
	end
	local function on_detach()
		view.attached = false
	end
	view.attached = vim.api.nvim_buf_attach(view.right_buf, false, {
		on_lines = on_lines,
		on_detach = on_detach,
	})
end

---@param view gleb.diff.view.View
---@param source_win integer
local function sync_windows(view, source_win)
	if view.syncing or not vim.api.nvim_win_is_valid(source_win) then
		return
	end
	local source_side = source_win == view.left_win and "left" or "right"
	local peer_win = source_side == "left" and view.right_win or view.left_win
	if not vim.api.nvim_win_is_valid(peer_win) then
		return
	end
	local source_view = vim.api.nvim_win_call(source_win, vim.fn.winsaveview)
	local source_cursor = vim.api.nvim_win_get_cursor(source_win)
	local peer_line = layout.transfer_line(view.layout, source_side, source_cursor[1])
	local peer_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(peer_win))
	local peer_topline = layout.transfer_line(view.layout, source_side, source_view.topline)
	peer_line = math.min(math.max(peer_line, 1), peer_count)
	local state = sync_states[view] or {}
	sync_states[view] = state

	view.syncing = true
	local peer_cursor = vim.api.nvim_win_get_cursor(peer_win)
	if peer_cursor[1] ~= peer_line or peer_cursor[2] ~= source_cursor[2] then
		state.cursor = { win = peer_win, line = peer_line, col = source_cursor[2] }
		vim.api.nvim_win_set_cursor(peer_win, { peer_line, source_cursor[2] })
	end
	local target_topline = math.min(math.max(peer_topline, 1), peer_count)
	state.scroll = {
		win = peer_win,
		topline = target_topline,
		topfill = source_view.topfill,
		leftcol = source_view.leftcol,
	}
	vim.api.nvim_win_call(peer_win, function()
		vim.fn.winrestview({
			topline = target_topline,
			topfill = source_view.topfill,
			leftcol = source_view.leftcol,
		})
	end)
	view.syncing = false
end

---@param args vim.api.keyset.create_autocmd.callback_args
local function on_scrolled(args)
	local win = tonumber(args.match) --[[@as integer?]]
	if not win then
		return
	end
	local view = M.state.by_win[win]
	if view then
		local state = sync_states[view]
		local synced = state and state.scroll or nil
		if synced and synced.win == win then
			local actual = vim.api.nvim_win_call(win, vim.fn.winsaveview)
			state.scroll = nil
			if
				synced.topline == actual.topline
				and synced.topfill == actual.topfill
				and synced.leftcol == actual.leftcol
			then
				return
			end
		end
		sync_windows(view, win)
	end
end

local function on_cursor_moved()
	local win = vim.api.nvim_get_current_win()
	local view = M.state.by_win[win]
	if view then
		local cursor = vim.api.nvim_win_get_cursor(win)
		local state = sync_states[view]
		local synced = state and state.cursor or nil
		if synced and synced.win == win and synced.line == cursor[1] and synced.col == cursor[2] then
			state.cursor = nil
			return
		end
		if synced and synced.win == win then
			state.cursor = nil
		end
		sync_windows(view, win)
	end
end

---@param view gleb.diff.view.View
local function create_interaction_autocmds(view)
	vim.api.nvim_create_autocmd("WinScrolled", {
		group = view.augroup,
		pattern = { tostring(view.left_win), tostring(view.right_win) },
		callback = on_scrolled,
	})
	for _, buf in ipairs({ view.left_buf, view.right_buf }) do
		vim.api.nvim_create_autocmd("CursorMoved", {
			group = view.augroup,
			buffer = buf,
			callback = on_cursor_moved,
		})
	end
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = view.augroup,
		buffer = view.right_buf,
		callback = function()
			schedule_redraw(view)
		end,
	})
	vim.api.nvim_create_autocmd("FocusGained", {
		group = view.augroup,
		callback = function()
			refresh_index(view)
		end,
	})
end

---@param view gleb.diff.view.View
local function register(view)
	M.state.by_path[view.path] = view
	M.state.by_win[view.left_win] = view
	M.state.by_win[view.right_win] = view
	set_mappings(view)
	render.draw(view)
	create_interaction_autocmds(view)
	attach(view)
end

---@param spec gleb.diff.view.Spec
---@return gleb.diff.view.View?
local function build(spec)
	local comparison = compare(spec.left, spec.right)
	local action_comparison = compare_default(spec.left, spec.right)
	if #action_comparison.fragments == 0 then
		return nil
	end
	local path = vim.fs.normalize(spec.path)
	local relpath = spec.relpath or vim.fs.basename(path)
	local index = spec.root and stage.read(spec.root, relpath) or nil
	local right_buf = spec.right_buf or readonly_buffer(spec.right)
	---@type gleb.diff.view.View
	---@diagnostic disable-next-line: missing-fields -- windows initializes the handles as one lifecycle step.
	local view = {
		path = path,
		relpath = relpath,
		root = spec.root,
		left = spec.left,
		right = spec.right,
		labels = spec.labels,
		filetype = spec.filetype or "",
		actionable = spec.actionable ~= false,
		head_final_newline = spec.head_final_newline == true,
		right_buf = right_buf,
		on_next_file = spec.on_next_file,
		ns = vim.api.nvim_create_namespace(""),
		fragments = comparison.fragments,
		action_fragments = action_comparison.fragments,
		moves = comparison.moves,
		index = index,
		changedtick = vim.api.nvim_buf_get_changedtick(right_buf),
		approximate = comparison.too_big or comparison.timed_out,
		syncing = false,
	}
	view.layout = layout.build(
		comparison.fragments,
		#spec.left,
		#spec.right,
		M.config.context,
		displayed_states(
			comparison.fragments,
			action_comparison.fragments,
			checkbox_states(view, action_comparison.fragments, spec.right)
		),
		comparison.moves
	)
	return view
end

---@param view gleb.diff.view.View
---@param win integer
function M.jump_move(view, win)
	local side = win == view.left_win and "left" or "right"
	local line = vim.api.nvim_win_get_cursor(win)[1] - 1
	local start_key = side == "left" and "start1" or "start2"
	local end_key = side == "left" and "end1" or "end2"
	local target_key = side == "left" and "start2" or "start1"
	local target_win = side == "left" and view.right_win or view.left_win
	for _, move in ipairs(view.moves) do
		if line >= move[start_key] and line < move[end_key] then
			vim.api.nvim_set_current_win(target_win)
			vim.api.nvim_win_set_cursor(target_win, { move[target_key] + 1, 0 })
			return
		end
	end
end

---@param view gleb.diff.view.View
---@param win integer
function M.apply(view, win)
	if view.actionable == false then
		vim.notify("Revert unavailable: file cannot be compared with HEAD", vim.log.levels.WARN)
		return
	end
	refresh_before_action(view)
	local side = win == view.left_win and "left" or "right"
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local index = layout.change_at(view.layout, side, line)
	local fragment = index and view.fragments[index] or nil
	if not fragment then
		return
	end
	local replacement = vim.list_slice(view.left, fragment.start1 + 1, fragment.end1)
	vim.api.nvim_buf_set_lines(view.right_buf, fragment.start2, fragment.end2, false, replacement)
	redraw_now(view)
end

---@param view gleb.diff.view.View
---@param win integer
function M.toggle_include(view, win)
	if view.actionable == false then
		vim.notify("Stage unavailable: file cannot be compared with HEAD", vim.log.levels.WARN)
		return
	end
	if not view.root then
		return
	end
	refresh_before_action(view)
	local side = win == view.left_win and "left" or "right"
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local index = layout.change_at_fragments(view.action_fragments, side, line)
	local fragment = index and view.action_fragments[index] or nil
	if not fragment then
		return
	end
	local current, err = stage.read(view.root, view.relpath)
	local old_state = current and patch.state(view.left, current.lines, view.right, fragment) or nil
	local include = old_state ~= "󰄲"
	if not current then
		vim.notify((include and "Stage" or "Unstage") .. " failed: " .. (err or ""), vim.log.levels.ERROR)
		return
	end
	local new_lines, update_err = patch.update_index(view.left, current.lines, view.right, fragment, include)
	if not new_lines then
		vim.notify((include and "Stage" or "Unstage") .. " failed: " .. update_err, vim.log.levels.ERROR)
		return
	end
	local right_final_newline = vim.bo[view.right_buf].eol or vim.bo[view.right_buf].fixeol
	local new_final_newline
	if fragment.end2 == #view.right then
		if include then
			new_final_newline = right_final_newline
		else
			new_final_newline = view.head_final_newline
		end
	else
		new_final_newline = current.final_newline
	end
	local text = patch.make_patch(view.relpath, current.lines, new_lines, current.final_newline, new_final_newline)
	if stage.apply(view.root, text, include) then
		view.index = { lines = new_lines, final_newline = new_final_newline }
		redraw_now(view)
	end
end

---@param view gleb.diff.view.View
---@param source_win integer
function M.expand_fold(view, source_win)
	local source_side = source_win == view.left_win and "left" or "right"
	local source_line = vim.api.nvim_win_get_cursor(source_win)[1]
	local peer_win = source_side == "left" and view.right_win or view.left_win
	local peer_line = layout.transfer_line(view.layout, source_side, source_line)
	for _, target in ipairs({ { source_win, source_line }, { peer_win, peer_line } }) do
		vim.api.nvim_win_call(target[1], function()
			vim.cmd(("%dfoldopen"):format(target[2]))
		end)
	end
end

---@param view gleb.diff.view.View
---@param source_win integer
function M.toggle_folds(view, source_win)
	local source_side = source_win == view.left_win and "left" or "right"
	local has_closed = vim.api.nvim_win_call(source_win, function()
		for _, fold in ipairs(view.layout.folds) do
			local first = source_side == "left" and fold.start1 or fold.start2
			if vim.fn.foldclosed(first) ~= -1 then
				return true
			end
		end
		return false
	end)
	local command = has_closed and "normal! zR" or "normal! zM"
	for _, win in ipairs({ view.left_win, view.right_win }) do
		vim.api.nvim_win_call(win, function()
			vim.cmd(command)
		end)
	end
end

---@param view gleb.diff.view.View
---@param win integer
---@param step -1|1
function M.navigate(view, win, step)
	local side = win == view.left_win and "left" or "right"
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local index = layout.change_at_line(view.layout, side, line)
	if index then
		index = index + step
	else
		local start_key = side == "left" and "start1" or "start2"
		for candidate, fragment in ipairs(view.fragments) do
			local target = fragment[start_key] + 1
			if (step == 1 and target > line) or (step == -1 and target < line) then
				index = candidate
				if step == 1 then
					break
				end
			end
		end
	end
	local fragment = index and view.fragments[index] or nil
	if not fragment then
		return
	end
	local start_key = side == "left" and "start1" or "start2"
	local count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
	vim.api.nvim_win_set_cursor(win, { math.min(fragment[start_key] + 1, count), 0 })
end

---@param spec gleb.diff.view.Spec
---@return gleb.diff.view.View?
function M.open(spec)
	local path = vim.fs.normalize(spec.path)
	local existing = M.state.by_path[path]
	if existing and vim.api.nvim_tabpage_is_valid(existing.tab) then
		vim.api.nvim_set_current_tabpage(existing.tab)
		vim.api.nvim_set_current_win(existing.right_win)
		return existing
	end

	local view = build(spec)
	if not view then
		return nil
	end
	windows.open(view)
	register(view)
	local first = view.fragments[1]
	if first then
		local line = math.min(first.start2 + 1, math.max(#spec.right, 1))
		vim.api.nvim_win_set_cursor(view.right_win, { line, 0 })
	end
	return view
end

---@param win integer
---@param spec gleb.diff.view.Spec
---@return gleb.diff.view.View?
function M.show(win, spec)
	local existing = M.state.by_win[win] or M.state.by_path[vim.fs.normalize(spec.path)]
	if existing then
		M.close(existing)
	end
	local view = build(spec)
	if not view then
		return nil
	end
	windows.show(view, win)
	register(view)
	return view
end

---@param view gleb.diff.view.View
function M.close(view)
	if view.closing then
		return
	end
	view.closing = true
	M.state.by_path[view.path] = nil
	M.state.by_win[view.left_win] = nil
	M.state.by_win[view.right_win] = nil
	sync_states[view] = nil
	pcall(vim.api.nvim_del_augroup_by_id, view.augroup)

	for buf, mappings in pairs(view.mappings or {}) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_call(buf, function()
				for _, mapping in ipairs(mappings) do
					pcall(vim.keymap.del, "n", mapping.lhs, { buffer = buf })
					if next(mapping.previous) ~= nil then
						vim.fn.mapset("n", false, mapping.previous)
					end
				end
			end)
		end
	end
	for _, buf in ipairs({ view.left_buf, view.right_buf }) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_clear_namespace(buf, view.ns, 0, -1)
		end
	end
	pcall(vim.api.nvim__ns_set, view.ns, { wins = {} })
	if view.timer then
		view.timer:stop()
		view.timer:close()
	end
	view.attached = false

	if view.owns_tab and vim.api.nvim_tabpage_is_valid(view.tab) then
		vim.api.nvim_set_current_tabpage(view.tab)
		pcall(vim.cmd.tabclose)
	else
		if vim.api.nvim_win_is_valid(view.left_win) then
			pcall(vim.api.nvim_win_close, view.left_win, true)
		end
		windows.restore(view)
	end
	windows.restore_ufo(view)
	if vim.api.nvim_win_is_valid(view.origin_win) then
		vim.api.nvim_set_current_win(view.origin_win)
	end
end

---@return gleb.diff.view.View?
function M.current()
	return M.state.by_win[vim.api.nvim_get_current_win()]
end

function M.recompare_all()
	for _, view in pairs(M.state.by_path) do
		redraw_now(view)
	end
end

function M.reset()
	for _, view in pairs(M.state.by_path) do
		if vim.api.nvim_buf_is_valid(view.left_buf) then
			vim.api.nvim_buf_clear_namespace(view.left_buf, view.ns, 0, -1)
		end
		if vim.api.nvim_buf_is_valid(view.right_buf) then
			vim.api.nvim_buf_clear_namespace(view.right_buf, view.ns, 0, -1)
		end
	end
	M.state = { by_path = {}, by_win = {} }
end

return M
