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

---@type FileTreeViewState
M.state = { by_tab = {} }

local view_group

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
local function add_teardown_autocmds(view)
	view.autocmds = {
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
	M.state = { by_tab = {} }
end

--- Set up project-tree rendering and lifecycle hooks.
---@return nil
function M.setup()
	render.setup()
	view_group = vim.api.nvim_create_augroup("gleb_file_tree_view", { clear = true })
	vim.api.nvim_create_autocmd("QuitPre", { group = view_group, callback = on_quit_pre })
end

return M
