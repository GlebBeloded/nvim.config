-- The project-tree view owns one left-docked window and its lifecycle per tab page.

local M = {}

local editor = require("gleb.file_tree.editor")
local expanded = require("gleb.file_tree.expanded")
local folds = require("gleb.file_tree.folds")
local fs = require("gleb.workspace")
local git = require("gleb.file_tree.git")
local ignore = require("gleb.tree.ignore")
local lifecycle = require("gleb.file_tree.lifecycle")
local model = require("gleb.file_tree.model")
local render = require("gleb.file_tree.render")
local settings = require("gleb.tree.settings")
local sidebar = require("gleb.tree.sidebar")
local state = require("gleb.file_tree.state")
local watch = require("gleb.tree.watch")
local debounce = require("gleb.util.debounce")
local ui_tree = require("gleb.ui.tree")
local tree_model = require("gleb.ui.tree.model")
local tree_view = require("gleb.ui.tree.view")

local IGNORE_WAIT_MS = 300
local INVALIDATION_WINDOW_MS = 50

---@class FileTreeView
---@field tab integer
---@field root string
---@field buf integer
---@field win integer
---@field expanded table<string, boolean>
---@field expanded_nests table<string, boolean>
---@field rows FileTreeRow[]
---@field rows_by_path table<string, integer>
---@field tree gleb.ui.tree.Model
---@field tree_watched table<string, boolean>
---@field autocmds integer[]
---@field watching boolean
---@field directory_hijacks table<integer, boolean>
---@field buffer_leave_cursor? integer[]
---@field skip_follow_buf? integer
---@field initial_draw_timer? uv.uv_timer_t
---@field dirty_timer? uv.uv_timer_t
---@field dirty boolean
---@field dirty_path? string
---@field dirty_scans table<string, boolean>
---@field git_pending boolean
---@field initializing boolean
---@field initial_source_ready boolean
---@field initial_expansions_loaded boolean

---@class FileTreeViewState
---@field by_tab table<integer, FileTreeView>
---@field last_editor_by_tab table<integer, integer>

---@type FileTreeViewState
M.state = { by_tab = {}, last_editor_by_tab = editor.state.last_editor_by_tab }

--- Return whether a window can host an editor buffer.
---@param win integer
---@return boolean
function M.is_eligible_editor(win)
	return editor.is_eligible(win)
end

--- Select an eligible editor window for a left-side tool view.
---@param view { tab: integer, win: integer }
---@param replace_dashboard? boolean
---@return integer
function M.eligible_editor(view, replace_dashboard)
	return editor.select(view, replace_dashboard)
end

---@param root string
---@param path string
---@return boolean
local function is_file_under(root, path)
	local stat = path ~= "" and vim.uv.fs_stat(path) or nil
	return stat ~= nil and stat.type == "file" and vim.startswith(path, root .. "/")
end

---@param view FileTreeView
---@param path string
---@param missing_is_root boolean
---@return string?
local function reveal_target(view, path, missing_is_root)
	if path:match("^%w+://") then
		return nil
	end
	if path == "" then
		return missing_is_root and view.root or nil
	end
	local normalized = fs.normalize(path)
	if not vim.startswith(normalized, view.root .. "/") then
		return nil
	end
	local stat = vim.uv.fs_stat(normalized)
	if not stat then
		return view.root
	end
	if stat.type == "file" and vim.startswith(normalized, view.root .. "/") then
		return normalized
	end
	return nil
end

---@param view FileTreeView
---@param path string
local function expand_to(view, path)
	if not is_file_under(view.root, path) then
		return
	end
	local directory = vim.fs.dirname(path)
	while directory ~= view.root and vim.startswith(directory, view.root .. "/") do
		view.expanded[directory:sub(#view.root + 2)] = true
		directory = vim.fs.dirname(directory)
	end
end

---@param view FileTreeView
---@param loaded_settings FileTreeSettings
---@return FileTreeRowOptions
local function row_options(view, loaded_settings)
	return {
		status = git.status(view.root),
		ignored = git.ignored(view.root),
		ignored_generation = git.ignored_generation(view.root),
		show_ignored = state.show_ignored(),
		matcher = loaded_settings.matcher,
	}
end

---@param view FileTreeView
---@param path string
---@return boolean
local function is_hidden(view, path)
	local normalized = fs.normalize(path)
	if normalized == view.root or not vim.startswith(normalized, view.root .. "/") then
		return false
	end
	local opts = row_options(view, settings.load())
	if opts.show_ignored then
		return false
	end
	local relative = normalized:sub(#view.root + 2)
	local current = ""
	local parent_ignored = false
	for part in relative:gmatch("[^/]+") do
		current = current == "" and part or current .. "/" .. part
		local stat = vim.uv.fs_stat(vim.fs.joinpath(view.root, current))
		parent_ignored = part == ".git"
			or ignore.is_ignored(
				opts.ignored,
				opts.matcher,
				current,
				stat ~= nil and stat.type == "directory",
				parent_ignored
			)
		if parent_ignored then
			return true
		end
	end
	return false
end

---@param view FileTreeView
---@param path string
---@param rows_before FileTreeRow[]
---@param cursor_line integer
local function restore_cursor(view, path, rows_before, cursor_line)
	local indices = {}
	for index, row in ipairs(view.rows) do
		indices[row.path] = index
	end
	local target = indices[path]
	if not target then
		for index = math.min(cursor_line - 1, #rows_before), 1, -1 do
			target = indices[rows_before[index].path]
			if target then
				break
			end
		end
	end
	vim.api.nvim_win_set_cursor(view.win, { target or math.min(cursor_line, math.max(#view.rows, 1)), 0 })
end

---@class FileTreePreparedDraw
---@field rows FileTreeRow[]
---@field rows_by_path table<string, integer>
---@field watched table<string, boolean>

---@param rows FileTreeRow[]
---@return table<string, integer>
local function index_rows(rows)
	local rows_by_path = {}
	for index, row in ipairs(rows) do
		rows_by_path[row.path] = index
	end
	return rows_by_path
end

---@param view FileTreeView
---@param path string
---@return FileTreePreparedDraw
local function prepare_draw(view, path)
	expand_to(view, path)
	for relative in pairs(view.expanded) do
		local stat = vim.uv.fs_stat(vim.fs.joinpath(view.root, relative))
		if not stat or stat.type ~= "directory" then
			view.expanded[relative] = nil
		end
	end
	local watched = {}
	local tree = fs.tree(view.root, function(scan_path)
		watched[scan_path] = true
	end)
	local loaded_settings = settings.load()
	local nesting_settings = loaded_settings.nesting
	local opts = row_options(view, loaded_settings)
	for relative in pairs(view.expanded_nests) do
		local parent = vim.fs.joinpath(view.root, relative)
		local stat = vim.uv.fs_stat(parent)
		if not stat or stat.type ~= "file" or not model.has_nest(tree, parent, nesting_settings, opts) then
			view.expanded_nests[relative] = nil
		end
	end
	local rows = model.rows(tree, view.expanded, opts, nesting_settings, view.expanded_nests)
	return {
		rows = rows,
		rows_by_path = index_rows(rows),
		watched = watched,
	}
end

---@param view FileTreeView
---@param watched table<string, boolean>
---@return table<string, number>
local function prioritize_watches(view, watched)
	local priorities = {}
	for scan_path in pairs(watched) do
		priorities[scan_path] = math.huge
	end
	local cursor = vim.api.nvim_win_get_cursor(view.win)[1]
	local viewport = vim.api.nvim_win_call(view.win, function()
		return { vim.fn.line("w0"), vim.fn.line("w$") }
	end)
	for index, row in ipairs(view.rows) do
		local visible_penalty = index >= viewport[1] and index <= viewport[2] and 0 or #view.rows + 1
		local priority = visible_penalty + math.abs(index - cursor)
		local scan_path = row.path
		while scan_path and vim.startswith(scan_path, view.root) do
			if priorities[scan_path] and priority < priorities[scan_path] then
				priorities[scan_path] = priority
			end
			if scan_path == view.root then
				break
			end
			scan_path = vim.fs.dirname(scan_path)
		end
	end
	return priorities
end

local schedule_dirty
local request_git

---@param view FileTreeView
local function finish_draw(view)
	watch.sync(view.root, view.tab, prioritize_watches(view, view.tree_watched), function(changed_path)
		if M.state.by_tab[view.tab] ~= view or not vim.api.nvim_buf_is_valid(view.buf) then
			return
		end
		for _, row in ipairs(view.rows) do
			if
				row.kind == "directory"
				and row.label:find("/", 1, true)
				and vim.startswith(row.path, changed_path .. "/")
			then
				view.expanded[changed_path:sub(#view.root + 2)] = true
				break
			end
		end
		schedule_dirty(view, nil, changed_path)
	end, function()
		request_git(view)
	end)
	expanded.save(view.root, view.expanded)
end

---@param view FileTreeView
---@param buf integer
---@param rows gleb.ui.tree.Row[]
local function render_tree_rows(view, buf, rows)
	folds.sync_expansions(view)
	local visible = {}
	for _, tree_row in ipairs(rows) do
		visible[#visible + 1] = tree_row.node.data
	end
	view.rows = visible
	view.rows_by_path = index_rows(visible)
	render.draw(buf, visible)
	finish_draw(view)
end

---@param view FileTreeView
---@param path string
---@param prepared? FileTreePreparedDraw
local function draw(view, path, prepared)
	local rows_before = view.rows
	local cursor_line = vim.api.nvim_win_get_cursor(view.win)[1]
	prepared = prepared or prepare_draw(view, path)
	view.tree_watched = prepared.watched
	folds.rebuild_tree(view, prepared.rows)
	tree_view.draw(view.tree, function(buf, rows)
		render_tree_rows(view, buf, rows)
	end, path)
	if not view.rows_by_path[path] then
		restore_cursor(view, path, rows_before, cursor_line)
	end
end

---@type FileTreeFoldHooks
local fold_hooks = {
	expand_to = expand_to,
	row_options = row_options,
	prepare_draw = prepare_draw,
	draw = draw,
}

---@param view FileTreeView
---@param path string
---@return string?
local function prepare_selection(view, path)
	return folds.prepare_selection(view, path, fold_hooks)
end

---@param view FileTreeView
---@param path string
local function select_path(view, path)
	local normalized = prepare_selection(view, path)
	if normalized then
		draw(view, normalized)
	end
end

---@param view FileTreeView
request_git = function(view)
	if view.git_pending or not watch.toplevel(view.root) then
		return
	end
	view.git_pending = true
	git.request(view.root)
end

---@param view FileTreeView
---@param path? string
---@param invalidated_scan? string
schedule_dirty = function(view, path, invalidated_scan)
	if M.state.by_tab[view.tab] ~= view or not vim.api.nvim_buf_is_valid(view.buf) then
		return
	end
	view.dirty = true
	view.dirty_path = path or view.dirty_path
	if invalidated_scan then
		view.dirty_scans[invalidated_scan] = true
	end
	if view.dirty_timer then
		view.dirty_timer:stop()
		view.dirty_timer:close()
	end
	local timer
	timer = debounce.schedule(nil, INVALIDATION_WINDOW_MS, function()
		if view.dirty_timer ~= timer then
			return
		end
		timer:stop()
		timer:close()
		view.dirty_timer = nil
		if view.git_pending then
			return
		end
		if M.state.by_tab[view.tab] ~= view or not vim.api.nvim_buf_is_valid(view.buf) then
			return
		end
		for scan in pairs(view.dirty_scans) do
			fs.invalidate(scan)
			if not vim.uv.fs_stat(scan) then
				fs.invalidate(vim.fs.dirname(scan))
			end
		end
		local selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
		local target = view.dirty_path or (selected and selected.path) or view.root
		view.dirty = false
		view.dirty_path = nil
		view.dirty_scans = {}
		draw(view, target)
	end)
	view.dirty_timer = timer
end

---@param view FileTreeView
---@param changed boolean
local function apply_git_result(view, changed)
	view.git_pending = false
	if changed or view.dirty then
		schedule_dirty(view)
	end
end

---@param view FileTreeView
---@param loaded table<string, boolean>
local function merge_loaded_expansions(view, loaded)
	for relative in pairs(loaded) do
		view.expanded[relative] = true
	end
end

---@param view FileTreeView
---@param path string
---@return boolean
local function finish_initial_draw(view, path)
	if not view.initializing or not view.initial_source_ready or not view.initial_expansions_loaded then
		return false
	end
	local timer = view.initial_draw_timer
	if timer then
		timer:stop()
		timer:close()
		view.initial_draw_timer = nil
	end
	view.initializing = false
	if M.state.by_tab[view.tab] == view and vim.api.nvim_buf_is_valid(view.buf) then
		select_path(view, path)
	end
	return true
end

---@param view FileTreeView
---@param path string
local function start_initial_draw_deadline(view, path)
	view.initializing = true
	view.initial_draw_timer = assert(vim.uv.new_timer())
	view.initial_draw_timer:start(
		IGNORE_WAIT_MS,
		0,
		vim.schedule_wrap(function()
			view.initial_source_ready = true
			finish_initial_draw(view, path)
		end)
	)
end

---@param view FileTreeView
---@param root string
---@param path string
---@param toplevel? string
local function repository_ready(view, root, path, toplevel)
	if M.state.by_tab[view.tab] ~= view or view.root ~= root or not vim.api.nvim_buf_is_valid(view.buf) then
		return
	end
	if toplevel then
		start_initial_draw_deadline(view, path)
		git.refresh(root)
	else
		view.initial_source_ready = true
		finish_initial_draw(view, path)
	end
end

---@param view FileTreeView
---@param path string
---@param missing_is_root boolean
local function reveal_path(view, path, missing_is_root)
	local target = reveal_target(view, path, missing_is_root)
	if target and not is_hidden(view, target) then
		schedule_dirty(view, prepare_selection(view, target))
	end
end

---@param buf integer
local function configure_buffer(buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	vim.bo[buf].filetype = "gleb-file-tree"
end

---@param win integer
local function configure_window(win)
	vim.wo[win].winfixwidth = true
	vim.wo[win].cursorline = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].foldenable = false
	vim.wo[win].foldmethod = "manual"
	vim.wo[win].statuscolumn = ""
	vim.wo[win].wrap = false
	vim.wo[win].list = false
	vim.wo[win].spell = false
	vim.wo[win].winhighlight = "Normal:FileTreeNormal,CursorLine:FileTreeCursorLine,EndOfBuffer:FileTreeNormal"
	vim.api.nvim_win_set_width(win, 35)
end

---@param buf integer
local function detach_ufo(buf)
	local ok, ufo = pcall(require, "ufo")
	if ok then
		ufo.detach(buf)
	end
end

---@param view FileTreeView
---@return FileTreeRow?
local function selected_row(view)
	return view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
end

---@param view FileTreeView
---@param command string
local function open_selected(view, command)
	local row = selected_row(view)
	if not row or row.kind ~= "file" then
		return
	end
	vim.api.nvim_set_current_win(M.eligible_editor(view))
	vim.cmd(command .. " " .. vim.fn.fnameescape(row.path))
end

--- Open the selected project-tree file in the most recent editor window.
---@return nil
function M.open()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		local row = selected_row(view)
		if row and row.kind == "directory" then
			folds.toggle_directory(view, row, fold_hooks)
		else
			open_selected(view, "edit")
		end
	end
end

--- Collapse the selected directory or its displayed parent.
---@return nil
function M.close_node()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	ui_tree.close(view.tree)
end

--- Expand the selected directory or nest, or enter its first child.
---@return nil
function M.expand_node()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	ui_tree.open(view.tree)
end

--- Toggle the selected directory, or collapse the selected file's displayed parent.
---@return nil
function M.toggle_fold()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	ui_tree.toggle(view.tree)
end

--- Collapse every project-tree directory while keeping the root visible.
---@return nil
function M.fold_all()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	ui_tree.close_all(view.tree)
end

--- Expand project-tree directories depth-first up to the visible-row safety limit.
---@return nil
function M.unfold_all()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	ui_tree.open_all(view.tree)
end

--- Close the current tab page's project tree.
---@return nil
function M.close()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		vim.api.nvim_set_current_win(M.eligible_editor(view))
		lifecycle.close(view, M.state)
	end
end

--- Open the selected project-tree file in a vertical editor split.
---@return nil
function M.open_vsplit()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		open_selected(view, "vsplit")
	end
end

--- Open the selected project-tree file in a horizontal editor split.
---@return nil
function M.open_split()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		open_selected(view, "split")
	end
end

--- Open the selected project-tree file in a new tab.
---@return nil
function M.open_tab()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		open_selected(view, "tabnew")
	end
end

---@param path string
---@param requested_root? string
---@return FileTreeView
local function open_view(path, requested_root)
	state.load()
	local tab = vim.api.nvim_get_current_tabpage()
	editor.remember()
	local editor_win = editor.state.last_editor_by_tab[tab]
	local root = fs.normalize(requested_root or vim.fn.getcwd())
	local view
	local initial_path
	local initial_expanded = expanded.load(root, function(loaded)
		if
			view
			and initial_path
			and M.state.by_tab[tab] == view
			and view.root == root
			and vim.api.nvim_buf_is_valid(view.buf)
		then
			merge_loaded_expansions(view, loaded)
			view.initial_expansions_loaded = true
			finish_initial_draw(view, initial_path)
		end
	end)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, ("gleb-file-tree://%s#%d"):format(root, tab))
	configure_buffer(buf)

	vim.cmd("topleft vertical 35 split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	configure_window(win)
	detach_ufo(buf)

	---@type FileTreeView
	view = {
		tab = tab,
		root = root,
		buf = buf,
		win = win,
		expanded = initial_expanded,
		expanded_nests = {},
		rows = {},
		rows_by_path = {},
		tree = tree_model.new({}),
		tree_watched = {},
		autocmds = {},
		watching = true,
		directory_hijacks = {},
		dirty = false,
		dirty_scans = {},
		git_pending = false,
		initializing = true,
		initial_source_ready = false,
		initial_expansions_loaded = false,
	}
	tree_view.attach(buf, view.tree, {
		expand = function(node)
			return folds.expand_shared(view, node, fold_hooks)
		end,
		expand_all = function()
			folds.expand_all_shared(view, fold_hooks)
		end,
	})
	M.state.by_tab[tab] = view
	editor.state.last_editor_by_tab[tab] = editor_win
	initial_path = reveal_target(view, path, true) or root
	git.start_root(root, tab, function(changed)
		view.initial_source_ready = true
		local initial_drawn = finish_initial_draw(view, initial_path)
		if M.state.by_tab[tab] == view and vim.api.nvim_buf_is_valid(buf) and not view.initializing then
			apply_git_result(view, not initial_drawn and changed)
		end
	end)
	lifecycle.attach(view, {
		get_state = function()
			return M.state
		end,
		is_hidden = is_hidden,
		reveal_path = reveal_path,
	})
	watch.start_root(root, tab, function(toplevel)
		repository_ready(view, root, initial_path, toplevel)
	end)
	lifecycle.update_cursor()
	return view
end

---@param path string
---@param requested_root? string
---@return FileTreeView
local function open_replacing_changes(path, requested_root)
	sidebar.close("changes")
	return open_view(path, requested_root)
end

---@param view FileTreeView
---@param root string
local function reroot(view, root)
	if root == view.root then
		return
	end
	expanded.save(view.root, view.expanded)
	expanded.flush()
	watch.stop_root(view.root, view.tab)
	git.stop_root(view.root, view.tab)
	if view.dirty_timer then
		view.dirty_timer:stop()
		view.dirty_timer:close()
		view.dirty_timer = nil
	end
	if view.initial_draw_timer then
		view.initial_draw_timer:stop()
		view.initial_draw_timer:close()
		view.initial_draw_timer = nil
	end
	view.dirty = false
	view.dirty_path = nil
	view.dirty_scans = {}
	view.git_pending = false
	view.initializing = true
	view.initial_source_ready = false
	view.initial_expansions_loaded = false
	view.root = root
	view.expanded = expanded.load(root, function(loaded)
		if M.state.by_tab[view.tab] == view and view.root == root and vim.api.nvim_buf_is_valid(view.buf) then
			merge_loaded_expansions(view, loaded)
			view.initial_expansions_loaded = true
			finish_initial_draw(view, root)
		end
	end)
	view.expanded_nests = {}
	vim.api.nvim_buf_set_name(view.buf, ("gleb-file-tree://%s#%d"):format(root, view.tab))
	git.start_root(root, view.tab, function(changed)
		view.initial_source_ready = true
		local initial_drawn = finish_initial_draw(view, root)
		if M.state.by_tab[view.tab] == view and vim.api.nvim_buf_is_valid(view.buf) and not view.initializing then
			apply_git_result(view, not initial_drawn and changed)
		end
	end)
	watch.start_root(root, view.tab, function(toplevel)
		repository_ready(view, root, root, toplevel)
	end)
end

--- Return the active project-tree root and selected row.
---@return string? root
---@return FileTreeRow? row
function M.selected_path()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return nil, nil
	end
	return view.root, selected_row(view)
end

--- Redraw at a created path, selecting folders or opening files in the editor.
---@param path string
---@param open_file boolean
---@return nil
function M.select_created(path, open_file)
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	fs.invalidate_root(view.root)
	if is_hidden(view, path) then
		local row = selected_row(view)
		draw(view, row and row.path or view.root)
	else
		select_path(view, path)
	end
	if open_file then
		local editor_win = M.eligible_editor(view)
		view.skip_follow_buf = vim.api.nvim_win_get_buf(editor_win)
		vim.api.nvim_set_current_win(editor_win)
		view.skip_follow_buf = nil
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	else
		vim.api.nvim_set_current_win(view.win)
	end
end

---@param root string
---@param values table<string, boolean>
---@param move_pairs FileTreeMovePair[]
---@return table<string, boolean>
local function migrate_state(root, values, move_pairs)
	local migrated = {}
	for relative, value in pairs(values) do
		local target = relative
		for _, pair in ipairs(move_pairs) do
			local old = pair.old:sub(#root + 2)
			local new = pair.new:sub(#root + 2)
			if relative == old or vim.startswith(relative, old .. "/") then
				target = new .. relative:sub(#old + 1)
				break
			end
		end
		migrated[target] = value
	end
	return migrated
end

--- Migrate expansion keys before filesystem moves can trigger a pruning redraw.
---@param root string
---@param move_pairs FileTreeMovePair[]
---@return nil
function M.migrate_moved(root, move_pairs)
	for _, view in pairs(M.state.by_tab) do
		if view.root == root then
			view.expanded = migrate_state(view.root, view.expanded, move_pairs)
			view.expanded_nests = migrate_state(view.root, view.expanded_nests, move_pairs)
		end
	end
end

--- Refresh every project-tree view of a moved root and select the initiating target.
---@param root string
---@param selected_path string
---@param _move_pairs? FileTreeMovePair[]
---@return nil
function M.refresh_moved(root, selected_path, _move_pairs)
	local current_tab = vim.api.nvim_get_current_tabpage()
	local initiating_view = M.state.by_tab[current_tab]
	fs.invalidate_root(root)
	for tab, view in pairs(M.state.by_tab) do
		if view.root == root and vim.api.nvim_win_is_valid(view.win) then
			local row = selected_row(view)
			local target = tab == current_tab and selected_path or (row and row.path or root)
			if is_hidden(view, target) then
				draw(view, row and row.path or root)
			else
				draw(view, prepare_selection(view, target) or target)
			end
		end
	end
	if initiating_view and vim.api.nvim_win_is_valid(initiating_view.win) then
		vim.api.nvim_set_current_win(initiating_view.win)
	end
end

--- Rescan only the current project-tree view and request Git status without debounce.
---@return nil
function M.refresh()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	local row = selected_row(view)
	fs.invalidate_root(view.root)
	draw(view, row and row.path or view.root)
	git.refresh(view.root)
end

--- Redraw every open project tree after shared configuration changes.
---@return nil
function M.redraw_all()
	for _, view in pairs(M.state.by_tab) do
		if vim.api.nvim_win_is_valid(view.win) and vim.api.nvim_buf_is_valid(view.buf) then
			local row = selected_row(view)
			draw(view, row and row.path or view.root)
		end
	end
end

--- Toggle the current tab page's project tree.
---@return nil
function M.toggle()
	local tab = vim.api.nvim_get_current_tabpage()
	local view = M.state.by_tab[tab]
	local path = vim.api.nvim_buf_get_name(0)
	if view and vim.api.nvim_win_is_valid(view.win) then
		if vim.api.nvim_get_current_win() == view.win then
			lifecycle.close(view, M.state)
		else
			vim.api.nvim_set_current_win(view.win)
			reveal_path(view, path, true)
		end
		return
	end
	open_replacing_changes(path)
end

--- Open the project tree and reveal the current file.
---@return nil
function M.reveal()
	local path = vim.api.nvim_buf_get_name(0)
	local tab = vim.api.nvim_get_current_tabpage()
	local view = M.state.by_tab[tab]
	if not view or not vim.api.nvim_win_is_valid(view.win) then
		view = open_view(path)
	else
		vim.api.nvim_set_current_win(view.win)
		reveal_path(view, path, true)
	end
end

--- Close every project-tree view and clear module state.
---@return nil
function M.reset()
	for _, view in pairs(M.state.by_tab) do
		lifecycle.close(view, M.state)
	end
	editor.reset()
	M.state = { by_tab = {}, last_editor_by_tab = editor.state.last_editor_by_tab }
end

--- Set up project-tree rendering and lifecycle hooks.
---@return nil
function M.setup()
	render.setup()
	settings.on_reload("file_tree", M.redraw_all)
	lifecycle.setup({
		get_state = function()
			return M.state
		end,
		open_view = open_replacing_changes,
		reroot = reroot,
		request_git = request_git,
	})
end

sidebar.register("file_tree", M.close)

return M
