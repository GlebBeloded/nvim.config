local status_ok, differ = pcall(require, "differ")
if not status_ok then
	return
end

local registry = require("gleb.actions")
local adapter = require("gleb.actions.adapters.differ")
local store = assert(registry.state.store, "actions are not set up")
local catalog = assert(registry.state.applicator, "actions are not set up").catalog
local shortcuts = store:load()
local keymaps = {}
for action in pairs(require("differ.config").defaults.keymaps) do
	keymaps[action] = false
end
keymaps = vim.tbl_extend("force", keymaps, adapter.mappings(catalog, shortcuts))

-- Mirrors the old diffview.lua preferences: side-by-side view, tree listing,
-- 35-wide panel on the left (same width as neo-tree).
differ.setup({
	layout = "split", -- "stacked" | "split"; toggle at runtime with `dl`
	context = 3, -- fold unchanged runs longer than this; `math.huge` = whole file
	panel = {
		position = "left",
		width = 35,
		listing = "tree",
	},
	deep_diff = {
		enabled = true,
		granularity = "word",
	},
	keymaps = keymaps,
})
