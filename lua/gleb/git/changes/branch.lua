-- Branch-change helpers turn Git's NUL-delimited output into stable model inputs.

local M = {}

---@class ChangesBranchFile
---@field status "added"|"modified"|"deleted"|"renamed"
---@field path string
---@field orig? string

local STATUS_NAMES = {
	A = "added",
	D = "deleted",
	M = "modified",
}

---@param count integer
---@param merge_base string
---@return string
function M.summary(count, merge_base)
	local noun = count == 1 and "commit" or "commits"
	return string.format("%d %s · merge-base %s", count, noun, merge_base:sub(1, 7))
end

---@param output string
---@return ChangesBranchFile[]
function M.parse_name_status(output)
	local fields = vim.split(output, "\0", { plain = true, trimempty = true })
	local files = {}
	local index = 1
	while index <= #fields do
		local code = fields[index]
		local kind = code:sub(1, 1)
		if kind == "R" or kind == "C" then
			table.insert(files, { status = "renamed", orig = fields[index + 1], path = fields[index + 2] })
			index = index + 3
		else
			table.insert(files, { status = STATUS_NAMES[kind] or "modified", path = fields[index + 1] })
			index = index + 2
		end
	end
	return files
end

return M
