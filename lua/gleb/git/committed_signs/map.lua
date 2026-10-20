-- Classify branch-committed lines and move their signs through unsaved edits without plugin state.
local M = {}

---@alias GlebCommittedSignKind "add"|"change"|"changedelete"|"delete"|"topdelete"
---@alias GlebCommittedSignKinds table<integer, GlebCommittedSignKind>

local DIFF_OPTIONS = {
	result_type = "indices",
	algorithm = "myers",
	indent_heuristic = true,
}

---@param lines string[]
---@return string
local function text(lines)
	return table.concat(lines, "\n")
end

---@param before string[]
---@param after string[]
---@return integer[][]
local function hunks(before, after)
	local result = vim.text.diff(text(before), text(after), DIFF_OPTIONS)
	---@cast result integer[][]
	return result
end

---@param base_lines string[]
---@param head_lines string[]
---@return GlebCommittedSignKinds
function M.kinds(base_lines, head_lines)
	local result = {}

	for _, hunk in ipairs(hunks(base_lines, head_lines)) do
		local a_count, b_start, b_count = hunk[2], hunk[3], hunk[4]
		if b_count == 0 then
			local line = math.max(1, b_start)
			result[line] = b_start == 0 and "topdelete" or "delete"
		else
			local kind = a_count == 0 and "add" or "change"
			for line = b_start, b_start + b_count - 1 do
				result[line] = kind
			end
			if a_count > b_count then
				result[b_start + b_count - 1] = "changedelete"
			end
		end
	end

	return result
end

---@param head_lines string[]
---@param buf_lines string[]
---@param kinds GlebCommittedSignKinds
---@return GlebCommittedSignKinds
function M.to_buffer(head_lines, buf_lines, kinds)
	local local_hunks = hunks(head_lines, buf_lines)
	local lines = vim.tbl_keys(kinds)
	table.sort(lines)

	local result = {}
	local hunk_index = 1
	local offset = 0

	for _, line in ipairs(lines) do
		local dropped = false
		while hunk_index <= #local_hunks do
			local hunk = local_hunks[hunk_index]
			local a_start, a_count, b_count = hunk[1], hunk[2], hunk[4]
			local ends_before = a_count == 0 and a_start < line or a_start + a_count - 1 < line
			if ends_before then
				offset = offset + b_count - a_count
				hunk_index = hunk_index + 1
			elseif a_count > 0 and line >= a_start then
				dropped = line < a_start + a_count
				break
			else
				break
			end
		end
		if not dropped then
			result[line + offset] = kinds[line]
		end
	end

	return result
end

return M
