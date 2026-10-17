-- Public line-comparison entry point for the IntelliJ-style diff engine.
-- Lines are interned before the integer LCS and exposed as half-open ranges.

local lcs = require("gleb.diff.engine.lcs")
local ranges = require("gleb.diff.engine.ranges")

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

local function intern(lines1, lines2)
	local ids = {}
	local next_id = 0
	local function convert(lines)
		local converted = {}
		for index, line in ipairs(lines) do
			local id = ids[line]
			if id == nil then
				id = next_id
				next_id = next_id + 1
				ids[line] = id
			end
			converted[index] = id
		end
		return converted
	end
	return convert(lines1), convert(lines2)
end

---@param lines1 string[]
---@param lines2 string[]
---@param opts? gleb.diff.Options
---@return gleb.diff.Result
function M.compare_lines(lines1, lines2, opts)
	opts = opts or {}
	local limits = opts.limits or {}
	local ids1, ids2 = intern(lines1, lines2)
	local threshold = limits.myers_threshold
		or math.min(#ids1 + #ids2, DELTA_THRESHOLD_SIZE + 10 * math.floor(math.sqrt(#ids1 + #ids2)))
	local result = lcs.diff(ids1, ids2, threshold)
	return {
		fragments = ranges.from_matches(result.matches, #lines1, #lines2),
		too_big = result.status == "too_big",
		timed_out = false,
	}
end

return M
