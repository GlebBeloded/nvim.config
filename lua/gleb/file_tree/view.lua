-- The project-tree view owns one left-docked window and its lifecycle per tab page.

local M = {}

local fs = require("gleb.file_tree.fs")
local model = require("gleb.file_tree.model")
local render = require("gleb.file_tree.render")

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
	vim.api.nvim_set_current_win(eligible_editor(view))
	vim.cmd(command .. " " .. vim.fn.fnameescape(row.path))
end

--- Open the selected project-tree file in the most recent editor window.
---@return nil
function M.open()
	local view = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if view then
		open_selected(view, "edit")
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
local function configure_mappings(view)
	local options = { buffer = view.buf, silent = true }
	vim.keymap.set("n", "<CR>", M.open, vim.tbl_extend("force", options, { desc = "Project: Open" }))
	vim.keymap.set(
		"n",
		"v",
		M.open_vsplit,
		vim.tbl_extend("force", options, { desc = "Project: Open in Vertical Split" })
	)
	vim.keymap.set(
		"n",
		"s",
		M.open_split,
		vim.tbl_extend("force", options, { desc = "Project: Open in Horizontal Split" })
	)
	vim.keymap.set("n", "t", M.open_tab, vim.tbl_extend("force", options, { desc = "Project: Open in New Tab" }))
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
				if vim.api.nvim_buf_is_valid(view.buf) then
					vim.bo[view.buf].bufhidden = "wipe"
				end
			end,
		}),
		vim.api.nvim_create_autocmd("BufEnter", {
			group = view_group,
			callback = function()
				protect_tree_buffer(view)
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
	local root = vim.fn.getcwd()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, ("gleb-file-tree://%s#%d"):format(root, tab))
	configure_buffer(buf)

	vim.cmd("topleft vertical 35 split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	configure_window(win)

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
	configure_mappings(view)
	draw(view, path)
	return view
end

local function on_quit_pre()
	local tab = vim.api.nvim_get_current_tabpage()
	local view = M.state.by_tab[tab]
	if not view or vim.api.nvim_get_current_win() == view.win then
		return
	end
	local editor_count = vim.iter(vim.api.nvim_tabpage_list_wins(tab)):fold(0, function(count, win)
		local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
		return count + ((filetype == "gleb-file-tree" or filetype == "neo-tree") and 0 or 1)
	end)
	if editor_count == 1 then
		close_view(view)
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
		draw(view, path)
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
end

return M
