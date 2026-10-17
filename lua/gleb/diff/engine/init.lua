-- Public line-comparison entry point for the IntelliJ-style diff engine.
-- Lines are interned before the integer LCS and exposed as half-open ranges.

local by_line = require("gleb.diff.engine.by_line")
local policy = require("gleb.diff.engine.policy")

local M = {}

local DELTA_THRESHOLD_SIZE = 20000

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
	local fragments, status = by_line.compare(lines1, lines2, comparison_policy, threshold)
	if comparison_policy == "ignore_whitespaces_chunks" then
		fragments = policy.trim_ignored_chunks(fragments, lines1, lines2)
	end
	return {
		fragments = fragments,
		too_big = status == "too_big",
		timed_out = false,
	}
end

return M
