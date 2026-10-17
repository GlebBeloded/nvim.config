-- Lua port of intellij-community ComparisonManagerImpl.kt compareLines
-- (Apache-2.0, © JetBrains s.r.o.).
-- Modified: rewritten in Lua; see NOTICE.
-- Public line-comparison entry point for the IntelliJ-style diff engine.
-- Lines are interned before the integer LCS and exposed as half-open ranges.

local by_line = require("gleb.diff.engine.by_line")
local by_char = require("gleb.diff.engine.by_char")
local by_word = require("gleb.diff.engine.by_word")
local policy = require("gleb.diff.engine.policy")

local M = {}

local DELTA_THRESHOLD_SIZE = 20000
local MAX_BAD_LINES = 3
local MAX_INNER_BYTES = 50000
local TIMEOUT_MS = 1000

---@alias gleb.diff.Policy "default"|"trim_whitespaces"|"ignore_whitespaces"|"ignore_whitespaces_chunks"

---@class gleb.diff.Limits
---@field timeout_ms? integer
---@field clock? fun(): number
---@field myers_threshold? integer
---@field max_inner_bytes? integer

---@alias gleb.diff.Highlight "by_word"|"by_word_split"|"by_char"|"by_line"|"none"

---@class gleb.diff.InnerFragment
---@field start1 integer
---@field end1 integer
---@field start2 integer
---@field end2 integer

---@class gleb.diff.Options
---@field policy? gleb.diff.Policy
---@field highlight? gleb.diff.Highlight
---@field limits? gleb.diff.Limits

---@class gleb.diff.Result
---@field fragments gleb.diff.LineFragment[]
---@field too_big boolean
---@field timed_out boolean

---@class gleb.diff.Context
---@field clock fun(): number
---@field deadline number
---@field myers_threshold integer

local function default_clock()
	return vim.uv.hrtime() / 1e6
end

local function fallback(lines1, lines2)
	local text1 = table.concat(lines1, "\n") .. "\n"
	local text2 = table.concat(lines2, "\n") .. "\n"
	local fragments = {}
	local indices_result = vim.text.diff(text1, text2, { result_type = "indices", algorithm = "histogram" })
	---@cast indices_result integer[][]
	for _, indices in ipairs(indices_result) do
		local line1, count1, line2, count2 = unpack(indices)
		local start1 = count1 > 0 and line1 - 1 or line1
		local start2 = count2 > 0 and line2 - 1 or line2
		fragments[#fragments + 1] = {
			start1 = start1,
			end1 = start1 + count1,
			start2 = start2,
			end2 = start2 + count2,
		}
	end
	return fragments
end

local function fragment_text(lines, start_index, end_index)
	return table.concat(lines, "\n", start_index + 1, end_index)
end

-- IntelliJ compares a fragment with the newline that ends its last line (getLineEnd(line, true)).
local function terminated_text(lines, start_index, end_index)
	local text = fragment_text(lines, start_index, end_index)
	if start_index < end_index and end_index < #lines then
		return text .. "\n"
	end
	return text
end

local function equal_under_policy(text1, text2, comparison_policy)
	return policy.key(text1, comparison_policy) == policy.key(text2, comparison_policy)
end

local function add_line_offset(block, fragment)
	block.start1 = block.start1 + fragment.start1
	block.end1 = block.end1 + fragment.start1
	block.start2 = block.start2 + fragment.start2
	block.end2 = block.end2 + fragment.start2
	block.offset1 = nil
	block.offset2 = nil
	return block
end

local function create_inner(fragments, lines1, lines2, highlight, comparison_policy, context, max_inner_bytes)
	local result = {}
	local failures = 0
	local timed_out = false
	for _, fragment in ipairs(fragments) do
		local text1 = terminated_text(lines1, fragment.start1, fragment.end1)
		local text2 = terminated_text(lines2, fragment.start2, fragment.end2)
		local deadline_passed = context.clock() > context.deadline
		if failures >= MAX_BAD_LINES or deadline_passed then
			timed_out = timed_out or deadline_passed
			result[#result + 1] = fragment
		elseif highlight == "by_line" then
			if
				(fragment.start1 == fragment.end1 or fragment.start2 == fragment.end2)
				and equal_under_policy(text1, text2, comparison_policy)
			then
				fragment.inner = {}
			end
			result[#result + 1] = fragment
		elseif #text1 > max_inner_bytes or #text2 > max_inner_bytes then
			failures = failures + 1
			result[#result + 1] = fragment
		elseif fragment.start1 == fragment.end1 or fragment.start2 == fragment.end2 then
			if equal_under_policy(text1, text2, comparison_policy) then
				fragment.inner = {}
			end
			result[#result + 1] = fragment
		elseif highlight == "by_word" or highlight == "by_word_split" then
			local blocks, status = by_word.compare_and_split(
				text1,
				text2,
				fragment.end1 - fragment.start1,
				fragment.end2 - fragment.start2,
				comparison_policy,
				context
			)
			if status ~= "ok" then
				failures = failures + 1
				timed_out = timed_out or status == "timed_out"
				result[#result + 1] = fragment
			else
				for _, block in ipairs(blocks) do
					result[#result + 1] = add_line_offset(block, fragment)
				end
			end
		elseif highlight == "by_char" then
			local inner, status = by_char.compare_policy(text1, text2, comparison_policy, context)
			if status == "ok" then
				fragment.inner = inner
			else
				failures = failures + 1
				timed_out = timed_out or status == "timed_out"
			end
			result[#result + 1] = fragment
		else
			result[#result + 1] = fragment
		end
	end
	return result, timed_out
end

local function context_from_options(opts)
	local limits = opts.limits or {}
	local clock = limits.clock or default_clock
	return {
		clock = clock,
		deadline = clock() + (limits.timeout_ms or TIMEOUT_MS),
		myers_threshold = limits.myers_threshold or DELTA_THRESHOLD_SIZE,
	}
end

---@param text1 string
---@param text2 string
---@param opts? gleb.diff.Options
---@return gleb.diff.InnerFragment[]
function M.compare_words(text1, text2, opts)
	opts = opts or {}
	local fragments = by_word.compare(text1, text2, opts.policy or "default", context_from_options(opts))
	return fragments
end

---@param text1 string
---@param text2 string
---@param opts? gleb.diff.Options
---@return gleb.diff.InnerFragment[]
function M.compare_chars(text1, text2, opts)
	opts = opts or {}
	local fragments = by_char.compare_policy(text1, text2, opts.policy or "default", context_from_options(opts))
	return fragments
end

---@param lines1 string[]
---@param lines2 string[]
---@param opts? gleb.diff.Options
---@return gleb.diff.Result
function M.compare_lines(lines1, lines2, opts)
	opts = opts or {}
	local highlight = opts.highlight or "by_word"
	if highlight == "none" then
		return { fragments = {}, too_big = false, timed_out = false }
	end
	local limits = opts.limits or {}
	local comparison_policy = opts.policy or "default"
	local threshold = limits.myers_threshold
		or math.min(#lines1 + #lines2, DELTA_THRESHOLD_SIZE + 10 * math.floor(math.sqrt(#lines1 + #lines2)))
	local clock = limits.clock or default_clock
	local context = {
		clock = clock,
		deadline = clock() + (limits.timeout_ms or TIMEOUT_MS),
		myers_threshold = threshold,
	}
	local fragments, status = by_line.compare(lines1, lines2, comparison_policy, context)
	if status ~= "ok" then
		fragments = fallback(lines1, lines2)
	end
	local inner_timed_out = false
	if status == "ok" then
		fragments, inner_timed_out = create_inner(
			fragments,
			lines1,
			lines2,
			highlight,
			comparison_policy,
			context,
			limits.max_inner_bytes or MAX_INNER_BYTES
		)
		if highlight ~= "by_word_split" then
			fragments = policy.squash(fragments, lines1, lines2)
		end
	end
	if status == "ok" and comparison_policy == "ignore_whitespaces_chunks" then
		fragments = policy.trim_ignored_chunks(fragments, lines1, lines2)
	end
	return {
		fragments = fragments,
		too_big = status == "too_big",
		timed_out = status == "timed_out" or inner_timed_out,
	}
end

---@class gleb.diff.Column
---@field row integer
---@field col_start integer
---@field col_end integer

local function append_columns(columns, start_offset, end_offset, first_row, selected_lines)
	local offset = 0
	for line_index, line in ipairs(selected_lines) do
		local line_start = offset
		local line_end = offset + #line
		local col_start = math.max(start_offset, line_start) - line_start
		local col_end = math.min(end_offset, line_end) - line_start
		if
			col_start < col_end
			or (start_offset == end_offset and start_offset >= line_start and start_offset <= line_end)
		then
			columns[#columns + 1] = { row = first_row + line_index - 1, col_start = col_start, col_end = col_end }
		end
		offset = line_end + 1
	end
end

---@param fragment gleb.diff.LineFragment
---@param side 1|2
---@param lines string[]
---@return gleb.diff.Column[]?
function M.inner_columns(fragment, side, lines)
	if fragment.inner == nil then
		return nil
	end
	local first_row = fragment["start" .. side]
	local last_row = fragment["end" .. side]
	local selected_lines = {}
	for row = first_row + 1, last_row do
		selected_lines[#selected_lines + 1] = lines[row]
	end
	local columns = {}
	for _, inner in ipairs(fragment.inner) do
		append_columns(columns, inner["start" .. side], inner["end" .. side], first_row, selected_lines)
	end
	return columns
end

return M
