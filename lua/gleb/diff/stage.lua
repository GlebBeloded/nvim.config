-- Synchronous Git index access for one-change staging in the owned diff view.
-- Patch construction stays in patch.lua; this module owns process errors and notifications.

local M = {}

---@class gleb.diff.Index
---@field lines string[]
---@field final_newline boolean

---@param text string
---@return gleb.diff.Index
local function index_text(text)
	local final_newline = text:sub(-1) == "\n"
	if final_newline then
		text = text:sub(1, -2)
	end
	return {
		lines = text == "" and {} or vim.split(text, "\n", { plain = true }),
		final_newline = final_newline,
	}
end

---@param root string
---@param relpath string
---@return gleb.diff.Index?
---@return string?
function M.read(root, relpath)
	local result = vim.system({ "git", "show", ":" .. relpath }, { cwd = root, text = true }):wait()
	if result.code ~= 0 then
		return nil, vim.trim(result.stderr or "")
	end
	return index_text(result.stdout or ""), nil
end

---@param root string
---@param patch string
---@param include boolean
---@return boolean
function M.apply(root, patch, include)
	if patch == "" then
		return true
	end
	local result = vim.system(
		{ "git", "apply", "--cached", "--whitespace=nowarn", "-" },
		{ cwd = root, stdin = patch, text = true }
	):wait()
	if result.code ~= 0 then
		local operation = include and "Stage" or "Unstage"
		vim.notify(operation .. " failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
		return false
	end
	return true
end

return M
