-- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/ByWordRt.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/word_diff.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- Word-level comparison used by the inner phase.

local M = {}

local function timed_out(context)
	return context.clock() > context.deadline
end

local function common_prefix(text1, text2)
	local limit = math.min(#text1, #text2)
	local index = 0
	while index < limit and text1:byte(index + 1) == text2:byte(index + 1) do
		index = index + 1
	end
	return index
end

local function common_suffix(text1, text2, prefix)
	local limit = math.min(#text1, #text2) - prefix
	local count = 0
	while count < limit and text1:byte(#text1 - count) == text2:byte(#text2 - count) do
		count = count + 1
	end
	return count
end

---@param text1 string
---@param text2 string
---@param _comparison_policy gleb.diff.Policy
---@param context gleb.diff.Context
---@return gleb.diff.InnerFragment[], gleb.diff.LcsStatus
function M.compare(text1, text2, _comparison_policy, context)
	if timed_out(context) then
		return {}, "timed_out"
	end
	if text1 == text2 then
		return {}, "ok"
	end
	local prefix = common_prefix(text1, text2)
	local suffix = common_suffix(text1, text2, prefix)
	return {
		{
			start1 = prefix,
			end1 = #text1 - suffix,
			start2 = prefix,
			end2 = #text2 - suffix,
		},
	},
		"ok"
end

local function split_lines(text)
	local lines = vim.split(text, "\n", { plain = true })
	return lines
end

---@param text1 string
---@param text2 string
---@param line_count1 integer
---@param line_count2 integer
---@param comparison_policy gleb.diff.Policy
---@param context gleb.diff.Context
---@return gleb.diff.LineFragment[], gleb.diff.LcsStatus
function M.compare_and_split(text1, text2, line_count1, line_count2, comparison_policy, context)
	if timed_out(context) then
		return {}, "timed_out"
	end
	local lines1 = split_lines(text1)
	local lines2 = split_lines(text2)
	if line_count1 ~= line_count2 then
		local inner, status = M.compare(text1, text2, comparison_policy, context)
		return { { start1 = 0, end1 = line_count1, start2 = 0, end2 = line_count2, inner = inner } }, status
	end
	local result = {}
	for index = 1, line_count1 do
		if timed_out(context) then
			return result, "timed_out"
		end
		if lines1[index] ~= lines2[index] then
			local inner, status = M.compare(lines1[index], lines2[index], comparison_policy, context)
			if status ~= "ok" then
				return result, status
			end
			result[#result + 1] = {
				start1 = index - 1,
				end1 = index,
				start2 = index - 1,
				end2 = index,
				inner = inner,
			}
		end
	end
	return result, "ok"
end

return M
