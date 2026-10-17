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

local function side_text_length(fragment, side, lines)
	local start_index = fragment["start" .. side]
	local end_index = fragment["end" .. side]
	if start_index == end_index then
		return 0
	end
	return #table.concat(lines, "\n", start_index + 1, end_index)
end

local function append_inner(target, source, shift1, shift2)
	if target.inner == nil or source.inner == nil then
		target.inner = nil
		return
	end
	for _, inner in ipairs(source.inner) do
		local shifted = {
			start1 = inner.start1 + shift1,
			end1 = inner.end1 + shift1,
			start2 = inner.start2 + shift2,
			end2 = inner.end2 + shift2,
		}
		local previous = target.inner[#target.inner]
		if previous and previous.end1 == shifted.start1 and previous.end2 == shifted.start2 then
			previous.end1 = shifted.end1
			previous.end2 = shifted.end2
		else
			target.inner[#target.inner + 1] = shifted
		end
	end
end

---@param fragments gleb.diff.LineFragment[]
---@param lines1 string[]
---@param lines2 string[]
---@return gleb.diff.LineFragment[]
function M.squash(fragments, lines1, lines2)
	local result = {}
	for _, fragment in ipairs(fragments) do
		local previous = result[#result]
		if previous and previous.end1 == fragment.start1 and previous.end2 == fragment.start2 then
			local shift1 = side_text_length(previous, 1, lines1)
			local shift2 = side_text_length(previous, 2, lines2)
			if previous.start1 ~= previous.end1 and previous.end1 < #lines1 then
				shift1 = shift1 + 1
			end
			if previous.start2 ~= previous.end2 and previous.end2 < #lines2 then
				shift2 = shift2 + 1
			end
			append_inner(previous, fragment, shift1, shift2)
			previous.end1 = fragment.end1
			previous.end2 = fragment.end2
		else
			local copy = vim.deepcopy(fragment)
			result[#result + 1] = copy
		end
	end
	return result
end

return M
