local Context = require("gleb.actions.context")

local M = {}

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param scope "common"|"filesystem"|"git_status"
---@return table<string, table>
function M.mappings(catalog, shortcuts, scope)
	local mappings = {}
	for id, lhs_list in pairs(shortcuts) do
		local action = catalog:get(id)
		if action and action.plugin == "neo-tree" and action.neo_tree_scope == scope then
			for _, lhs in ipairs(lhs_list) do
				mappings[lhs] = {
					Context.invoke(action),
					desc = action.category .. ": " .. action.title,
				}
			end
		end
	end
	return mappings
end

return M
