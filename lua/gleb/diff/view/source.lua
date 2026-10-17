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
---@field actionable boolean

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

---@param values string[]
---@return boolean
local function has_nul(values)
	for _, value in ipairs(values) do
		if value:find("\0", 1, true) then
			return true
		end
	end
	return false
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
	local prefix = git({ "rev-parse", "--show-prefix" }, directory)
	local relpath = vim.trim(prefix.stdout) .. vim.fs.basename(path)
	local left_result = git({ "show", "HEAD:" .. relpath }, root)
	local hash_result = git({ "rev-parse", "--short=7", "HEAD" }, root)
	local left = left_result.code == 0 and lines(left_result.stdout) or {}
	local right = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local unmerged = git({ "ls-files", "--unmerged", "--", relpath }, root)
	local diff_attr = git({ "check-attr", "diff", "--", relpath }, root)
	local binary_attr = diff_attr.code == 0 and diff_attr.stdout:match(": diff: unset%s*$") ~= nil
	return {
		path = path,
		root = root,
		relpath = relpath,
		left = left,
		right = right,
		hash = hash_result.code == 0 and vim.trim(hash_result.stdout) or "HEAD",
		filetype = vim.bo[buf].filetype,
		actionable = left_result.code == 0
			and unmerged.stdout == ""
			and not binary_attr
			and not left_result.stdout:find("\0", 1, true)
			and not has_nul(right),
	}
end

return M
