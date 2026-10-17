-- Computes per-change index state and patches without Git or editor state.
-- Keeping the range math pure lets the view stage exactly one displayed change.

local engine = require("gleb.diff.engine")

local M = {}

local UNCHECKED = "󰄱"
local CHECKED = "󰄲"
local MIXED = "󰡖"

---@alias gleb.diff.PatchChange gleb.diff.LineFragment

local function ranges_overlap(start1, end1, start2, end2)
	if start1 == end1 then
		return start2 <= start1 and start1 <= end2
	end
	if start2 == end2 then
		return start1 <= start2 and start2 <= end1
	end
	return start1 < end2 and start2 < end1
end

local function index_fragments(head, index)
	return engine.compare_lines(head, index, { highlight = "by_line" }).fragments
end

local function overlapping_fragments(fragments, current)
	local result = {}
	for _, fragment in ipairs(fragments) do
		if ranges_overlap(fragment.start1, fragment.end1, current.start1, current.end1) then
			result[#result + 1] = fragment
		end
	end
	return result
end

local function fragment_before(fragment, current)
	return fragment.end1 < current.start1
		or (fragment.end1 == current.start1 and fragment.start1 < fragment.end1 and current.start1 < current.end1)
end

local function fragment_after(fragment, current)
	return fragment.start1 > current.end1
		or (fragment.start1 == current.end1 and fragment.start1 < fragment.end1 and current.start1 < current.end1)
end

local function slices_equal(lines1, start1, end1, lines2, start2, end2)
	if end1 - start1 ~= end2 - start2 then
		return false
	end
	for offset = 0, end1 - start1 - 1 do
		if lines1[start1 + offset + 1] ~= lines2[start2 + offset + 1] then
			return false
		end
	end
	return true
end

local function append_range(result, lines, start_index, end_index)
	for index = start_index + 1, end_index do
		result[#result + 1] = lines[index]
	end
end

local function union_range(current, overlapping)
	local start_index = current.start1
	local end_index = current.end1
	for _, fragment in ipairs(overlapping) do
		start_index = math.min(start_index, fragment.start1)
		end_index = math.max(end_index, fragment.end1)
	end
	return start_index, end_index
end

local function index_range(fragments, overlapping, union_start, union_end)
	local delta_before = 0
	for _, fragment in ipairs(fragments) do
		if fragment.end1 < union_start or (fragment.end1 == union_start and fragment.start1 < fragment.end1) then
			delta_before = delta_before + (fragment.end2 - fragment.start2) - (fragment.end1 - fragment.start1)
		end
	end

	local overlap_delta = 0
	for _, fragment in ipairs(overlapping) do
		overlap_delta = overlap_delta + (fragment.end2 - fragment.start2) - (fragment.end1 - fragment.start1)
	end
	return union_start + delta_before, union_end + delta_before + overlap_delta
end

---@param index string[]
---@param right string[]
---@param current gleb.diff.PatchChange
---@param overlapping gleb.diff.LineFragment[]
---@return string
local function state_from_fragments(index, right, current, overlapping)
	if #overlapping == 0 then
		return UNCHECKED
	end

	local staged = overlapping[1]
	if
		#overlapping == 1
		and staged.start1 == current.start1
		and staged.end1 == current.end1
		and slices_equal(index, staged.start2, staged.end2, right, current.start2, current.end2)
	then
		return CHECKED
	end
	return MIXED
end

---@param head string[]
---@param index string[]
---@param right string[]
---@param current gleb.diff.PatchChange
---@return string
function M.state(head, index, right, current)
	local overlapping = overlapping_fragments(index_fragments(head, index), current)
	return state_from_fragments(index, right, current, overlapping)
end

---@param head string[]
---@param index string[]
---@param right string[]
---@param changes gleb.diff.PatchChange[] ordered, non-overlapping ranges
---@return string[]
function M.states(head, index, right, changes)
	local staged = index_fragments(head, index)
	local states = {}
	local staged_index = 1
	for change_index, current in ipairs(changes) do
		while staged[staged_index] and fragment_before(staged[staged_index], current) do
			staged_index = staged_index + 1
		end
		local overlapping = {}
		local candidate = staged_index
		while staged[candidate] and not fragment_after(staged[candidate], current) do
			if ranges_overlap(staged[candidate].start1, staged[candidate].end1, current.start1, current.end1) then
				overlapping[#overlapping + 1] = staged[candidate]
			end
			candidate = candidate + 1
		end
		states[change_index] = state_from_fragments(index, right, current, overlapping)
	end
	return states
end

local function overlaps_outside_current(overlapping, current)
	for _, fragment in ipairs(overlapping) do
		if fragment.start1 < current.start1 or fragment.end1 > current.end1 then
			return true
		end
	end
	return false
end

---@param head string[]
---@param index string[]
---@param right string[]
---@param current gleb.diff.PatchChange
---@param include boolean
---@return string[]?
---@return string?
function M.update_index(head, index, right, current, include)
	local fragments = index_fragments(head, index)
	local overlapping = overlapping_fragments(fragments, current)
	if overlaps_outside_current(overlapping, current) then
		return nil, "overlaps other staged lines"
	end
	local union_start, union_end = union_range(current, overlapping)
	local index_start, index_end = index_range(fragments, overlapping, union_start, union_end)
	local result = {}

	append_range(result, index, 0, index_start)
	if include then
		append_range(result, head, union_start, current.start1)
		append_range(result, right, current.start2, current.end2)
		append_range(result, head, current.end1, union_end)
	else
		append_range(result, head, union_start, union_end)
	end
	append_range(result, index, index_end, #index)
	return result
end

local function lines_text(lines, final_newline)
	local text = table.concat(lines, "\n")
	if final_newline then
		return text .. "\n"
	end
	return text
end

---@param path string
---@param old_lines string[]
---@param new_lines string[]
---@param old_final_newline boolean
---@param new_final_newline boolean
---@return string
function M.make_patch(path, old_lines, new_lines, old_final_newline, new_final_newline)
	local old_text = lines_text(old_lines, old_final_newline)
	local new_text = lines_text(new_lines, new_final_newline)
	if old_text == new_text then
		return ""
	end
	local body = vim.text.diff(old_text, new_text, { result_type = "unified", ctxlen = 3 })
	return ("diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n%s"):format(path, path, path, path, body)
end

return M
