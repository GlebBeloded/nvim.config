-- Mason window actions; lua/gleb/lsp/config/init.lua hands their keys to mason's `ui.keymaps`.

local replay = require("gleb.actions.adapters").replay

---@type gleb.Action[]
local actions = {
	{
		id = "mason.install_package",
		title = "Install package",
		category = "Mason",
		plugin = "mason",
		run = replay("mason.install_package"),
	},
}

return actions
