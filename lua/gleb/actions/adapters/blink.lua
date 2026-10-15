-- blink.cmp adapter: each assigned key gets its action's blink command list (insert or command-line keymap).

local Context = require("gleb.actions.context")

local M = {}

--- Actions without a native command list run through the registry and stop the key there.
---@param action gleb.Action
---@return table
local function commands(action)
	if action.commands then
		return action.commands
	end
	return {
		function()
			return action.run(Context.capture())
		end,
	}
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param mode? "i"|"c" keymap to build; blink actions default to insert mode
---@return table<string, table>
function M.mappings(catalog, shortcuts, mode)
	mode = mode or "i"
	local keymap = {}
	for id, lhs_list in pairs(shortcuts) do
		local action = vim.startswith(id, "blink.") and catalog:get(id) or nil
		if action and vim.tbl_contains(action.modes or { "i" }, mode) then
			for _, lhs in ipairs(lhs_list) do
				keymap[lhs] = commands(action)
			end
		end
	end
	return keymap
end

return M
