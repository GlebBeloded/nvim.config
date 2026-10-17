-- Git-backed source acquisition for the current-file diff view.
-- Commands use argv lists and return data in Neovim's line model.

local M = {}

---@class gleb.diff.view.Source
---@field path string
---@field root string
---@field relpath string
---@field left string[]
---@field right string[]
---@field hash string
---@field filetype string

---@param args string[]
---@param cwd string
---@return vim.SystemCompleted
local function git(args, cwd)
	return vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
end

---@param text string
---@return string[]
local function lines(text)
	if text == "" then
		return {}
	end
	text = text:gsub("\n$", "")
	return vim.split(text, "\n", { plain = true })
end

---@param path string
---@param buf integer
---@return gleb.diff.view.Source?
---@return "not_repo"?
function M.current(path, buf)
	path = vim.fs.normalize(path)
	local directory = vim.fs.dirname(path)
	local root_result = git({ "rev-parse", "--show-toplevel" }, directory)
	if root_result.code ~= 0 then
		return nil, "not_repo"
	end
	local root = vim.trim(root_result.stdout)
	local tracked = git({ "ls-files", "--full-name", "--", path }, root)
	local relpath = tracked.code == 0 and vim.trim(tracked.stdout) or ""
	if relpath == "" then
		relpath = assert(vim.fs.relpath(root, path))
	end
	local left_result = git({ "show", "HEAD:" .. relpath }, root)
	local hash_result = git({ "rev-parse", "--short=7", "HEAD" }, root)
	local left = left_result.code == 0 and lines(left_result.stdout) or {}
	return {
		path = path,
		root = root,
		relpath = relpath,
		left = left,
		right = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
		hash = hash_result.code == 0 and vim.trim(hash_result.stdout) or "HEAD",
		filetype = vim.bo[buf].filetype,
	}
end

return M
