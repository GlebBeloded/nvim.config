-- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/ByCharRt.kt
-- and ChangeCorrector.kt (Apache-2.0, © JetBrains s.r.o.).
-- Modified: rewritten in Lua with UTF-8 byte offsets; see NOTICE.
-- Character comparison and whitespace-policy correction for inner fragments.

local lcs = require("gleb.diff.engine.lcs")
local ranges = require("gleb.diff.engine.ranges")
local trim = require("gleb.diff.engine.trim")

local M = {}

local function unbounded_context()
	return {
		clock = function()
			return 0
		end,
		deadline = math.huge,
		myers_threshold = 20000,
	}
end

local function is_continuation(byte)
	return byte ~= nil and byte >= 0x80 and byte < 0xc0
end

local function codepoint_at(text, index)
	local first = text:byte(index)
	if first < 0x80 then
		return first, 1
	end
	local second = text:byte(index + 1)
	if first >= 0xc2 and first <= 0xdf and is_continuation(second) then
		return (first - 0xc0) * 0x40 + second - 0x80, 2
	end
	local third = text:byte(index + 2)
	if
		first >= 0xe0
		and first <= 0xef
		and is_continuation(second)
		and is_continuation(third)
		and not (first == 0xe0 and second < 0xa0)
		and not (first == 0xed and second >= 0xa0)
	then
		return (first - 0xe0) * 0x1000 + (second - 0x80) * 0x40 + third - 0x80, 3
	end
	local fourth = text:byte(index + 3)
	if
		first >= 0xf0
		and first <= 0xf4
		and is_continuation(second)
		and is_continuation(third)
		and is_continuation(fourth)
		and not (first == 0xf0 and second < 0x90)
		and not (first == 0xf4 and second >= 0x90)
	then
		return (first - 0xf0) * 0x40000 + (second - 0x80) * 0x1000 + (third - 0x80) * 0x40 + fourth - 0x80, 4
	end
	return first, 1
end

local function codepoints(text, predicate)
	local values = {}
	local offsets = {}
	local widths = {}
	local index = 1
	while index <= #text do
		local value, width = codepoint_at(text, index)
		if not predicate or predicate(value) then
			values[#values + 1] = value
			offsets[#offsets + 1] = index - 1
			widths[#widths + 1] = width
		end
		index = index + width
	end
	return { values = values, offsets = offsets, widths = widths }
end

local function is_whitespace(codepoint)
	return codepoint == 0x20 or codepoint == 0x09 or codepoint == 0x0a
end

local function whitespace_at(text, offset)
	local byte = text:byte(offset + 1)
	return byte == 0x20 or byte == 0x09 or byte == 0x0a
end

local function new_change_builder(length1, length2)
	local builder = { index1 = 0, index2 = 0, changes = {} }
	function builder.mark_equal(start1, start2, end1, end2)
		if start1 == end1 and start2 == end2 then
			return
		end
		if builder.index1 ~= start1 or builder.index2 ~= start2 then
			builder.changes[#builder.changes + 1] = {
				start1 = builder.index1,
				end1 = start1,
				start2 = builder.index2,
				end2 = start2,
			}
		end
		builder.index1 = end1
		builder.index2 = end2
	end
	function builder.finish()
		if builder.index1 ~= length1 or builder.index2 ~= length2 then
			builder.changes[#builder.changes + 1] = {
				start1 = builder.index1,
				end1 = length1,
				start2 = builder.index2,
				end2 = length2,
			}
		end
		return builder.changes
	end
	return builder
end

local function sorted_matches(values1, values2, context)
	local result = lcs.diff(values1, values2, context)
	table.sort(result.matches, function(left, right)
		if left[1] == right[1] then
			return left[2] < right[2]
		end
		return left[1] < right[1]
	end)
	return result.matches, result.status
end

local function compare_data(data1, data2, length1, length2, context)
	local matches, status = sorted_matches(data1.values, data2.values, context)
	if status ~= "ok" then
		return {}, status
	end
	local builder = new_change_builder(length1, length2)
	for _, match in ipairs(matches) do
		local index1 = match[1] + 1
		local index2 = match[2] + 1
		builder.mark_equal(
			data1.offsets[index1],
			data2.offsets[index2],
			data1.offsets[index1] + data1.widths[index1],
			data2.offsets[index2] + data2.widths[index2]
		)
	end
	return builder.finish(), "ok"
end

---@param text1 string
---@param text2 string
---@param context? gleb.diff.Context
---@return gleb.diff.InnerFragment[], gleb.diff.LcsStatus
function M.compare(text1, text2, context)
	context = context or unbounded_context()
	return compare_data(codepoints(text1), codepoints(text2), #text1, #text2, context)
end

local function nonspace_codepoints(text)
	return codepoints(text, function(value)
		return not is_whitespace(value)
	end)
end

local function mark_gap(builder, text1, text2, start1, end1, start2, end2, context)
	local changes, status = M.compare(text1:sub(start1 + 1, end1), text2:sub(start2 + 1, end2), context)
	if status ~= "ok" then
		return status
	end
	for _, range in ipairs(ranges.unchanged_from_changes(changes, end1 - start1, end2 - start2)) do
		builder.mark_equal(start1 + range.start1, start2 + range.start2, start1 + range.end1, start2 + range.end2)
	end
	return "ok"
end

---@param text1 string
---@param text2 string
---@param context? gleb.diff.Context
---@return gleb.diff.InnerFragment[], gleb.diff.LcsStatus
function M.compare_two_step(text1, text2, context)
	context = context or unbounded_context()
	local data1 = nonspace_codepoints(text1)
	local data2 = nonspace_codepoints(text2)
	local matches, status = sorted_matches(data1.values, data2.values, context)
	if status ~= "ok" then
		return {}, status
	end
	local builder = new_change_builder(#text1, #text2)
	local last1 = 0
	local last2 = 0
	for _, match in ipairs(matches) do
		local index1 = match[1] + 1
		local index2 = match[2] + 1
		local start1 = data1.offsets[index1]
		local start2 = data2.offsets[index2]
		status = mark_gap(builder, text1, text2, last1, start1, last2, start2, context)
		if status ~= "ok" then
			return {}, status
		end
		local end1 = start1 + data1.widths[index1]
		local end2 = start2 + data2.widths[index2]
		builder.mark_equal(start1, start2, end1, end2)
		last1 = end1
		last2 = end2
	end
	status = mark_gap(builder, text1, text2, last1, #text1, last2, #text2, context)
	if status ~= "ok" then
		return {}, status
	end
	return builder.finish(), "ok"
end

---@param text1 string
---@param text2 string
---@param context gleb.diff.Context
---@return gleb.diff.InnerFragment[], gleb.diff.LcsStatus
function M.compare_punctuation(text1, text2, context)
	local data1 = codepoints(text1, trim.is_punctuation)
	local data2 = codepoints(text2, trim.is_punctuation)
	return compare_data(data1, data2, #text1, #text2, context)
end

local function trim_start(text, start_offset, end_offset)
	while start_offset < end_offset and whitespace_at(text, start_offset) do
		start_offset = start_offset + 1
	end
	return start_offset
end

local function trim_end(text, start_offset, end_offset)
	while start_offset < end_offset and whitespace_at(text, end_offset - 1) do
		end_offset = end_offset - 1
	end
	return end_offset
end

local function is_leading_space(text, offset)
	if offset < 0 or offset == #text or not whitespace_at(text, offset) then
		return false
	end
	offset = offset - 1
	while offset >= 0 do
		local byte = text:byte(offset + 1)
		if byte == 0x0a then
			return true
		end
		if not whitespace_at(text, offset) then
			return false
		end
		offset = offset - 1
	end
	return true
end

local function is_trailing_space(text, offset)
	if offset < 0 or offset == #text or not whitespace_at(text, offset) then
		return false
	end
	while offset < #text do
		local byte = text:byte(offset + 1)
		if byte == 0x0a then
			return true
		end
		if not whitespace_at(text, offset) then
			return false
		end
		offset = offset + 1
	end
	return true
end

local function trim_spaces(changes, text1, text2)
	local result = {}
	for _, range in ipairs(changes) do
		local start1 = range.start1
		local end1 = range.end1
		local start2 = range.start2
		local end2 = range.end2
		if is_leading_space(text1, start1) or is_trailing_space(text1, start1) then
			start1 = trim_start(text1, start1, end1)
		end
		if is_leading_space(text1, end1 - 1) or is_trailing_space(text1, end1 - 1) then
			end1 = trim_end(text1, start1, end1)
		end
		if is_leading_space(text2, start2) or is_trailing_space(text2, start2) then
			start2 = trim_start(text2, start2, end2)
		end
		if is_leading_space(text2, end2 - 1) or is_trailing_space(text2, end2 - 1) then
			end2 = trim_end(text2, start2, end2)
		end
		if (start1 ~= end1 or start2 ~= end2) and text1:sub(start1 + 1, end1) ~= text2:sub(start2 + 1, end2) then
			result[#result + 1] = { start1 = start1, end1 = end1, start2 = start2, end2 = end2 }
		end
	end
	return result
end

local function offset_after_previous(data, index)
	if index == 0 then
		return 0
	end
	return data.offsets[index] + data.widths[index]
end

local function expand_whitespace_forward(text1, text2, start1, start2)
	local count = 0
	while
		start1 + count < #text1
		and start2 + count < #text2
		and text1:byte(start1 + count + 1) == text2:byte(start2 + count + 1)
		and whitespace_at(text1, start1 + count)
	do
		count = count + 1
	end
	return count
end

local function ignore_spaces(text1, text2, context)
	local data1 = nonspace_codepoints(text1)
	local data2 = nonspace_codepoints(text2)
	local lcs_result = lcs.diff(data1.values, data2.values, context)
	if lcs_result.status ~= "ok" then
		return {}, lcs_result.status
	end
	local changes = ranges.from_matches(lcs_result.matches, #data1.values, #data2.values)
	local result = {}
	for _, change in ipairs(changes) do
		local start1
		local end1
		if change.start1 == change.end1 then
			local base1 = offset_after_previous(data1, change.start1)
			local base2 = offset_after_previous(data2, change.start2)
			end1 = base1 + expand_whitespace_forward(text1, text2, base1, base2)
			start1 = end1
		else
			start1 = data1.offsets[change.start1 + 1]
			end1 = data1.offsets[change.end1] + data1.widths[change.end1]
		end
		local start2
		local end2
		if change.start2 == change.end2 then
			local base1 = offset_after_previous(data1, change.start1)
			local base2 = offset_after_previous(data2, change.start2)
			end2 = base2 + expand_whitespace_forward(text1, text2, base1, base2)
			start2 = end2
		else
			start2 = data2.offsets[change.start2 + 1]
			end2 = data2.offsets[change.end2] + data2.widths[change.end2]
		end
		result[#result + 1] = { start1 = start1, end1 = end1, start2 = start2, end2 = end2 }
	end
	return result, "ok"
end

---@param text1 string
---@param text2 string
---@param comparison_policy gleb.diff.Policy
---@param context gleb.diff.Context
---@return gleb.diff.InnerFragment[], gleb.diff.LcsStatus
function M.compare_policy(text1, text2, comparison_policy, context)
	if comparison_policy == "ignore_whitespaces" or comparison_policy == "ignore_whitespaces_chunks" then
		return ignore_spaces(text1, text2, context)
	end
	local changes, status = M.compare_two_step(text1, text2, context)
	if status ~= "ok" then
		return {}, status
	end
	if comparison_policy == "trim_whitespaces" then
		changes = trim_spaces(changes, text1, text2)
	end
	return changes, "ok"
end

return M
