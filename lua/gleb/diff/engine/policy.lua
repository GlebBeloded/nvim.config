-- Lua port of intellij-community ComparisonUtil.kt and IgnorePolicy.java
-- (Apache-2.0, © JetBrains s.r.o.).
-- Modified: rewritten in Lua; see NOTICE.
-- Whitespace policy normalization for IntelliJ-style line comparison.
-- Only space, tab, and newline are whitespace; carriage returns remain text.

local M = {}

local function is_whitespace_byte(byte)
	return byte == 0x20 or byte == 0x09 or byte == 0x0a
end

local function without_whitespace(text)
	return (text:gsub("[ \t\n]", ""))
end

local function trim_whitespace(text)
	return (text:gsub("^[ \t\n]+", ""):gsub("[ \t\n]+$", ""))
end

---@param text string
---@param policy gleb.diff.Policy
---@return string
function M.key(text, policy)
	if policy == "trim_whitespaces" then
		return trim_whitespace(text)
	end
	if policy == "ignore_whitespaces" or policy == "ignore_whitespaces_chunks" then
		return without_whitespace(text)
	end
	return text
end

---@param text string
---@return string
function M.ignore_key(text)
	return without_whitespace(text)
end

---@param text string
---@return integer
function M.count_nonspace_codepoints(text)
	local count = 0
	for index = 1, #text do
		local byte = text:byte(index)
		if not is_whitespace_byte(byte) and (byte < 0x80 or byte >= 0xc0) then
			count = count + 1
		end
	end
	return count
end

local function fragment_text(lines, start_index, end_index)
	local selected = {}
	for index = start_index + 1, end_index do
		selected[#selected + 1] = lines[index]
	end
	return table.concat(selected, "\n")
end

---@param fragments gleb.diff.LineFragment[]
---@param lines1 string[]
---@param lines2 string[]
---@return gleb.diff.LineFragment[]
function M.trim_ignored_chunks(fragments, lines1, lines2)
	local result = {}
	for _, fragment in ipairs(fragments) do
		local text1 = fragment_text(lines1, fragment.start1, fragment.end1)
		local text2 = fragment_text(lines2, fragment.start2, fragment.end2)
		if without_whitespace(text1) ~= without_whitespace(text2) then
			result[#result + 1] = fragment
		end
	end
	return result
end

return M
