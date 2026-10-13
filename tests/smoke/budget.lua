-- Startup time budget of `make smoke-startup`, stretched on a loaded host (tests/helpers.lua load_factor).

local H = require("tests.helpers")

local M = {}

--- `base_ms` times the host load factor, rounded; exactly `base_ms` on an idle host.
---@param base_ms number
---@return integer
function M.startup_budget(base_ms)
	return math.floor(base_ms * H.load_factor() + 0.5)
end

return M
