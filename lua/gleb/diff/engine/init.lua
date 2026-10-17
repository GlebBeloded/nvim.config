-- Lua port of intellij-community ComparisonManagerImpl.kt compareLines
-- (Apache-2.0, © JetBrains s.r.o.).
-- Modified: rewritten in Lua; see NOTICE.
-- Public line-comparison entry point for the IntelliJ-style diff engine.
-- Lines are interned before the integer LCS and exposed as half-open ranges.

local by_line = require("gleb.diff.engine.by_line")
local policy = require("gleb.diff.engine.policy")

local M = {}

local DELTA_THRESHOLD_SIZE = 20000
local TIMEOUT_MS = 1000

---@alias gleb.diff.Policy "default"|"trim_whitespaces"|"ignore_whitespaces"|"ignore_whitespaces_chunks"

---@class gleb.diff.Limits
---@field timeout_ms? integer
---@field clock? fun(): number
---@field myers_threshold? integer

---@class gleb.diff.Options
---@field policy? gleb.diff.Policy
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

---@param lines1 string[]
---@param lines2 string[]
---@param opts? gleb.diff.Options
---@return gleb.diff.Result
function M.compare_lines(lines1, lines2, opts)
	opts = opts or {}
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
	if status == "ok" and comparison_policy == "ignore_whitespaces_chunks" then
		fragments = policy.trim_ignored_chunks(fragments, lines1, lines2)
	end
	return {
		fragments = fragments,
		too_big = status == "too_big",
		timed_out = status == "timed_out",
	}
end

return M
