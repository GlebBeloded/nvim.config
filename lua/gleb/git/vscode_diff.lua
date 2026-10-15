local status_ok, codediff = pcall(require, "codediff")
if not status_ok then
	return
end

local registry = require("gleb.actions")
local adapter = require("gleb.actions.adapters.codediff")
local store = assert(registry.state.store, "actions are not set up")
local catalog = assert(registry.state.applicator, "actions are not set up").catalog
local shortcuts = store:load()
local keymaps = {}
for scope, defaults in pairs(require("codediff.config").defaults.keymaps) do
	keymaps[scope] = {}
	for action in pairs(defaults) do
		keymaps[scope][action] = false
	end
end
keymaps = vim.tbl_deep_extend("force", keymaps, adapter.mappings(catalog, shortcuts).keymaps)

codediff.setup({
	-- Explorer: file tree panel on the left, 35 columns wide
	explorer = {
		position = "left",
		width = 35,
		view_mode = "tree",
	},
	keymaps = keymaps,
})
