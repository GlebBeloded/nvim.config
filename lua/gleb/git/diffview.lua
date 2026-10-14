local status_ok, diffview = pcall(require, "diffview")
if not status_ok then
	return
end

local registry = require("gleb.actions")
local adapter = require("gleb.actions.adapters.diffview")
local store = assert(registry.state.store, "actions are not set up")
local catalog = assert(registry.state.applicator, "actions are not set up").catalog
local shortcuts = store:load()

diffview.setup({
	enhanced_diff_hl = true,
	view = {
		default = {
			layout = "diff2_horizontal",
		},
		merge_tool = {
			layout = "diff3_mixed",
		},
	},
	file_panel = {
		listing_style = "tree",
		tree_options = {
			flatten_dirs = true,
			folder_statuses = "only_folded",
		},
		win_config = {
			position = "left",
			width = 35,
		},
	},
	keymaps = {
		disable_defaults = true,
		view = adapter.mappings(catalog, shortcuts, "view"),
		file_panel = adapter.mappings(catalog, shortcuts, "file_panel"),
	},
})
