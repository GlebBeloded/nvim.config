-- Copilot statusline indicator that stays HIDDEN while Copilot is healthy and
-- only shows a (red, via lualine `color`) glyph when Copilot is NOT working:
-- disabled/offline, failed to start, no client, or reporting a warning.
local M = {}

local GLYPH = ""

-- Don't touch Copilot until it has actually loaded (it lazy-loads on InsertEnter);
-- requiring its modules early would force an eager load on every redraw.
local function loaded()
	return package.loaded["copilot.client"] ~= nil
end

local function not_working()
	if not loaded() then
		return false
	end

	local client = require("copilot.client")
	if client.is_disabled() or client.startup_error or not client.get() then
		return true
	end

	local ok, status = pcall(require, "copilot.status")
	return ok and status.data and status.data.status == "Warning"
end

function M.component()
	return not_working() and GLYPH or ""
end

return M
