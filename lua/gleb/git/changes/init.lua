-- Changes coordinates repository discovery and one panel per tab.

local M = {}

local fs = require("gleb.file_tree.fs")
local git = require("gleb.git.changes.git")
local view = require("gleb.git.changes.view")

---@class ChangesState
---@field by_tab table<integer, ChangesView>

---@type ChangesState
M.state = { by_tab = {} }

---@return string path
---@return string dir
local function current_location()
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" or path:match("^%w+://") then
		return "", fs.normalize(vim.fn.getcwd())
	end
	path = fs.normalize(path)
	return path, vim.fs.dirname(path)
end

---@param dir string
---@param selected_path string
---@return nil
local function resolve_and_open(dir, selected_path)
	local tab = vim.api.nvim_get_current_tabpage()
	git.resolve_root(dir, function(result, root)
		if vim.api.nvim_get_current_tabpage() ~= tab then
			return
		end
		if not root then
			vim.notify("Git root error: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			return
		end
		view.open(root, selected_path)
	end)
end

--- Toggle the current tab's Changes panel.
---@return nil
function M.toggle()
	local tab = vim.api.nvim_get_current_tabpage()
	local current = M.state.by_tab[tab]
	if current and vim.api.nvim_win_is_valid(current.win) then
		if vim.api.nvim_get_current_win() == current.win then
			view.close(current)
		else
			vim.api.nvim_set_current_win(current.win)
		end
		return
	end
	local path, dir = current_location()
	resolve_and_open(dir, path)
end

--- Open or focus the Changes panel for review.
---@return nil
function M.review()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if current and vim.api.nvim_win_is_valid(current.win) then
		vim.api.nvim_set_current_win(current.win)
		return
	end
	local path, dir = current_location()
	resolve_and_open(dir, path)
end

--- Open the Changes panel for a directory.
---@param opts { root: string }
---@return nil
function M.open(opts)
	resolve_and_open(opts.root, "")
end

--- Clear Changes panel state for tests.
---@return nil
function M.reset()
	M.state = { by_tab = {} }
end

require("gleb.git.changes.highlights").setup()

return M
