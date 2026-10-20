-- Branch-change helpers turn Git's NUL-delimited output into stable model inputs.

local M = {}

---@class ChangesBranchFile
---@field status "added"|"modified"|"deleted"|"renamed"
---@field path string
---@field orig? string

---@class ChangesBranchCommit
---@field hash string
---@field parents string[]
---@field timestamp integer
---@field subject string

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

---@param seconds integer
---@return string
function M.age(seconds)
	if seconds < 60 then
		return "now"
	elseif seconds < 60 * 60 then
		return math.floor(seconds / 60) .. "m"
	elseif seconds < 24 * 60 * 60 then
		return math.floor(seconds / (60 * 60)) .. "h"
	elseif seconds < 14 * 24 * 60 * 60 then
		return math.floor(seconds / (24 * 60 * 60)) .. "d"
	elseif seconds < 60 * 24 * 60 * 60 then
		return math.floor(seconds / (7 * 24 * 60 * 60)) .. "w"
	elseif seconds < 365 * 24 * 60 * 60 then
		return math.floor(seconds / (30 * 24 * 60 * 60)) .. "mo"
	end
	return math.floor(seconds / (365 * 24 * 60 * 60)) .. "y"
end

---@return integer
function M.now()
	return os.time()
end

---@param output string
---@return ChangesBranchCommit[]
function M.parse_commits(output)
	local commits = {}
	local records = vim.split(output, "\0\0", { plain = true, trimempty = true })
	for _, record in ipairs(records) do
		local fields = vim.split(record, "\0", { plain = true })
		table.insert(commits, {
			hash = fields[1],
			parents = vim.split(fields[2], " ", { plain = true, trimempty = true }),
			timestamp = assert(tonumber(fields[3]), "invalid commit timestamp"),
			subject = fields[4],
		})
	end
	return commits
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
