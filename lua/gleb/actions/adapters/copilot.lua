local adapter = require("gleb.actions.adapters").by_action({ "copilot" })

local M = {}

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@return table
function M.mappings(catalog, shortcuts)
	return { suggestion = { keymap = adapter.mappings(catalog, shortcuts) } }
end

return M
