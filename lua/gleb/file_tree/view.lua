-- The project-tree view owns one left-docked window and its lifecycle per tab page.

local M = {}

local fs = require("gleb.file_tree.fs")
local model = require("gleb.file_tree.model")
local render = require("gleb.file_tree.render")

local EXPANSION_MAX_ROWS = 5000

---@class FileTreeView
---@field tab integer
---@field root string
---@field buf integer
---@field win integer
---@field expanded table<string, boolean>
---@field rows FileTreeRow[]
---@field autocmds integer[]

---@class FileTreeViewState
---@field by_tab table<integer, FileTreeView>
---@field last_editor_by_tab table<integer, integer>

---@type FileTreeViewState
M.state = { by_tab = {}, last_editor_by_tab = {} }

local view_group
local original_guicursor

---@param view FileTreeView
local function update_cursor(view)
	local tree_focused = vim.api.nvim_win_is_valid(view.win) and vim.api.nvim_get_current_win() == view.win
	local mode = vim.api.nvim_get_mode().mode
	local hidden = tree_focused and (mode == "n" or mode == "v" or mode == "V" or mode == "\22")
	if hidden then
		original_guicursor = original_guicursor or vim.o.guicursor
		vim.o.guicursor = "a:FileTreeHiddenCursor"
	elseif original_guicursor then
		vim.o.guicursor = original_guicursor
	end
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
	error("project tree requires an editor window")
end

---@param view FileTreeView
local function forget(view)
	if M.state.by_tab[view.tab] == view then
		M.state.by_tab[view.tab] = nil
	end
	for _, autocmd in ipairs(view.autocmds) do
		pcall(vim.api.nvim_del_autocmd, autocmd)
	end
	view.autocmds = {}
end

---@param view FileTreeView
local function close_view(view)
	if original_guicursor then
		vim.o.guicursor = original_guicursor
	end
	forget(view)
	if vim.api.nvim_win_is_valid(view.win) then
		vim.api.nvim_win_close(view.win, true)
	elseif vim.api.nvim_buf_is_valid(view.buf) then
		vim.api.nvim_buf_delete(view.buf, { force = true })
	end
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
---@param path string
local function draw(view, path)
	expand_to(view, path)
	view.rows = model.rows(fs.tree(view.root), view.expanded, {})
	render.draw(view.buf, view.rows)
	for index, row in ipairs(view.rows) do
		if row.path == path then
			vim.api.nvim_win_set_cursor(view.win, { index, 0 })
			break
		end
	end
end

---@param view FileTreeView
---@param path string
---@param missing_is_root boolean
local function reveal_path(view, path, missing_is_root)
	local target = reveal_target(view, path, missing_is_root)
	if target then
		draw(view, target)
	end
end

---@param view FileTreeView
---@param path string
local function redraw_at(view, path)
	view.rows = model.rows(fs.tree(view.root), view.expanded, {})
	render.draw(view.buf, view.rows)
	for index, row in ipairs(view.rows) do
		if row.path == path then
			vim.api.nvim_win_set_cursor(view.win, { index, 0 })
			return
		end
	end
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
	vim.wo[win].winhighlight = "Normal:FileTreeNormal,CursorLine:FileTreeCursorLine"
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
	local rows = model.rows(fs.tree(view.root), view.expanded, {})
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
	local row = selected_row(view)
	view.expanded = {}
	redraw_at(view, row and row.path or view.root)
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
		elseif found_parent and row.depth == parent.depth + 1 and row.kind == "directory" then
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
	local rows = model.rows(fs.tree(view.root), view.expanded, {})
	local queue = {}
	for _, row in ipairs(rows) do
		if row.kind == "directory" then
			queue[#queue + 1] = row
		end
	end
	local queue_index = 1
	while queue_index <= #queue do
		local row = queue[queue_index]
		queue_index = queue_index + 1
		if not row.empty then
			local expanded_rows = expand_directory(view, row, "Unfold all stopped at 5000 rows")
			if not expanded_rows then
				break
			end
			rows = expanded_rows
			append_directory_children(rows, row, queue)
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
local function follow_current_buffer(view)
	if vim.api.nvim_get_current_tabpage() ~= view.tab or vim.api.nvim_get_current_buf() == view.buf then
		return
	end
	reveal_path(view, vim.api.nvim_buf_get_name(0), false)
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
				update_cursor(view)
				if vim.api.nvim_buf_is_valid(view.buf) then
					vim.bo[view.buf].bufhidden = "wipe"
				end
			end,
		}),
		vim.api.nvim_create_autocmd({ "WinEnter", "ModeChanged" }, {
			group = view_group,
			callback = function()
				update_cursor(view)
			end,
		}),
		vim.api.nvim_create_autocmd("BufEnter", {
			group = view_group,
			callback = function()
				protect_tree_buffer(view)
				follow_current_buffer(view)
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
		expanded = {},
		rows = {},
		autocmds = {},
	}
	M.state.by_tab[tab] = view
	add_teardown_autocmds(view)
	reveal_path(view, path, true)
	update_cursor(view)
	return view
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
end

return M
