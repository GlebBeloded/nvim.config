local adapter = require("gleb.actions.adapters").by_action({ "codediff" })

local M = {}

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@return table
function M.mappings(catalog, shortcuts)
	return { keymaps = { view = adapter.mappings(catalog, shortcuts) } }
end

return M
