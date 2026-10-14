-- Features own action lists; this module is their catalog entry point.

local Registry = require("gleb.actions.registry")

local M = {}

---@param feature_actions gleb.Action[][]
---@return gleb.ActionCatalog
function M.catalog(feature_actions)
	return Registry.new(feature_actions)
end

return M
