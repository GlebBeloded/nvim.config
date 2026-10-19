-- The project-tree view owns one left-docked window and its lifecycle per tab page.

local M = {}

local expanded = require("gleb.file_tree.expanded")
local fs = require("gleb.file_tree.fs")
local git = require("gleb.file_tree.git")
local ignore = require("gleb.file_tree.ignore")
local model = require("gleb.file_tree.model")
local render = require("gleb.file_tree.render")
local settings = require("gleb.file_tree.settings")
local state = require("gleb.file_tree.state")
local watch = require("gleb.file_tree.watch")

local EXPANSION_MAX_ROWS = 5000
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

---@class FileTreeViewState
---@field by_tab table<integer, FileTreeView>
---@field last_editor_by_tab table<integer, integer>

---@type FileTreeViewState
M.state = { by_tab = {}, last_editor_by_tab = {} }

local view_group
local original_guicursor

local function update_cursor()
	local current = vim.api.nvim_get_current_win()
	local tree_focused = vim.api.nvim_win_is_valid(current)
		and vim.bo[vim.api.nvim_win_get_buf(current)].filetype == "gleb-file-tree"
	local mode = vim.api.nvim_get_mode().mode
	local hidden = tree_focused and (mode == "n" or mode == "v" or mode == "V" or mode == "\22")
	if hidden then
		original_guicursor = original_guicursor or vim.o.guicursor
		vim.o.guicursor = "a:FileTreeHiddenCursor"
	elseif original_guicursor then
		vim.o.guicursor = original_guicursor
	end
end

---@param view FileTreeView
---@return integer
local function create_editor(view)
	vim.api.nvim_set_current_win(view.win)
	vim.cmd("rightbelow vnew")
	vim.cmd(
		"setlocal winfixwidth< cursorline< number< relativenumber< signcolumn< foldcolumn< foldenable< foldmethod< statuscolumn< wrap< list< spell< winhighlight<"
	)
	local win = vim.api.nvim_get_current_win()
	M.state.last_editor_by_tab[view.tab] = win
	return win
end

--- Return whether a window can host an editor buffer.
---@param win integer
---@return boolean
function M.is_eligible_editor(win)
	if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local filetype = vim.bo[buf].filetype
	local name = vim.api.nvim_buf_get_name(buf)
	return vim.bo[buf].buftype == ""
		and filetype ~= "gleb-file-tree"
		and filetype ~= "gleb-changes"
		and not vim.startswith(filetype, "Diffview")
		and not vim.startswith(name, "diffview://")
		and not vim.wo[win].diff
end

---@param win integer
---@return boolean
local function is_sidebar_window(win)
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end
	local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
	return filetype == "gleb-file-tree" or filetype == "gleb-changes"
end

local function remember_editor()
	local win = vim.api.nvim_get_current_win()
	if M.is_eligible_editor(win) then
		M.state.last_editor_by_tab[vim.api.nvim_get_current_tabpage()] = win
	end
end

--- Select an eligible editor window for a left-side tool view.
---@param view { tab: integer, win: integer }
---@return integer
function M.eligible_editor(view)
	local remembered = M.state.last_editor_by_tab[view.tab]
	if remembered and remembered ~= view.win and M.is_eligible_editor(remembered) then
		return remembered
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tab)) do
		if win ~= view.win and M.is_eligible_editor(win) then
			M.state.last_editor_by_tab[view.tab] = win
			return win
		end
	end
	return create_editor(view)
end

---@param view FileTreeView
local function forget(view)
	if M.state.by_tab[view.tab] == view then
		M.state.by_tab[view.tab] = nil
	end
	if view.watching then
		view.watching = false
		expanded.save(view.root, view.expanded)
		expanded.flush()
		watch.stop_root(view.root, view.tab)
		git.stop_root(view.root, view.tab)
	end
	if view.initial_draw_timer then
		view.initial_draw_timer:stop()
		view.initial_draw_timer:close()
		view.initial_draw_timer = nil
	end
	if view.dirty_timer then
		view.dirty_timer:stop()
		view.dirty_timer:close()
		view.dirty_timer = nil
	end
	for _, autocmd in ipairs(view.autocmds) do
		pcall(vim.api.nvim_del_autocmd, autocmd)
	end
	view.autocmds = {}
end

---@param view FileTreeView
local function close_view(view)
	if vim.api.nvim_buf_is_valid(view.buf) then
		vim.bo[view.buf].bufhidden = "wipe"
	end
	forget(view)
	if vim.api.nvim_win_is_valid(view.win) then
		vim.api.nvim_win_close(view.win, true)
	end
	if vim.api.nvim_buf_is_valid(view.buf) then
		vim.api.nvim_buf_delete(view.buf, { force = true })
	end
	update_cursor()
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

local schedule_dirty
local request_git

---@param view FileTreeView
---@param path string
---@param prepared? FileTreePreparedDraw
local function draw(view, path, prepared)
	local rows_before = view.rows
	local cursor_line = vim.api.nvim_win_get_cursor(view.win)[1]
	prepared = prepared or prepare_draw(view, path)
	view.rows = prepared.rows
	view.rows_by_path = prepared.rows_by_path
	render.draw(view.buf, view.rows)
	restore_cursor(view, path, rows_before, cursor_line)
	watch.sync(view.root, view.tab, prepared.watched, function(changed_path)
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
---@param path string
---@return string?
local function prepare_selection(view, path)
	local normalized = fs.normalize(path)
	local row = view.rows_by_path[normalized]
	if row then
		vim.api.nvim_win_set_cursor(view.win, { row, 0 })
		return
	end
	expand_to(view, normalized)
	local loaded_settings = settings.load()
	local nesting_settings = loaded_settings.nesting
	local parent =
		model.nest_parent(fs.tree(view.root), normalized, nesting_settings, row_options(view, loaded_settings))
	if parent then
		view.expanded_nests[parent:sub(#view.root + 2)] = true
	end
	return normalized
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
	local timer = assert(vim.uv.new_timer())
	view.dirty_timer = timer
	timer:start(
		INVALIDATION_WINDOW_MS,
		0,
		vim.schedule_wrap(function()
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
	)
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
	local timer = view.initial_draw_timer
	if not timer then
		return false
	end
	timer:stop()
	timer:close()
	view.initial_draw_timer = nil
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
		view.initializing = false
		select_path(view, path)
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

---@param view FileTreeView
---@param path string
local function redraw_at(view, path)
	draw(view, path)
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
---@param row FileTreeRow
---@param warning string
---@return FileTreeRow[]?
---@return FileTreePreparedDraw?
local function expand_directory(view, row, warning)
	local relative = row.path:sub(#view.root + 2)
	view.expanded[relative] = true
	local prepared = prepare_draw(view, row.path)
	if #prepared.rows > EXPANSION_MAX_ROWS then
		view.expanded[relative] = nil
		vim.notify(warning, vim.log.levels.WARN)
		return nil
	end
	return prepared.rows, prepared
end

---@param view FileTreeView
---@param row FileTreeRow
local function toggle_directory(view, row)
	if row.kind == "root" or row.empty then
		return
	end
	local relative = row.path:sub(#view.root + 2)
	if row.expanded then
		view.expanded[relative] = nil
		draw(view, row.path)
	else
		local _, prepared = expand_directory(view, row, "Expansion stopped at 5000 rows")
		if not prepared then
			return
		end
		draw(view, row.path, prepared)
	end
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

---@param view FileTreeView
---@param row FileTreeRow
---@return boolean
local function close_nest(view, row)
	local parent = row.nest_parent or (row.nest_expanded and row.path or nil)
	if not parent then
		return false
	end
	view.expanded_nests[parent:sub(#view.root + 2)] = nil
	draw(view, parent)
	return true
end

--- Open the selected project-tree file in the most recent editor window.
---@return nil
function M.open()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		local row = selected_row(view)
		if row and row.kind == "directory" then
			toggle_directory(view, row)
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
	local index = vim.api.nvim_win_get_cursor(view.win)[1]
	local row = view.rows[index]
	if not row or row.kind == "root" then
		return
	end
	if close_nest(view, row) then
		return
	end
	local target = row
	if row.kind ~= "directory" or not row.expanded then
		for parent_index = index - 1, 1, -1 do
			local candidate = view.rows[parent_index]
			if candidate.depth < row.depth then
				target = candidate
				break
			end
		end
	end
	if target.kind == "root" then
		return
	end
	view.expanded[target.path:sub(#view.root + 2)] = nil
	draw(view, target.path)
end

--- Toggle the selected directory, or collapse the selected file's displayed parent.
---@return nil
function M.toggle_fold()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	local row = selected_row(view)
	if row and row.kind == "directory" then
		toggle_directory(view, row)
	elseif row and row.kind == "file" and row.nest_children then
		local relative = row.path:sub(#view.root + 2)
		view.expanded_nests[relative] = not view.expanded_nests[relative] or nil
		draw(view, row.path)
	elseif row and row.kind == "file" and row.nest_parent then
		close_nest(view, row)
	elseif row and row.kind == "file" then
		M.close_node()
	end
end

--- Collapse every project-tree directory while keeping the root visible.
---@return nil
function M.fold_all()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	local path = view.root
	for index = vim.api.nvim_win_get_cursor(view.win)[1], 2, -1 do
		local row = view.rows[index]
		if row.depth == 0 then
			path = row.path
			break
		end
	end
	view.expanded = {}
	view.expanded_nests = {}
	redraw_at(view, path)
end

--- Expand project-tree directories depth-first up to the visible-row safety limit.
---@return nil
function M.unfold_all()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not view then
		return
	end
	local selected = selected_row(view)
	view.expanded = {}
	view.expanded_nests = {}
	local loaded_settings = settings.load()
	local nesting_settings = loaded_settings.nesting
	local tree = fs.tree(view.root)
	local stopped
	view.expanded, view.expanded_nests, stopped =
		model.unfold_all(tree, row_options(view, loaded_settings), nesting_settings, EXPANSION_MAX_ROWS)
	if stopped then
		vim.notify("Unfold all stopped at 5000 rows", vim.log.levels.WARN)
	end
	redraw_at(view, selected and selected.path or view.root)
end

--- Close the current tab page's project tree.
---@return nil
function M.close()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		vim.api.nvim_set_current_win(M.eligible_editor(view))
		close_view(view)
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

---@param view FileTreeView
local function protect_tree_buffer(view)
	if not vim.api.nvim_win_is_valid(view.win) or vim.api.nvim_get_current_win() ~= view.win then
		return
	end
	local replacement = vim.api.nvim_win_get_buf(view.win)
	if replacement == view.buf then
		return
	end
	local editor = M.eligible_editor(view)
	vim.api.nvim_win_set_buf(view.win, view.buf)
	vim.bo[view.buf].bufhidden = "wipe"
	vim.api.nvim_win_set_buf(editor, replacement)
	vim.api.nvim_set_current_win(editor)
end

---@param view FileTreeView
local function keep_tree_buffer(view)
	if
		vim.api.nvim_win_is_valid(view.win)
		and vim.api.nvim_get_current_win() == view.win
		and vim.api.nvim_win_get_buf(view.win) == view.buf
	then
		vim.bo[view.buf].bufhidden = "hide"
	end
end

---@param view FileTreeView
---@param buf integer
local function follow_buffer(view, buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_tabpage() ~= view.tab or buf == view.buf then
		return
	end
	if view.skip_follow_buf == buf then
		view.skip_follow_buf = nil
		return
	end
	local win = vim.api.nvim_get_current_win()
	local path = vim.api.nvim_buf_get_name(buf)
	local stat = path ~= "" and vim.uv.fs_stat(path) or nil
	if stat and stat.type == "directory" then
		view.directory_hijacks[win] = true
		return
	end
	if view.directory_hijacks[win] then
		view.directory_hijacks[win] = nil
		return
	end
	if vim.bo[buf].buftype == "" and not is_hidden(view, path) then
		reveal_path(view, path, false)
	end
end

---@param view FileTreeView
local function add_teardown_autocmds(view)
	view.autocmds = {
		vim.api.nvim_create_autocmd("BufLeave", {
			group = view_group,
			buffer = view.buf,
			callback = function()
				view.buffer_leave_cursor = vim.api.nvim_win_get_cursor(view.win)
				vim.bo[view.buf].bufhidden = "hide"
			end,
		}),
		vim.api.nvim_create_autocmd("WinLeave", {
			group = view_group,
			pattern = tostring(view.win),
			callback = function()
				update_cursor()
				if vim.api.nvim_buf_is_valid(view.buf) then
					vim.bo[view.buf].bufhidden = "wipe"
				end
			end,
		}),
		vim.api.nvim_create_autocmd({ "WinEnter", "ModeChanged" }, {
			group = view_group,
			callback = function()
				keep_tree_buffer(view)
				update_cursor()
			end,
		}),
		vim.api.nvim_create_autocmd("BufEnter", {
			group = view_group,
			callback = function(args)
				protect_tree_buffer(view)
				keep_tree_buffer(view)
				follow_buffer(view, args.buf)
			end,
		}),
		vim.api.nvim_create_autocmd("WinClosed", {
			group = view_group,
			pattern = tostring(view.win),
			callback = function()
				forget(view)
			end,
		}),
		vim.api.nvim_create_autocmd("BufWipeout", {
			group = view_group,
			buffer = view.buf,
			callback = function()
				forget(view)
			end,
		}),
	}
end

---@param path string
---@param requested_root? string
---@return FileTreeView
local function open_view(path, requested_root)
	state.load()
	local tab = vim.api.nvim_get_current_tabpage()
	remember_editor()
	local editor = M.state.last_editor_by_tab[tab]
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
			if not view.initializing then
				select_path(view, initial_path)
			end
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
		autocmds = {},
		watching = true,
		directory_hijacks = {},
		dirty = false,
		dirty_scans = {},
		git_pending = false,
		initializing = true,
	}
	M.state.by_tab[tab] = view
	M.state.last_editor_by_tab[tab] = editor
	initial_path = reveal_target(view, path, true) or root
	git.start_root(root, tab, function(changed)
		if finish_initial_draw(view, initial_path) then
			return
		end
		if M.state.by_tab[tab] == view and vim.api.nvim_buf_is_valid(buf) then
			apply_git_result(view, changed)
		end
	end)
	add_teardown_autocmds(view)
	watch.start_root(root, tab, function(toplevel)
		repository_ready(view, root, initial_path, toplevel)
	end)
	update_cursor()
	return view
end

---@param path string
---@param requested_root? string
---@return FileTreeView
local function open_replacing_changes(path, requested_root)
	local changes = package.loaded["gleb.git.changes"]
	if changes then
		changes.close()
	end
	return open_view(path, requested_root)
end

---@param args { buf: integer }
local function hijack_directory(args)
	if not vim.api.nvim_buf_is_valid(args.buf) then
		return
	end
	local directory = vim.api.nvim_buf_get_name(args.buf)
	local stat = directory ~= "" and vim.uv.fs_stat(directory) or nil
	if vim.bo[args.buf].buftype ~= "" or not stat or stat.type ~= "directory" then
		return
	end

	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view and vim.api.nvim_win_is_valid(view.win) then
		if vim.api.nvim_get_current_win() == view.win then
			vim.api.nvim_win_set_buf(view.win, view.buf)
			if view.buffer_leave_cursor then
				vim.api.nvim_win_set_cursor(view.win, view.buffer_leave_cursor)
				view.buffer_leave_cursor = nil
			end
		else
			vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, false))
		end
		vim.api.nvim_set_current_win(view.win)
	else
		vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, false))
		open_replacing_changes(directory, directory)
	end
	if vim.api.nvim_buf_is_valid(args.buf) then
		vim.api.nvim_buf_delete(args.buf, { force = true })
	end
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
	view.root = root
	view.expanded = expanded.load(root, function(loaded)
		if M.state.by_tab[view.tab] == view and view.root == root and vim.api.nvim_buf_is_valid(view.buf) then
			merge_loaded_expansions(view, loaded)
			if not view.initializing then
				draw(view, root)
			end
		end
	end)
	view.expanded_nests = {}
	vim.api.nvim_buf_set_name(view.buf, ("gleb-file-tree://%s#%d"):format(root, view.tab))
	git.start_root(root, view.tab, function(changed)
		if finish_initial_draw(view, root) then
			return
		end
		if M.state.by_tab[view.tab] == view and vim.api.nvim_buf_is_valid(view.buf) then
			apply_git_result(view, changed)
		end
	end)
	watch.start_root(root, view.tab, function(toplevel)
		repository_ready(view, root, root, toplevel)
	end)
end

---@param tab integer
---@return integer
local function eligible_editor_count(tab)
	return vim.iter(vim.api.nvim_tabpage_list_wins(tab)):fold(0, function(count, win)
		return count + (M.is_eligible_editor(win) and 1 or 0)
	end)
end

---@param tab integer
local function close_tree_windows(tab)
	local view = M.state.by_tab[tab]
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if is_sidebar_window(win) and (not view or win ~= view.win) and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	if view then
		close_view(view)
	end
end

local function on_quit_pre()
	local tab = vim.api.nvim_get_current_tabpage()
	if
		M.state.by_tab[tab]
		and M.is_eligible_editor(vim.api.nvim_get_current_win())
		and eligible_editor_count(tab) == 1
	then
		close_tree_windows(tab)
	end
end

---@param tab integer
local function close_trees_if_orphaned(tab)
	if vim.api.nvim_tabpage_is_valid(tab) and M.state.by_tab[tab] and eligible_editor_count(tab) == 0 then
		close_tree_windows(tab)
	end
end

local function close_trees_without_an_editor()
	for tab in pairs(M.state.by_tab) do
		local pending_tab = tab
		vim.schedule(function()
			close_trees_if_orphaned(pending_tab)
		end)
	end
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
		local editor = M.eligible_editor(view)
		view.skip_follow_buf = vim.api.nvim_win_get_buf(editor)
		vim.api.nvim_set_current_win(editor)
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
				select_path(view, target)
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
			close_view(view)
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
		close_view(view)
	end
	M.state = { by_tab = {}, last_editor_by_tab = {} }
end

--- Set up project-tree rendering and lifecycle hooks.
---@return nil
function M.setup()
	render.setup()
	view_group = vim.api.nvim_create_augroup("gleb_file_tree_view", { clear = true })
	local hijack_group = vim.api.nvim_create_augroup("gleb_file_tree_hijack", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", { group = hijack_group, callback = hijack_directory })
	remember_editor()
	vim.api.nvim_create_autocmd("WinEnter", { group = view_group, callback = remember_editor })
	vim.api.nvim_create_autocmd("QuitPre", { group = view_group, callback = on_quit_pre })
	vim.api.nvim_create_autocmd("WinClosed", { group = view_group, callback = close_trees_without_an_editor })
	vim.api.nvim_create_autocmd("DirChanged", {
		group = view_group,
		pattern = "global",
		callback = function()
			local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
			if view then
				reroot(view, fs.normalize(vim.fn.getcwd()))
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", { group = view_group, callback = expanded.flush })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = view_group,
		callback = function()
			local path = fs.normalize(vim.api.nvim_buf_get_name(0))
			for _, view in pairs(M.state.by_tab) do
				if vim.startswith(path, view.root .. "/") then
					request_git(view)
				end
			end
		end,
	})
end

return M
