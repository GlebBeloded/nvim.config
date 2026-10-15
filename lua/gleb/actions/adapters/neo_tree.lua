local Context = require("gleb.actions.context")

local AREAS = { "file_tree", "neo_tree" }

local M = {}

---@param id string
---@param action gleb.Action
---@param scope? "common"|"filesystem"|"git_status"
---@return boolean
local function belongs(id, action, scope)
	local area = id:match("^([^.]+)%.")
	return vim.tbl_contains(AREAS, area) and (scope == nil or action.neo_tree_scope == scope)
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param scope? "common"|"filesystem"|"git_status"
---@param build fun(action: gleb.Action): unknown
---@return table<string, unknown>
local function collect(catalog, shortcuts, scope, build)
	local mappings = {}
	for id, lhs_list in pairs(shortcuts) do
		local action = catalog:get(id)
		if action and belongs(id, action, scope) then
			for _, lhs in ipairs(lhs_list) do
				mappings[lhs] = build(action)
			end
		end
	end
	return mappings
end

--- neo-tree command whose description is also its help text.
---@param action gleb.Action
---@return table
local function command(action)
	return { Context.invoke(action), desc = action.category .. ": " .. action.title }
end

--- lhs → callback for tree actions, limited to one neo-tree source window when `scope` is given.
---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param scope? "common"|"filesystem"|"git_status"
---@return table<string, function>
function M.mappings(catalog, shortcuts, scope)
	return collect(catalog, shortcuts, scope, Context.invoke)
end

--- neo-tree `window.mappings` table of one source window.
---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param scope "common"|"filesystem"|"git_status"
---@return table<string, table>
function M.window_mappings(catalog, shortcuts, scope)
	return collect(catalog, shortcuts, scope, command)
end

return M
