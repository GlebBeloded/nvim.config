-- Changed-range construction for the diff engine.
-- Matching pairs stay internal so every public range is ordered and half-open.

local M = {}

---@class gleb.diff.LineFragment
---@field start1 integer
---@field end1 integer
---@field start2 integer
---@field end2 integer

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

return M
