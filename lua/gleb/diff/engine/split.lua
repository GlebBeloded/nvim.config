-- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/LineFragmentSplitter.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/word_diff.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- Splits a changed line block at matched newlines and first words in lines.

local policy = require("gleb.diff.engine.policy")

local M = {}

local function word_offset(words, text, index)
	if index == -1 then
		return 0
	end
	if index == #words then
		return #text
	end
	return words[index + 1].end_offset
end

local function has_words_inside(block, words1, words2)
	for index = block.words.start1, block.words.end1 - 1 do
		if not words1[index + 1].newline then
			return true
		end
	end
	for index = block.words.start2, block.words.end2 - 1 do
		if not words2[index + 1].newline then
			return true
		end
	end
	return false
end

local function create_chunk(text1, text2, words1, words2, start1, start2, end1, end2, has_equal_words)
	local offset_start1 = word_offset(words1, text1, start1)
	local offset_start2 = word_offset(words2, text2, start2)
	local offset_end1 = word_offset(words1, text1, end1)
	local offset_end2 = word_offset(words2, text2, end2)
	local block = {
		words = {
			start1 = math.max(0, start1 + 1),
			end1 = math.min(end1 + 1, #words1),
			start2 = math.max(0, start2 + 1),
			end2 = math.min(end2 + 1, #words2),
		},
		offsets = {
			start1 = offset_start1,
			end1 = offset_end1,
			start2 = offset_start2,
			end2 = offset_end2,
		},
	}
	return {
		block = block,
		has_equal_words = has_equal_words,
		has_words_inside = has_words_inside(block, words1, words2),
		is_equal_ignore_whitespace = policy.ignore_key(text1:sub(offset_start1 + 1, offset_end1))
			== policy.ignore_key(text2:sub(offset_start2 + 1, offset_end2)),
	}
end

local function should_merge(left, right)
	return (not left.has_equal_words and not right.has_equal_words)
		or (left.is_equal_ignore_whitespace and right.is_equal_ignore_whitespace)
		or not left.has_words_inside
		or not right.has_words_inside
end

local function merge_chunks(left, right)
	local block1 = left.block
	local block2 = right.block
	return {
		block = {
			words = {
				start1 = block1.words.start1,
				end1 = block2.words.end1,
				start2 = block1.words.start2,
				end2 = block2.words.end2,
			},
			offsets = {
				start1 = block1.offsets.start1,
				end1 = block2.offsets.end1,
				start2 = block1.offsets.start2,
				end2 = block2.offsets.end2,
			},
		},
		has_equal_words = left.has_equal_words or right.has_equal_words,
		has_words_inside = left.has_words_inside or right.has_words_inside,
		is_equal_ignore_whitespace = left.is_equal_ignore_whitespace and right.is_equal_ignore_whitespace,
	}
end

---@param text1 string
---@param text2 string
---@param words1 gleb.diff.Word[]
---@param words2 gleb.diff.Word[]
---@param unchanged gleb.diff.LineFragment[]
---@return table[]
function M.blocks(text1, text2, words1, words2, unchanged)
	local result = {}
	local last1 = -1
	local last2 = -1
	local pending

	local function add_line_chunk(end1, end2, has_equal_words)
		if last1 > end1 or last2 > end2 then
			return
		end
		local chunk = create_chunk(text1, text2, words1, words2, last1, last2, end1, end2, has_equal_words)
		local offsets = chunk.block.offsets
		if offsets.start1 == offsets.end1 and offsets.start2 == offsets.end2 then
			return
		end
		if pending then
			if should_merge(pending, chunk) then
				chunk = merge_chunks(pending, chunk)
			else
				result[#result + 1] = pending.block
			end
		end
		pending = chunk
		last1 = end1
		last2 = end2
	end

	local function is_first_in_line(words, index)
		return index == 0 or words[index].newline
	end

	local has_equal_words = false
	for _, range in ipairs(unchanged) do
		for offset = 0, range.end1 - range.start1 - 1 do
			local index1 = range.start1 + offset
			local index2 = range.start2 + offset
			if words1[index1 + 1].newline and words2[index2 + 1].newline then
				add_line_chunk(index1, index2, has_equal_words)
				has_equal_words = false
			else
				if is_first_in_line(words1, index1) and is_first_in_line(words2, index2) then
					add_line_chunk(index1 - 1, index2 - 1, has_equal_words)
					has_equal_words = false
				end
				has_equal_words = true
			end
		end
	end
	add_line_chunk(#words1, #words2, has_equal_words)
	if pending then
		result[#result + 1] = pending.block
	end
	return result
end

return M
