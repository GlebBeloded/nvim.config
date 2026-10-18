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

---@class FileTreeView
---@field tab integer
---@field root string
---@field buf integer
---@field win integer
---@field expanded table<string, boolean>
---@field expanded_nests table<string, boolean>
---@field rows FileTreeRow[]
---@field autocmds integer[]
---@field watching boolean
---@field directory_hijacks table<integer, boolean>
---@field skip_follow_buf? integer
---@field initial_draw_timer? uv.uv_timer_t

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

---@param win integer
---@return boolean
local function is_eligible_editor(win)
	if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local filetype = vim.bo[buf].filetype
	local name = vim.api.nvim_buf_get_name(buf)
	return vim.bo[buf].buftype == ""
		and filetype ~= "neo-tree"
		and filetype ~= "gleb-file-tree"
		and not vim.startswith(filetype, "Diffview")
		and not vim.startswith(name, "diffview://")
		and not vim.wo[win].diff
end

---@param win integer
---@return boolean
local function is_tree_window(win)
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end
	local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
	return filetype == "gleb-file-tree" or filetype == "neo-tree"
end

local function remember_editor()
	local win = vim.api.nvim_get_current_win()
	if is_eligible_editor(win) then
		M.state.last_editor_by_tab[vim.api.nvim_get_current_tabpage()] = win
	end
end

---@param view FileTreeView
---@return integer
local function eligible_editor(view)
	local remembered = M.state.last_editor_by_tab[view.tab]
	if remembered and remembered ~= view.win and is_eligible_editor(remembered) then
		return remembered
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tab)) do
		if win ~= view.win and is_eligible_editor(win) then
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
	for _, autocmd in ipairs(view.autocmds) do
		pcall(vim.api.nvim_del_autocmd, autocmd)
	end
	view.autocmds = {}
end

---@param view FileTreeView
local function close_view(view)
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
local function draw(view, path)
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
	for relative in pairs(view.expanded_nests) do
		local parent = vim.fs.joinpath(view.root, relative)
		local stat = vim.uv.fs_stat(parent)
		if
			not stat
			or stat.type ~= "file"
			or not model.has_nest(tree, parent, nesting_settings, loaded_settings.matcher)
		then
			view.expanded_nests[relative] = nil
		end
	end
	view.rows =
		model.rows(tree, view.expanded, row_options(view, loaded_settings), nesting_settings, view.expanded_nests)
	render.draw(view.buf, view.rows)
	local cursor = vim.api.nvim_win_get_cursor(view.win)
	vim.api.nvim_win_set_cursor(view.win, { math.min(cursor[1], math.max(#view.rows, 1)), cursor[2] })
	for index, row in ipairs(view.rows) do
		if row.path == path then
			vim.api.nvim_win_set_cursor(view.win, { index, 0 })
			break
		end
	end
	watch.sync(view.root, view.tab, watched, function(changed_path)
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
		local selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
		draw(view, selected and selected.path or view.root)
	end, function()
		git.request(view.root)
	end)
	expanded.save(view.root, view.expanded)
end

---@param view FileTreeView
---@param path string
local function select_path(view, path)
	local normalized = fs.normalize(path)
	expand_to(view, normalized)
	local loaded_settings = settings.load()
	local nesting_settings = loaded_settings.nesting
	local parent = model.nest_parent(fs.tree(view.root), normalized, nesting_settings, loaded_settings.matcher)
	if parent then
		view.expanded_nests[parent:sub(#view.root + 2)] = true
	end
	draw(view, normalized)
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
	if M.state.by_tab[view.tab] == view and vim.api.nvim_buf_is_valid(view.buf) then
		select_path(view, path)
	end
	return true
end

---@param view FileTreeView
---@param path string
---@param missing_is_root boolean
local function reveal_path(view, path, missing_is_root)
	local target = reveal_target(view, path, missing_is_root)
	if target and not is_hidden(view, target) then
		select_path(view, target)
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
	vim.bo[buf].bufhidden = "wipe"
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
local function expand_directory(view, row, warning)
	local relative = row.path:sub(#view.root + 2)
	view.expanded[relative] = true
	local loaded_settings = settings.load()
	local rows = model.rows(
		fs.tree(view.root),
		view.expanded,
		row_options(view, loaded_settings),
		loaded_settings.nesting,
		view.expanded_nests
	)
	if #rows > EXPANSION_MAX_ROWS then
		view.expanded[relative] = nil
		vim.notify(warning, vim.log.levels.WARN)
		return nil
	end
	return rows
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
	elseif not expand_directory(view, row, "Expansion stopped at 5000 rows") then
		return
	end
	draw(view, row.path)
end

---@param view FileTreeView
---@param command string
local function open_selected(view, command)
	local row = selected_row(view)
	if not row or row.kind ~= "file" then
		return
	end
	vim.api.nvim_set_current_win(eligible_editor(view))
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

---@param rows FileTreeRow[]
---@param parent FileTreeRow
---@param queue FileTreeRow[]
local function append_directory_children(rows, parent, queue)
	local found_parent = false
	for _, row in ipairs(rows) do
		if row.path == parent.path then
			found_parent = true
		elseif found_parent and row.depth <= parent.depth then
			return
		elseif found_parent and row.depth == parent.depth + 1 and row.kind == "directory" and not row.ignored then
			queue[#queue + 1] = row
		end
	end
end

--- Expand project-tree directories breadth-first up to the visible-row safety limit.
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
	local rows =
		model.rows(tree, view.expanded, row_options(view, loaded_settings), nesting_settings, view.expanded_nests)
	local queue = {}
	for _, row in ipairs(rows) do
		if row.kind == "directory" and not row.ignored then
			queue[#queue + 1] = row
		end
	end
	local queue_index = 1
	local stopped = false
	while queue_index <= #queue do
		local row = queue[queue_index]
		queue_index = queue_index + 1
		if not row.empty then
			local expanded_rows = expand_directory(view, row, "Unfold all stopped at 5000 rows")
			if not expanded_rows then
				stopped = true
				break
			end
			rows = expanded_rows
			append_directory_children(rows, row, queue)
		end
	end
	if not stopped then
		local visible_count = #rows
		for _, row in ipairs(rows) do
			if row.nest_children then
				if visible_count + #row.nest_children > EXPANSION_MAX_ROWS then
					vim.notify("Unfold all stopped at 5000 rows", vim.log.levels.WARN)
					break
				end
				view.expanded_nests[row.path:sub(#view.root + 2)] = true
				visible_count = visible_count + #row.nest_children
			end
		end
	end
	redraw_at(view, selected and selected.path or view.root)
end

--- Close the current tab page's project tree.
---@return nil
function M.close()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		vim.api.nvim_set_current_win(eligible_editor(view))
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
	local editor = eligible_editor(view)
	vim.api.nvim_win_set_buf(view.win, view.buf)
	vim.bo[view.buf].bufhidden = "wipe"
	vim.api.nvim_win_set_buf(editor, replacement)
	vim.api.nvim_set_current_win(editor)
end

---@param view FileTreeView
---@param buf integer
local function follow_buffer(view, buf)
	if vim.api.nvim_get_current_tabpage() ~= view.tab or buf == view.buf then
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
				update_cursor()
			end,
		}),
		vim.api.nvim_create_autocmd("BufEnter", {
			group = view_group,
			callback = function(args)
				protect_tree_buffer(view)
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
---@return FileTreeView
local function open_view(path)
	state.load()
	local tab = vim.api.nvim_get_current_tabpage()
	local root = fs.normalize(vim.fn.getcwd())
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, ("gleb-file-tree://%s#%d"):format(root, tab))
	configure_buffer(buf)

	vim.cmd("topleft vertical 35 split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	configure_window(win)
	detach_ufo(buf)

	---@type FileTreeView
	local view = {
		tab = tab,
		root = root,
		buf = buf,
		win = win,
		expanded = expanded.load(root),
		expanded_nests = {},
		rows = {},
		autocmds = {},
		watching = true,
		directory_hijacks = {},
	}
	M.state.by_tab[tab] = view
	watch.start_root(root, tab)
	local initial_path = reveal_target(view, path, true) or root
	git.start_root(root, tab, function()
		if finish_initial_draw(view, initial_path) then
			return
		end
		if M.state.by_tab[tab] == view and vim.api.nvim_buf_is_valid(buf) then
			local selected = view.rows[vim.api.nvim_win_get_cursor(win)[1]]
			draw(view, selected and selected.path or root)
		end
	end)
	add_teardown_autocmds(view)
	if watch.toplevel(root) then
		view.initial_draw_timer = assert(vim.uv.new_timer())
		view.initial_draw_timer:start(
			IGNORE_WAIT_MS,
			0,
			vim.schedule_wrap(function()
				finish_initial_draw(view, initial_path)
			end)
		)
		git.refresh(root)
	else
		select_path(view, initial_path)
	end
	update_cursor()
	return view
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
	view.root = root
	view.expanded = expanded.load(root)
	view.expanded_nests = {}
	vim.api.nvim_buf_set_name(view.buf, ("gleb-file-tree://%s#%d"):format(root, view.tab))
	watch.start_root(root, view.tab)
	git.start_root(root, view.tab, function()
		if M.state.by_tab[view.tab] == view and vim.api.nvim_buf_is_valid(view.buf) then
			local selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
			draw(view, selected and selected.path or root)
		end
	end)
	draw(view, root)
	git.request(root)
end

---@param tab integer
---@return integer
local function eligible_editor_count(tab)
	return vim.iter(vim.api.nvim_tabpage_list_wins(tab)):fold(0, function(count, win)
		return count + (is_eligible_editor(win) and 1 or 0)
	end)
end

---@param tab integer
local function close_tree_windows(tab)
	local view = M.state.by_tab[tab]
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if is_tree_window(win) and (not view or win ~= view.win) and vim.api.nvim_win_is_valid(win) then
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
		and is_eligible_editor(vim.api.nvim_get_current_win())
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
		local editor = eligible_editor(view)
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
			local cursor_line = vim.api.nvim_win_get_cursor(view.win)[1]
			local rows_before = view.rows
			draw(view, row and row.path or view.root)
			if
				row and not vim.iter(view.rows):any(function(candidate)
					return candidate.path == row.path
				end)
			then
				for index = cursor_line - 1, 1, -1 do
					local previous_path = rows_before[index].path
					local new_index = vim.iter(view.rows):enumerate():find(function(_, candidate)
						return candidate.path == previous_path
					end)
					if new_index then
						vim.api.nvim_win_set_cursor(view.win, { new_index, 0 })
						break
					end
				end
			end
		end
	end
end

--- Toggle the current tab page's project tree.
---@return nil
function M.toggle()
	local tab = vim.api.nvim_get_current_tabpage()
	local view = M.state.by_tab[tab]
	if view and vim.api.nvim_win_is_valid(view.win) then
		if vim.api.nvim_get_current_win() == view.win then
			close_view(view)
		else
			vim.api.nvim_set_current_win(view.win)
		end
		return
	end
	local path = vim.api.nvim_buf_get_name(0)
	open_view(path)
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
			local requested = {}
			for _, view in pairs(M.state.by_tab) do
				if vim.startswith(path, view.root .. "/") and not requested[view.root] then
					requested[view.root] = true
					git.request(view.root)
				end
			end
		end,
	})
end

return M
