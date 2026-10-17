-- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/ChunkOptimizer.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/smart_align.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- IntelliJ LineChunkOptimizer for stable boundaries around blank and short lines.
-- It slides equivalent LCS alignments without changing the number of matched lines.

local ranges = require("gleb.diff.engine.ranges")
local trim = require("gleb.diff.engine.trim")

local M = {}

local UNIMPORTANT_LINE_CHAR_COUNT = 3

local function find_next_unimportant(lines, offset, count, threshold)
	for shift = 0, count - 1 do
		local line = lines[offset + shift + 1]
		if not line then
			return -1
		end
		if line.nonspace <= threshold then
			return shift
		end
	end
	return -1
end

local function find_previous_unimportant(lines, offset, count, threshold)
	for shift = 0, count - 1 do
		local line = lines[offset - shift + 1]
		if not line then
			return -1
		end
		if line.nonspace <= threshold then
			return shift
		end
	end
	return -1
end

local function pick_shift(forward, backward)
	if forward == -1 and backward == -1 then
		return nil
	end
	if forward == 0 or backward == 0 then
		return 0
	end
	if forward ~= -1 then
		return forward
	end
	return -backward
end

local function boundary_shift(lines1, lines2, touch_left, equal_forward, equal_backward, range1, range2)
	for _, choice in ipairs({
		{ threshold = 0, changed = false },
		{ threshold = 0, changed = true },
		{ threshold = UNIMPORTANT_LINE_CHAR_COUNT, changed = false },
		{ threshold = UNIMPORTANT_LINE_CHAR_COUNT, changed = true },
	}) do
		local lines
		local forward_start
		local backward_start
		if choice.changed then
			lines = touch_left and lines2 or lines1
			forward_start = touch_left and range1.end2 or range1.end1
			backward_start = (touch_left and range2.start2 or range2.start1) - 1
		else
			lines = touch_left and lines1 or lines2
			forward_start = touch_left and range2.start1 or range2.start2
			backward_start = forward_start - 1
		end
		local shift = pick_shift(
			find_next_unimportant(lines, forward_start, equal_forward + 1, choice.threshold),
			find_previous_unimportant(lines, backward_start, equal_backward + 1, choice.threshold)
		)
		if shift ~= nil then
			return shift
		end
	end
	return 0
end

---@param lines1 gleb.diff.Line[]
---@param lines2 gleb.diff.Line[]
---@param changes gleb.diff.LineFragment[]
---@param equals fun(index1: integer, index2: integer): boolean
---@param context gleb.diff.Context
---@return gleb.diff.LineFragment[], gleb.diff.LcsStatus
function M.optimize(lines1, lines2, changes, equals, context)
	local unchanged = ranges.unchanged_from_changes(changes, #lines1, #lines2)
	local optimized = {}

	local function process_last_ranges()
		while #optimized >= 2 do
			local range1 = optimized[#optimized - 1]
			local range2 = optimized[#optimized]
			if range1.end1 ~= range2.start1 and range1.end2 ~= range2.start2 then
				return
			end
			local count1 = range1.end1 - range1.start1
			local count2 = range2.end1 - range2.start1
			local equal_forward =
				trim.expand_forward(range1.end1, range1.end2, range1.end1 + count2, range1.end2 + count2, equals)
			local equal_backward = trim.expand_backward(
				range2.start1 - count1,
				range2.start2 - count1,
				range2.start1,
				range2.start2,
				equals
			)
			if equal_forward == 0 and equal_backward == 0 then
				return
			end

			optimized[#optimized] = nil
			optimized[#optimized] = nil
			if equal_forward == count2 then
				optimized[#optimized + 1] = {
					start1 = range1.start1,
					end1 = range1.end1 + count2,
					start2 = range1.start2,
					end2 = range1.end2 + count2,
				}
			elseif equal_backward == count1 then
				optimized[#optimized + 1] = {
					start1 = range2.start1 - count1,
					end1 = range2.end1,
					start2 = range2.start2 - count1,
					end2 = range2.end2,
				}
			else
				local touch_left = range1.end1 == range2.start1
				local shift = boundary_shift(lines1, lines2, touch_left, equal_forward, equal_backward, range1, range2)
				optimized[#optimized + 1] = {
					start1 = range1.start1,
					end1 = range1.end1 + shift,
					start2 = range1.start2,
					end2 = range1.end2 + shift,
				}
				optimized[#optimized + 1] = {
					start1 = range2.start1 + shift,
					end1 = range2.end1,
					start2 = range2.start2 + shift,
					end2 = range2.end2,
				}
				return
			end
		end
	end

	for _, range in ipairs(unchanged) do
		if context.clock() > context.deadline then
			return {}, "timed_out"
		end
		optimized[#optimized + 1] = range
		process_last_ranges()
	end
	return ranges.changes_from_unchanged(optimized, #lines1, #lines2), "ok"
end

local function has_whitespace(text, start_offset, end_offset)
	for index = start_offset + 1, end_offset do
		local byte = text:byte(index)
		if byte == 0x20 or byte == 0x09 or byte == 0x0a then
			return true
		end
	end
	return false
end

local function words_separated(text, left, right)
	return left.newline or right.newline or has_whitespace(text, left.end_offset, right.start_offset)
end

local function sequence_edge_shift(text, words, offset, count, forward)
	for shift = 0, count - 1 do
		local left
		local right
		if forward then
			left = words[offset + shift + 1]
			right = words[offset + shift + 2]
		else
			left = words[offset - shift]
			right = words[offset - shift + 1]
		end
		if not left or not right then
			return -1
		end
		if words_separated(text, left, right) then
			return shift + 1
		end
	end
	return -1
end

---@param text1 string
---@param text2 string
---@param words1 gleb.diff.Word[]
---@param words2 gleb.diff.Word[]
---@param unchanged gleb.diff.LineFragment[]
---@return gleb.diff.LineFragment[]
function M.optimize_words(text1, text2, words1, words2, unchanged)
	local optimized = {}
	local function equals(index1, index2)
		return words1[index1 + 1].key == words2[index2 + 1].key
	end
	local function process_last_ranges()
		while #optimized >= 2 do
			local left = optimized[#optimized - 1]
			local right = optimized[#optimized]
			if left.end1 ~= right.start1 and left.end2 ~= right.start2 then
				return
			end
			local count1 = left.end1 - left.start1
			local count2 = right.end1 - right.start1
			local forward = trim.expand_forward(left.end1, left.end2, left.end1 + count2, left.end2 + count2, equals)
			local backward =
				trim.expand_backward(right.start1 - count1, right.start2 - count1, right.start1, right.start2, equals)
			if forward == 0 and backward == 0 then
				return
			end
			optimized[#optimized] = nil
			optimized[#optimized] = nil
			if forward == count2 then
				optimized[#optimized + 1] = {
					start1 = left.start1,
					end1 = left.end1 + count2,
					start2 = left.start2,
					end2 = left.end2 + count2,
				}
			elseif backward == count1 then
				optimized[#optimized + 1] = {
					start1 = right.start1 - count1,
					end1 = right.end1,
					start2 = right.start2 - count1,
					end2 = right.end2,
				}
			else
				local touch_left = left.end1 == right.start1
				local touch_words = touch_left and words1 or words2
				local touch_text = touch_left and text1 or text2
				local touch_start = touch_left and right.start1 or right.start2
				local before = touch_words[touch_start]
				local at = touch_words[touch_start + 1]
				local shift = 0
				if before and at and not words_separated(touch_text, before, at) then
					shift = sequence_edge_shift(touch_text, touch_words, touch_start, forward, true)
					if shift < 0 then
						local backward_shift =
							sequence_edge_shift(touch_text, touch_words, touch_start - 1, backward, false)
						shift = backward_shift > 0 and -backward_shift or 0
					end
				end
				optimized[#optimized + 1] = {
					start1 = left.start1,
					end1 = left.end1 + shift,
					start2 = left.start2,
					end2 = left.end2 + shift,
				}
				optimized[#optimized + 1] = {
					start1 = right.start1 + shift,
					end1 = right.end1,
					start2 = right.start2 + shift,
					end2 = right.end2,
				}
				return
			end
		end
	end
	for _, range in ipairs(unchanged) do
		optimized[#optimized + 1] = range
		process_last_ranges()
	end
	return optimized
end

return M
