-- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/ByWordRt.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/word_diff.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- Word-level comparison used by the inner phase.

local by_char = require("gleb.diff.engine.by_char")
local lcs = require("gleb.diff.engine.lcs")
local optimizer = require("gleb.diff.engine.optimizer")
local policy = require("gleb.diff.engine.policy")
local ranges = require("gleb.diff.engine.ranges")
local split = require("gleb.diff.engine.split")
local trim = require("gleb.diff.engine.trim")

local M = {}

---@class gleb.diff.Word
---@field start_offset integer
---@field end_offset integer
---@field newline boolean
---@field key string

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

---@param text string
---@return gleb.diff.Word[]
function M.inline_chunks(text)
	local chunks = {}
	local index = 1
	local word_start
	while index <= #text do
		local codepoint, width = codepoint_at(text, index)
		local alpha = trim.is_alpha(codepoint)
		local word_part = alpha and not trim.is_continuous_script(codepoint)
		if word_part then
			word_start = word_start or index - 1
		else
			if word_start then
				chunks[#chunks + 1] = {
					start_offset = word_start,
					end_offset = index - 1,
					newline = false,
					key = text:sub(word_start + 1, index - 1),
				}
				word_start = nil
			end
			if alpha then
				chunks[#chunks + 1] = {
					start_offset = index - 1,
					end_offset = index - 1 + width,
					newline = false,
					key = text:sub(index, index + width - 1),
				}
			elseif codepoint == 0x0a then
				chunks[#chunks + 1] = {
					start_offset = index - 1,
					end_offset = index,
					newline = true,
					key = "\n",
				}
			end
		end
		index = index + width
	end
	if word_start then
		chunks[#chunks + 1] = {
			start_offset = word_start,
			end_offset = #text,
			newline = false,
			key = text:sub(word_start + 1),
		}
	end
	return chunks
end

local function word_keys(words)
	local keys = {}
	for index, word in ipairs(words) do
		keys[index] = word.key
	end
	return keys
end

local function compare_words(text1, text2, context)
	local words1 = M.inline_chunks(text1)
	local words2 = M.inline_chunks(text2)
	local lcs_result = lcs.diff(word_keys(words1), word_keys(words2), context)
	if lcs_result.status ~= "ok" then
		return words1, words2, {}, lcs_result.status
	end
	local changes = ranges.from_matches(lcs_result.matches, #words1, #words2)
	local unchanged = ranges.unchanged_from_changes(changes, #words1, #words2)
	unchanged = optimizer.optimize_words(text1, text2, words1, words2, unchanged)
	return words1, words2, unchanged, "ok"
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

local function punctuation_matches(text1, text2, context)
	local changes, status = by_char.compare_punctuation(text1, text2, context)
	if status ~= "ok" then
		return {}, status
	end
	return ranges.unchanged_from_changes(changes, #text1, #text2), "ok"
end

local function match_adjustment_delimiters(text1, text2, words1, words2, unchanged, context)
	local builder = new_change_builder(#text1, #text2)
	local last

	local function start_offset(words, index)
		return words[index + 1].start_offset
	end

	local function end_offset(words, index)
		return words[index + 1].end_offset
	end

	local function match_range(start1, start2, end1, end2)
		if start1 == end1 and start2 == end2 then
			return "ok"
		end
		local matches, status = punctuation_matches(text1:sub(start1 + 1, end1), text2:sub(start2 + 1, end2), context)
		if status ~= "ok" then
			return status
		end
		for _, match in ipairs(matches) do
			builder.mark_equal(start1 + match.start1, start2 + match.start2, start1 + match.end1, start2 + match.end2)
		end
		return "ok"
	end

	local function match_complex(one_text, one_start, two_a, start_a, two_b, start_b, mirrored)
		local matches, status = punctuation_matches(one_text, two_a .. two_b, context)
		if status ~= "ok" then
			return status
		end
		local seam = #two_a
		for _, match in ipairs(matches) do
			local pieces
			if match.end2 <= seam then
				pieces = { { match.start1, match.end1, match.start2, match.end2, start_a } }
			elseif match.start2 >= seam then
				pieces = { { match.start1, match.end1, match.start2 - seam, match.end2 - seam, start_b } }
			else
				local first_length = seam - match.start2
				pieces = {
					{ match.start1, match.start1 + first_length, match.start2, seam, start_a },
					{ match.start1 + first_length, match.end1, 0, match.end2 - seam, start_b },
				}
			end
			for _, piece in ipairs(pieces) do
				if mirrored then
					builder.mark_equal(
						piece[5] + piece[3],
						one_start + piece[1],
						piece[5] + piece[4],
						one_start + piece[2]
					)
				else
					builder.mark_equal(
						one_start + piece[1],
						piece[5] + piece[3],
						one_start + piece[2],
						piece[5] + piece[4]
					)
				end
			end
		end
		return "ok"
	end

	local function match_backward_range(start1, start2, end1, end2)
		if last.start1 == start1 and last.start2 == start2 then
			return match_range(start1, start2, end1, end2)
		end
		if last.start1 < start1 and last.start2 < start2 then
			local status = match_range(last.start1, last.start2, last.end1, last.end2)
			if status ~= "ok" then
				return status
			end
			return match_range(start1, start2, end1, end2)
		end
		if last.start1 == start1 and last.end1 == end1 then
			return match_complex(
				text1:sub(start1 + 1, end1),
				start1,
				text2:sub(last.start2 + 1, last.end2),
				last.start2,
				text2:sub(start2 + 1, end2),
				start2,
				false
			)
		end
		return match_complex(
			text2:sub(start2 + 1, end2),
			start2,
			text1:sub(last.start1 + 1, last.end1),
			last.start1,
			text1:sub(start1 + 1, end1),
			start1,
			true
		)
	end

	local function match_backward(index1, index2)
		local start1 = index1 == 0 and 0 or end_offset(words1, index1 - 1)
		local start2 = index2 == 0 and 0 or end_offset(words2, index2 - 1)
		local end1 = index1 == #words1 and #text1 or start_offset(words1, index1)
		local end2 = index2 == #words2 and #text2 or start_offset(words2, index2)
		local status = match_backward_range(start1, start2, end1, end2)
		last = nil
		return status
	end

	local function match_forward(index1, index2)
		local start1 = index1 == -1 and 0 or end_offset(words1, index1)
		local start2 = index2 == -1 and 0 or end_offset(words2, index2)
		local end1 = index1 + 1 == #words1 and #text1 or start_offset(words1, index1 + 1)
		local end2 = index2 + 1 == #words2 and #text2 or start_offset(words2, index2 + 1)
		last = { start1 = start1, start2 = start2, end1 = end1, end2 = end2 }
	end

	match_forward(-1, -1)
	for _, range in ipairs(unchanged) do
		for offset = 0, range.end1 - range.start1 - 1 do
			local index1 = range.start1 + offset
			local index2 = range.start2 + offset
			local status = match_backward(index1, index2)
			if status ~= "ok" then
				return {}, status
			end
			builder.mark_equal(
				start_offset(words1, index1),
				start_offset(words2, index2),
				end_offset(words1, index1),
				end_offset(words2, index2)
			)
			match_forward(index1, index2)
		end
	end
	local status = match_backward(#words1, #words2)
	if status ~= "ok" then
		return {}, status
	end
	return builder.finish(), "ok"
end

local function whitespace_at(text, offset)
	local byte = text:byte(offset + 1)
	return byte == 0x20 or byte == 0x09 or byte == 0x0a
end

local function default_corrector(changes, text1, text2)
	local result = {}
	for _, range in ipairs(changes) do
		local end_cut = 0
		while
			range.start1 < range.end1 - end_cut
			and range.start2 < range.end2 - end_cut
			and text1:byte(range.end1 - end_cut) == text2:byte(range.end2 - end_cut)
			and whitespace_at(text1, range.end1 - end_cut - 1)
		do
			end_cut = end_cut + 1
		end
		local start_cut = 0
		while
			range.start1 + start_cut < range.end1 - end_cut
			and range.start2 + start_cut < range.end2 - end_cut
			and text1:byte(range.start1 + start_cut + 1) == text2:byte(range.start2 + start_cut + 1)
			and whitespace_at(text1, range.start1 + start_cut)
		do
			start_cut = start_cut + 1
		end
		local corrected = {
			start1 = range.start1 + start_cut,
			end1 = range.end1 - end_cut,
			start2 = range.start2 + start_cut,
			end2 = range.end2 - end_cut,
		}
		if corrected.start1 ~= corrected.end1 or corrected.start2 ~= corrected.end2 then
			result[#result + 1] = corrected
		end
	end
	return result
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
		if text:byte(offset + 1) == 0x0a then
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
		if text:byte(offset + 1) == 0x0a then
			return true
		end
		if not whitespace_at(text, offset) then
			return false
		end
		offset = offset + 1
	end
	return true
end

local function trim_spaces_corrector(changes, text1, text2)
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

local function expand_equal_whitespace(text1, text2, range)
	local start1 = range.start1
	local start2 = range.start2
	local end1 = range.end1
	local end2 = range.end2
	while
		start1 < end1
		and start2 < end2
		and text1:byte(start1 + 1) == text2:byte(start2 + 1)
		and whitespace_at(text1, start1)
	do
		start1 = start1 + 1
		start2 = start2 + 1
	end
	while start1 < end1 and start2 < end2 and text1:byte(end1) == text2:byte(end2) and whitespace_at(text1, end1 - 1) do
		end1 = end1 - 1
		end2 = end2 - 1
	end
	return { start1 = start1, end1 = end1, start2 = start2, end2 = end2 }
end

local function ignore_spaces_corrector(changes, text1, text2)
	local result = {}
	for _, range in ipairs(changes) do
		local expanded = expand_equal_whitespace(text1, text2, range)
		local start1 = trim_start(text1, expanded.start1, expanded.end1)
		local end1 = trim_end(text1, start1, expanded.end1)
		local start2 = trim_start(text2, expanded.start2, expanded.end2)
		local end2 = trim_end(text2, start2, expanded.end2)
		if
			(start1 ~= end1 or start2 ~= end2)
			and policy.ignore_key(text1:sub(start1 + 1, end1)) ~= policy.ignore_key(text2:sub(start2 + 1, end2))
		then
			result[#result + 1] = { start1 = start1, end1 = end1, start2 = start2, end2 = end2 }
		end
	end
	return result
end

local function correct_whitespace(changes, text1, text2, comparison_policy)
	if comparison_policy == "default" then
		return default_corrector(changes, text1, text2)
	end
	if comparison_policy == "trim_whitespaces" then
		return trim_spaces_corrector(default_corrector(changes, text1, text2), text1, text2)
	end
	return ignore_spaces_corrector(changes, text1, text2)
end

---@param text1 string
---@param text2 string
---@param comparison_policy gleb.diff.Policy
---@param context gleb.diff.Context
---@return gleb.diff.InnerFragment[], gleb.diff.LcsStatus
function M.compare(text1, text2, comparison_policy, context)
	local words1, words2, unchanged, status = compare_words(text1, text2, context)
	if status ~= "ok" then
		return {}, status
	end
	local changes
	changes, status = match_adjustment_delimiters(text1, text2, words1, words2, unchanged, context)
	if status ~= "ok" then
		return {}, status
	end
	return correct_whitespace(changes, text1, text2, comparison_policy), "ok"
end

local function count_newlines(words, start_index, end_index)
	local count = 0
	for index = start_index, end_index - 1 do
		if words[index + 1].newline then
			count = count + 1
		end
	end
	return count
end

local function subwords(words, start_index, end_index, offset)
	local result = {}
	for index = start_index, end_index - 1 do
		local word = words[index + 1]
		result[#result + 1] = {
			start_offset = word.start_offset - offset,
			end_offset = word.end_offset - offset,
			newline = word.newline,
			key = word.key,
		}
	end
	return result
end

---@param text1 string
---@param text2 string
---@param line_count1 integer
---@param line_count2 integer
---@param comparison_policy gleb.diff.Policy
---@param context gleb.diff.Context
---@return gleb.diff.LineFragment[], gleb.diff.LcsStatus
function M.compare_and_split(text1, text2, line_count1, line_count2, comparison_policy, context)
	local words1, words2, unchanged, status = compare_words(text1, text2, context)
	if status ~= "ok" then
		return {}, status
	end
	local changed = ranges.changes_from_unchanged(unchanged, #words1, #words2)
	local word_blocks = split.blocks(text1, text2, words1, words2, unchanged)
	local result = {}
	local line1 = 0
	local line2 = 0
	local change_index = 1
	for block_index, block in ipairs(word_blocks) do
		local word_range = block.words
		local offsets = block.offsets
		while change_index <= #changed do
			local range = changed[change_index]
			if range.end1 < word_range.start1 or range.end2 < word_range.start2 then
				change_index = change_index + 1
			else
				break
			end
		end
		local local_changes = {}
		local index = change_index
		while index <= #changed do
			local range = changed[index]
			index = index + 1
			local before_block = range.end1 < word_range.start1 or range.end2 < word_range.start2
			if not before_block and (range.start1 > word_range.end1 or range.start2 > word_range.end2) then
				break
			elseif not before_block then
				local clipped = {
					start1 = math.max(word_range.start1, range.start1) - word_range.start1,
					end1 = math.min(word_range.end1, range.end1) - word_range.start1,
					start2 = math.max(word_range.start2, range.start2) - word_range.start2,
					end2 = math.min(word_range.end2, range.end2) - word_range.start2,
				}
				if clipped.start1 ~= clipped.end1 or clipped.start2 ~= clipped.end2 then
					local_changes[#local_changes + 1] = clipped
				end
			end
		end
		local text_start1 = offsets.start1
		local text_start2 = offsets.start2
		local subtext1 = text1:sub(text_start1 + 1, offsets.end1)
		local subtext2 = text2:sub(text_start2 + 1, offsets.end2)
		local local_words1 = subwords(words1, word_range.start1, word_range.end1, text_start1)
		local local_words2 = subwords(words2, word_range.start2, word_range.end2, text_start2)
		local local_unchanged = ranges.unchanged_from_changes(local_changes, #local_words1, #local_words2)
		local inner
		inner, status =
			match_adjustment_delimiters(subtext1, subtext2, local_words1, local_words2, local_unchanged, context)
		if status ~= "ok" then
			return {}, status
		end
		inner = correct_whitespace(inner, subtext1, subtext2, comparison_policy)
		local end1
		local end2
		if block_index == #word_blocks then
			end1 = line_count1
			end2 = line_count2
		else
			end1 = line1 + count_newlines(words1, word_range.start1, word_range.end1)
			end2 = line2 + count_newlines(words2, word_range.start2, word_range.end2)
		end
		result[#result + 1] = {
			start1 = line1,
			end1 = end1,
			start2 = line2,
			end2 = end2,
			inner = inner,
			offset1 = text_start1,
			offset2 = text_start2,
		}
		line1 = end1
		line2 = end2
	end
	return result, "ok"
end

return M
