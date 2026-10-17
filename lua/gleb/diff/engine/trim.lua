-- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/TrimUtil.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/smart_align.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- Range trimming primitives shared by line matching and chunk optimization.
-- Equality is supplied by the caller so each whitespace policy uses the same mechanics.

local M = {}

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
