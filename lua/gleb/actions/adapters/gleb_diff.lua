-- Diff-view mappings are rebuilt from the current shortcut assignments whenever a view opens.

local Context = require("gleb.actions.context")
local Registry = require("gleb.actions.registry")

local M = {}

---@class gleb.diff.Mapping
---@field action gleb.Action
---@field callback function
---@field desc string

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@return table<string, gleb.diff.Mapping>
function M.mappings(catalog, shortcuts)
	local mappings = {}
	for id, lhs_list in pairs(shortcuts) do
		local action = catalog:get(id)
		if action and action.plugin == "gleb-diff" then
			for _, lhs in ipairs(lhs_list) do
				mappings[lhs] = {
					action = action,
					callback = Context.invoke(action),
					desc = Registry.description(action),
				}
			end
		end
	end
	return mappings
end

return M
