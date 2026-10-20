-- Changes view owns the fixed left window while the model and renderer own its rows.

local M = {}

local debounce = require("gleb.util.debounce")
local workspace = require("gleb.workspace")
local git = require("gleb.git.changes.git")
local model = require("gleb.git.changes.model")
local render = require("gleb.git.changes.render")
local tabs = require("gleb.git.changes.tabs")
local settings = require("gleb.tree.settings")
local watch = require("gleb.tree.watch")
local windows = require("gleb.tree.windows")
local tree_model = require("gleb.ui.tree.model")
local tree_view = require("gleb.ui.tree.view")

local WIDTH = 35
local REFRESH_DEBOUNCE_MS = 50
local DIFF_DEBOUNCE_MS = 50
local forget
local cleanup
local request_diff
local augroup = vim.api.nvim_create_augroup("gleb_changes", { clear = true })

---@class ChangesView
---@field tab integer
---@field root string
---@field buf integer
---@field win integer
---@field editor_win integer
---@field rows ChangesRow[]
---@field all_rows ChangesRow[]
---@field tree gleb.ui.tree.Model
---@field timer uv.uv_timer_t
---@field diff_timer uv.uv_timer_t
---@field generation integer
---@field selection_generation integer
---@field autocmds integer[]
---@field diff_view? gleb.diff.view.View
---@field diff_path? string
---@field diff_pending_path? string
---@field initial_selected_path? string
---@field review_on_refresh boolean
---@field loaded_buffers table<integer, boolean>
---@field active_tab string
---@field local_count integer
---@field branch_count integer
---@field branch_available boolean
---@field branch_request integer

---@param buf integer
---@return nil
local function configure_buffer(buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	vim.bo[buf].filetype = "gleb-changes"
end

---@param win integer
---@return nil
local function configure_window(win)
	vim.wo[win].winfixwidth = true
	vim.wo[win].cursorline = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].foldenable = false
	vim.wo[win].statuscolumn = ""
	vim.wo[win].wrap = false
	vim.wo[win].list = false
	vim.wo[win].spell = false
	vim.wo[win].winhighlight =
		"Normal:FileTreeNormal,CursorLine:FileTreeCursorLine,EndOfBuffer:FileTreeNormal,WinBar:FileTreeNormal,WinBarNC:FileTreeNormal"
	vim.api.nvim_win_set_width(win, WIDTH)
end

---@param text string
---@return string
local function statusline_escape(text)
	return (text:gsub("%%", "%%%%"))
end

---@param view ChangesView
---@return nil
local function draw_tabs(view)
	local parts = { " " }
	---@type gleb.git.changes.TabView
	local tab_view = {
		local_count = view.local_count,
		branch_count = view.branch_count,
		branch_available = view.branch_available,
	}
	for _, tab in ipairs(tabs.items) do
		if tab.available(tab_view) then
			local group = tab.id == view.active_tab and tab.group or "ChangesTabInactive"
			parts[#parts + 1] =
				string.format("%%#%s# %s %d %%* ", group, statusline_escape(tab.title), tab.count(tab_view))
		end
	end
	vim.wo[view.win].winbar = table.concat(parts):sub(1, -2)
end

---@param view ChangesView
---@param merge_base string
---@return nil
local function load_branch_count(view, merge_base)
	view.branch_request = view.branch_request + 1
	local request = view.branch_request
	vim.system({ "git", "diff", "--name-only", "-z", "-M", merge_base, "HEAD" }, {
		cwd = view.root,
		text = true,
	}, function(result)
		vim.schedule(function()
			local changes = require("gleb.git.changes")
			if changes.state.by_tab[view.tab] ~= view or request ~= view.branch_request then
				return
			end
			view.branch_count = result.code == 0
					and #vim.split(result.stdout or "", "\0", { plain = true, trimempty = true })
				or 0
			view.branch_available = true
			draw_tabs(view)
		end)
	end)
end

---@param view ChangesView
---@return nil
local function resolve_tabs(view)
	require("gleb.git.base").resolve(view.root, function(info)
		if require("gleb.git.changes").state.by_tab[view.tab] ~= view then
			return
		end
		view.branch_request = view.branch_request + 1
		view.branch_available = false
		view.branch_count = 0
		draw_tabs(view)
		if info then
			load_branch_count(view, info.merge_base)
		end
	end)
end

---@param view ChangesView
---@param selected_path string
---@return nil
local function select_file(view, selected_path)
	local selected_relative = selected_path ~= "" and selected_path:sub(#view.root + 2) or ""
	local first_file
	for index, row in ipairs(view.rows) do
		if row.kind == "file" then
			first_file = first_file or index
			if row.path == selected_relative then
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return
			end
		end
	end
	if first_file then
		vim.api.nvim_win_set_cursor(view.win, { first_file, 0 })
	end
end

---@param row ChangesRow?
---@return string?
local function row_key(row)
	if not row then
		return nil
	end
	return row.root .. ":" .. (row.path or row.fold_id or row.label)
end

---@param rows ChangesRow[]
---@return gleb.ui.tree.Node[]
local function tree_nodes(rows)
	local roots = {}
	local parents = {}
	for _, row in ipairs(rows) do
		local node = {
			id = assert(row_key(row)),
			children = {},
			foldable = row.fold_id ~= nil,
			open_by_default = true,
			data = row,
		}
		local parent = parents[row.depth - 1]
		if parent then
			parent.children[#parent.children + 1] = node
		else
			roots[#roots + 1] = node
		end
		parents[row.depth] = node
		for depth = row.depth + 1, #parents do
			parents[depth] = nil
		end
	end
	return roots
end

---@param view ChangesView
---@param selected_key string?
---@return nil
local function draw(view, selected_key)
	tree_view.draw(view.tree, function(buf, rows)
		local visible = {}
		for _, tree_row in ipairs(rows) do
			local row = tree_row.node.data
			if tree_row.node.foldable then
				row.expanded = not view.tree.folds[tree_row.id]
			else
				row.expanded = nil
			end
			visible[#visible + 1] = row
		end
		view.rows = visible
		render.draw(buf, visible, WIDTH)
	end, selected_key)
end

---@param view ChangesView
---@return nil
local function refresh_now(view)
	local changes = require("gleb.git.changes")
	if changes.state.by_tab[view.tab] ~= view then
		return
	end
	view.generation = view.generation + 1
	local generation = view.generation
	git.refresh(view.root, function(result, numstat_z)
		if
			changes.state.by_tab[view.tab] ~= view
			or generation ~= view.generation
			or not vim.api.nvim_buf_is_valid(view.buf)
		then
			return
		end
		if result.code ~= 0 then
			vim.notify("Git status failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			return
		end
		local current = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
		view.all_rows = model.rows(result.stdout or "", settings.load().nesting.rules, numstat_z)
		view.local_count = vim.iter(view.all_rows)
			:filter(function(row)
				return row.kind == "file"
			end)
			:fold(0, function(count)
				return count + 1
			end)
		tree_model.rebuild(view.tree, tree_nodes(view.all_rows))
		draw(view, row_key(current))
		draw_tabs(view)
		if view.initial_selected_path then
			select_file(view, view.initial_selected_path)
			view.initial_selected_path = nil
		end
		if view.review_on_refresh then
			view.review_on_refresh = false
			request_diff(view, view.rows[vim.api.nvim_win_get_cursor(view.win)[1]], false)
		end
	end)
end

---@param view ChangesView
---@return nil
function M.schedule_refresh(view)
	view.timer = debounce.schedule(view.timer, REFRESH_DEBOUNCE_MS, function()
		refresh_now(view)
	end)
end

---@param view ChangesView
---@return nil
local function refresh_from_git_dir(view)
	M.schedule_refresh(view)
	if view.diff_view then
		require("gleb.diff.view").refresh_index(view.diff_view)
	end
end

---@param buf integer
---@return nil
local function unload_clean_buffer(buf)
	if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and not vim.bo[buf].modified then
		vim.api.nvim_buf_delete(buf, { unload = true })
	end
end

--- Reload the selected row after a refresh outdated its in-flight diff.
---@param view ChangesView
---@param focus_right boolean
---@return nil
local function reload_outdated_diff(view, focus_right)
	request_diff(view, view.rows[vim.api.nvim_win_get_cursor(view.win)[1]], focus_right)
end

---@param view ChangesView
---@param row ChangesRow
---@param generation integer
---@param selection_generation integer
---@param focus_right boolean
---@return nil
local function show_diff(view, row, generation, selection_generation, focus_right)
	git.load_diff(view.root, row, function(spec, loaded_buf)
		local changes = require("gleb.git.changes")
		local selected = changes.state.by_tab[view.tab] == view
			and selection_generation == view.selection_generation
			and vim.api.nvim_win_is_valid(view.win)
		if not selected or generation ~= view.generation then
			if loaded_buf then
				unload_clean_buffer(loaded_buf)
			end
			if selected then
				view.diff_pending_path = nil
				reload_outdated_diff(view, focus_right)
			end
			return
		end
		if loaded_buf then
			view.loaded_buffers[loaded_buf] = true
		end
		local diff = require("gleb.diff.view")
		local editor = windows.eligible_editor(view, true)
		view.editor_win = editor
		spec.on_next_file = function()
			M.next_file(view)
		end
		local shown = diff.show(editor, spec)
		view.diff_pending_path = nil
		if not shown then
			if view.diff_view then
				diff.close(view.diff_view)
			end
			view.diff_view = nil
			view.diff_path = nil
			vim.notify("No content changes: " .. row.label, vim.log.levels.INFO)
			return
		end
		view.diff_view = shown
		view.diff_path = row.path
		if focus_right and vim.api.nvim_win_is_valid(shown.right_win) then
			vim.api.nvim_set_current_win(shown.right_win)
		end
	end)
end

---@param view ChangesView
---@param row ChangesRow?
---@param focus_right boolean
---@return nil
request_diff = function(view, row, focus_right)
	if not row or row.kind ~= "file" then
		return
	end
	if not row.diffable then
		vim.notify("No file content: " .. row.label, vim.log.levels.INFO)
		return
	end
	if row.path == view.diff_pending_path then
		return
	end
	if row.path == view.diff_path then
		if focus_right and view.diff_view and vim.api.nvim_win_is_valid(view.diff_view.right_win) then
			vim.api.nvim_set_current_win(view.diff_view.right_win)
		end
		return
	end
	view.selection_generation = view.selection_generation + 1
	view.diff_pending_path = row.path
	show_diff(view, row, view.generation, view.selection_generation, focus_right)
end

--- Drop an in-flight diff once the cursor leaves its row: waiting for the debounce
--- would let the stale load land and replace a view showing the same path.
---@param view ChangesView
---@param row ChangesRow?
---@return nil
local function drop_pending_diff(view, row)
	if view.diff_pending_path and (not row or row.path ~= view.diff_pending_path) then
		view.selection_generation = view.selection_generation + 1
		view.diff_pending_path = nil
	end
end

---@param view ChangesView
---@return nil
local function schedule_diff(view)
	local row = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
	drop_pending_diff(view, row)
	view.diff_timer = debounce.schedule(view.diff_timer, DIFF_DEBOUNCE_MS, function()
		if not vim.api.nvim_win_is_valid(view.win) then
			return
		end
		request_diff(view, row, false)
	end)
end

---@param tab integer
---@return integer
local function eligible_editor_count(tab)
	return vim.iter(vim.api.nvim_tabpage_list_wins(tab)):fold(0, function(count, win)
		return count + (windows.is_eligible_editor(win) and 1 or 0)
	end)
end

---@param view ChangesView
---@return nil
local function close_if_orphaned(view)
	local changes = require("gleb.git.changes")
	if
		vim.api.nvim_tabpage_is_valid(view.tab)
		and changes.state.by_tab[view.tab] == view
		and eligible_editor_count(view.tab) == 0
	then
		M.close(view)
	end
end

---@param view ChangesView
---@return nil
local function schedule_orphan_check(view)
	vim.schedule(function()
		close_if_orphaned(view)
	end)
end

---@param view ChangesView
---@return nil
local function close_before_last_editor(view)
	if
		vim.api.nvim_get_current_tabpage() == view.tab
		and windows.is_eligible_editor(vim.api.nvim_get_current_win())
		and eligible_editor_count(view.tab) == 1
	then
		M.close(view)
	end
end

---@param view ChangesView
---@return nil
local function add_refresh_sources(view)
	view.autocmds[#view.autocmds + 1] = vim.api.nvim_create_autocmd("CursorMoved", {
		group = augroup,
		buffer = view.buf,
		callback = function()
			schedule_diff(view)
		end,
	})
	view.autocmds[#view.autocmds + 1] = vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function(args)
			local path = workspace.normalize(vim.api.nvim_buf_get_name(args.buf))
			if path:sub(1, #view.root + 1) == view.root .. "/" then
				M.schedule_refresh(view)
			end
		end,
	})
	view.autocmds[#view.autocmds + 1] = vim.api.nvim_create_autocmd("FocusGained", {
		group = augroup,
		callback = function()
			M.schedule_refresh(view)
		end,
	})
	view.autocmds[#view.autocmds + 1] = vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		pattern = tostring(view.win),
		once = true,
		callback = function()
			M.close(view)
		end,
	})
	view.autocmds[#view.autocmds + 1] = vim.api.nvim_create_autocmd("QuitPre", {
		group = augroup,
		callback = function()
			close_before_last_editor(view)
		end,
	})
	view.autocmds[#view.autocmds + 1] = vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		callback = function()
			schedule_orphan_check(view)
		end,
	})
	watch.start_root(view.root, view.buf)
	watch.sync(view.root, view.buf, {}, function() end, function()
		refresh_from_git_dir(view)
	end)
end

---@param view ChangesView
---@return nil
forget = function(view)
	local changes = require("gleb.git.changes")
	if changes.state.by_tab[view.tab] == view then
		changes.state.by_tab[view.tab] = nil
	end
end

---@param view ChangesView
---@return nil
cleanup = function(view)
	forget(view)
	if not view.timer:is_closing() then
		view.timer:stop()
		view.timer:close()
	end
	if not view.diff_timer:is_closing() then
		view.diff_timer:stop()
		view.diff_timer:close()
	end
	watch.stop_root(view.root, view.buf)
	for _, autocmd in ipairs(view.autocmds) do
		pcall(vim.api.nvim_del_autocmd, autocmd)
	end
	view.autocmds = {}
end

--- Close one Changes view.
---@param view ChangesView
---@return nil
function M.close(view)
	cleanup(view)
	if view.diff_view then
		require("gleb.diff.view").close(view.diff_view)
		view.diff_view = nil
		view.diff_path = nil
		view.diff_pending_path = nil
	end
	for buf in pairs(view.loaded_buffers) do
		unload_clean_buffer(buf)
	end
	view.loaded_buffers = {}
	if vim.api.nvim_win_is_valid(view.win) and #vim.api.nvim_tabpage_list_wins(view.tab) == 1 then
		view.editor_win = windows.eligible_editor(view)
	end
	if vim.api.nvim_win_is_valid(view.editor_win) then
		vim.api.nvim_set_current_win(view.editor_win)
	end
	if vim.api.nvim_win_is_valid(view.win) then
		vim.api.nvim_win_close(view.win, true)
	end
	if vim.api.nvim_buf_is_valid(view.buf) then
		vim.api.nvim_buf_delete(view.buf, { force = true })
	end
end

--- Close the panel-owned diff and edit a file in the editor window.
---@param view ChangesView
---@param row ChangesRow
---@return nil
function M.open_file(view, row)
	if not row.path or not row.diffable then
		return
	end
	if view.diff_view then
		require("gleb.diff.view").close(view.diff_view)
		view.diff_view = nil
		view.diff_path = nil
	end
	local editor = windows.eligible_editor(view)
	view.editor_win = editor
	vim.api.nvim_set_current_win(editor)
	vim.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(view.root, row.path)))
	view.loaded_buffers[vim.api.nvim_get_current_buf()] = nil
end

--- Open and populate a Changes view in the current tab.
---@param root string
---@param selected_path string
---@param review? boolean
---@return ChangesView
function M.open(root, selected_path, review)
	local changes = require("gleb.git.changes")
	local tab = vim.api.nvim_get_current_tabpage()
	local editor_win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, ("gleb-changes://%s#%d"):format(root, tab))
	configure_buffer(buf)

	vim.cmd("topleft vertical " .. WIDTH .. " split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	configure_window(win)

	---@type ChangesView
	local view = {
		tab = tab,
		root = workspace.normalize(root),
		buf = buf,
		win = win,
		editor_win = editor_win,
		rows = {},
		all_rows = {},
		tree = tree_model.new({}),
		timer = assert(vim.uv.new_timer()),
		diff_timer = assert(vim.uv.new_timer()),
		generation = 0,
		selection_generation = 0,
		autocmds = {},
		loaded_buffers = {},
		initial_selected_path = workspace.normalize(selected_path),
		review_on_refresh = review == true,
		active_tab = "local",
		local_count = 0,
		branch_count = 0,
		branch_available = false,
		branch_request = 0,
	}
	tree_view.attach(buf, view.tree, {
		fallback = function()
			select_file(view, "")
		end,
	})
	changes.state.by_tab[tab] = view
	add_refresh_sources(view)
	draw_tabs(view)
	resolve_tabs(view)
	refresh_now(view)
	return view
end

--- Focus a Changes panel and show its selected file without debounce.
---@param view ChangesView
---@return nil
function M.review(view)
	vim.api.nvim_set_current_win(view.win)
	request_diff(view, view.rows[vim.api.nvim_win_get_cursor(view.win)[1]], false)
end

--- Move a panel-owned diff to the next diffable file.
---@param view ChangesView
---@return nil
function M.next_file(view)
	if require("gleb.git.changes").state.by_tab[view.tab] ~= view or not vim.api.nvim_win_is_valid(view.win) then
		return
	end
	local current_win = vim.api.nvim_get_current_win()
	local diff_view = view.diff_view
	local focus_right = diff_view ~= nil and (current_win == diff_view.left_win or current_win == diff_view.right_win)
	local current_row = vim.api.nvim_win_get_cursor(view.win)[1]
	for index = current_row + 1, #view.rows do
		local row = view.rows[index]
		if row.kind == "file" and row.diffable then
			view.diff_timer:stop()
			vim.api.nvim_win_set_cursor(view.win, { index, 0 })
			request_diff(view, row, focus_right)
			return
		end
	end
end

--- Toggle the fold under the panel cursor.
---@param view ChangesView
---@return nil
function M.toggle_fold(view)
	require("gleb.ui.tree").toggle(view.tree)
end

return M
