-- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/TrimUtil.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/smart_align.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- Range trimming primitives shared by line matching and chunk optimization.
-- Equality is supplied by the caller so each whitespace policy uses the same mechanics.

local unicode = require("gleb.diff.engine.unicode")

local M = {}

---@param codepoint integer
---@return boolean
function M.is_punctuation(codepoint)
	if codepoint == 95 then
		return false
	end
	return (codepoint >= 33 and codepoint <= 47)
		or (codepoint >= 58 and codepoint <= 64)
		or (codepoint >= 91 and codepoint <= 96)
		or (codepoint >= 123 and codepoint <= 126)
end

---@param codepoint integer
---@return boolean
function M.is_alpha(codepoint)
	local is_whitespace = codepoint < 128 and (codepoint == 9 or codepoint == 10 or codepoint == 32)
	return not is_whitespace and not M.is_punctuation(codepoint)
end

---@param codepoint integer
---@return boolean
function M.is_continuous_script(codepoint)
	if codepoint < 128 or unicode.is_decimal_digit(codepoint) then
		return false
	end
	if codepoint > 0xffff or unicode.is_ideographic(codepoint) or not unicode.is_alphabetic(codepoint) then
		return true
	end
	return unicode.is_hiragana(codepoint)
		or unicode.is_katakana(codepoint)
		or unicode.is_thai(codepoint)
		or unicode.is_javanese(codepoint)
end

---@param start1 integer
---@param start2 integer
---@param end1 integer
---@param end2 integer
---@param equals fun(index1: integer, index2: integer): boolean
---@return integer
function M.expand_forward(start1, start2, end1, end2, equals)
	local count = 0
	while start1 + count < end1 and start2 + count < end2 and equals(start1 + count, start2 + count) do
		count = count + 1
	end
	return count
end

---@param start1 integer
---@param start2 integer
---@param end1 integer
---@param end2 integer
---@param equals fun(index1: integer, index2: integer): boolean
---@return integer
function M.expand_backward(start1, start2, end1, end2, equals)
	local count = 0
	while end1 - count > start1 and end2 - count > start2 and equals(end1 - count - 1, end2 - count - 1) do
		count = count + 1
	end
	return count
end

---@param start1 integer
---@param start2 integer
---@param end1 integer
---@param end2 integer
---@param equals fun(index1: integer, index2: integer): boolean
---@return gleb.diff.LineFragment
function M.expand(start1, start2, end1, end2, equals)
	local forward = M.expand_forward(start1, start2, end1, end2, equals)
	start1 = start1 + forward
	start2 = start2 + forward
	local backward = M.expand_backward(start1, start2, end1, end2, equals)
	return { start1 = start1, end1 = end1 - backward, start2 = start2, end2 = end2 - backward }
end

return M
