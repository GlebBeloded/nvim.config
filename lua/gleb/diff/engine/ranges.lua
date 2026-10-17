-- Lua port of intellij-community Range.kt, DiffIterableUtil.kt, and ExpandChangeBuilder.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/smart_align.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- Changed-range construction for the diff engine.
-- Matching pairs stay internal so every public range is ordered and half-open.

local M = {}

---@class gleb.diff.LineFragment
---@field start1 integer
---@field end1 integer
---@field start2 integer
---@field end2 integer
---@field inner? gleb.diff.InnerFragment[]

---@class gleb.diff.Match
---@field [1] integer Index on side 1, 0-based.
---@field [2] integer Index on side 2, 0-based.

---@param matches gleb.diff.Match[]
---@param length1 integer
---@param length2 integer
---@return gleb.diff.LineFragment[]
function M.from_matches(matches, length1, length2)
	table.sort(matches, function(left, right)
		if left[1] == right[1] then
			return left[2] < right[2]
		end
		return left[1] < right[1]
	end)

	local fragments = {}
	local start1 = 0
	local start2 = 0
	for _, match in ipairs(matches) do
		if start1 < match[1] or start2 < match[2] then
			table.insert(fragments, {
				start1 = start1,
				end1 = match[1],
				start2 = start2,
				end2 = match[2],
			})
		end
		start1 = match[1] + 1
		start2 = match[2] + 1
	end

	if start1 < length1 or start2 < length2 then
		table.insert(fragments, {
			start1 = start1,
			end1 = length1,
			start2 = start2,
			end2 = length2,
		})
	end
	return fragments
end

---@param changes gleb.diff.LineFragment[]
---@param length1 integer
---@param length2 integer
---@return gleb.diff.LineFragment[]
function M.unchanged_from_changes(changes, length1, length2)
	local unchanged = {}
	local last1 = 0
	local last2 = 0
	for _, change in ipairs(changes) do
		if change.start1 > last1 or change.start2 > last2 then
			unchanged[#unchanged + 1] = {
				start1 = last1,
				end1 = change.start1,
				start2 = last2,
				end2 = change.start2,
			}
		end
		last1 = change.end1
		last2 = change.end2
	end
	if last1 < length1 or last2 < length2 then
		unchanged[#unchanged + 1] = { start1 = last1, end1 = length1, start2 = last2, end2 = length2 }
	end
	return unchanged
end

---@param unchanged gleb.diff.LineFragment[]
---@param length1 integer
---@param length2 integer
---@return gleb.diff.LineFragment[]
function M.changes_from_unchanged(unchanged, length1, length2)
	local changes = {}
	local last1 = 0
	local last2 = 0
	for _, range in ipairs(unchanged) do
		if range.start1 > last1 or range.start2 > last2 then
			changes[#changes + 1] = {
				start1 = last1,
				end1 = range.start1,
				start2 = last2,
				end2 = range.start2,
			}
		end
		last1 = range.end1
		last2 = range.end2
	end
	if last1 < length1 or last2 < length2 then
		changes[#changes + 1] = { start1 = last1, end1 = length1, start2 = last2, end2 = length2 }
	end
	return changes
end

return M
