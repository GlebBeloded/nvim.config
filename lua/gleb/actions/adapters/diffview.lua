local Context = require("gleb.actions.context")

local M = {}

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param scope string
---@return table[]
function M.mappings(catalog, shortcuts, scope)
	local mappings = {}
	for id, lhs_list in pairs(shortcuts) do
		local action = catalog:get(id)
		if action and action.plugin == "diffview" and vim.tbl_contains(action.diffview_scopes or {}, scope) then
			for _, lhs in ipairs(lhs_list) do
				table.insert(mappings, {
					action.modes or "n",
					lhs,
					Context.invoke(action),
					{ desc = action.category .. ": " .. action.title },
				})
			end
		end
	end
	return mappings
end

return M
