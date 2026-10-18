-- Pure ignored-path matching keeps glob policy independent from tree rendering and Git discovery.

local M = {}

---@class FileTreeIgnorePattern
---@field pattern vim.lpeg.Pattern
---@field path boolean
---@field directory boolean

---@class FileTreeIgnoreMatcher
---@field patterns FileTreeIgnorePattern[]

---@class FileTreeIgnoreError
---@field index integer
---@field reason string

--- Compile user globs, returning malformed patterns separately for the settings layer to report.
---@param globs string[]
---@return FileTreeIgnoreMatcher matcher
---@return FileTreeIgnoreError[] errors
function M.matcher(globs)
	local matcher = { patterns = {} }
	local errors = {}
	for index, glob in ipairs(globs) do
		local directory = vim.endswith(glob, "/")
		local source = directory and glob:sub(1, -2) or glob
		local ok, pattern = pcall(vim.glob.to_lpeg, source)
		if ok then
			matcher.patterns[#matcher.patterns + 1] = {
				pattern = pattern,
				path = source:find("/", 1, true) ~= nil,
				directory = directory,
			}
		else
			errors[#errors + 1] = { index = index, reason = tostring(pattern) }
		end
	end
	return matcher, errors
end

--- Return whether an entry is ignored by inherited, repository, or settings state.
---@param set table<string, boolean>
---@param matcher FileTreeIgnoreMatcher
---@param rel_path string
---@param is_dir boolean
---@param parent_ignored boolean
---@return boolean
function M.is_ignored(set, matcher, rel_path, is_dir, parent_ignored)
	if parent_ignored or set[rel_path] or (is_dir and set[rel_path .. "/"]) then
		return true
	end
	local name = rel_path:match("([^/]+)$") or rel_path
	for _, item in ipairs(matcher.patterns) do
		if (not item.directory or is_dir) and item.pattern:match(item.path and rel_path or name) then
			return true
		end
	end
	return false
end

return M
