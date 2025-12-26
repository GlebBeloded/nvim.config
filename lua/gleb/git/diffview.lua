local status_ok, diffview = pcall(require, "diffview")
if not status_ok then
	return
end

local actions = require("diffview.actions")

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
		view = {
			["<tab>"] = actions.select_next_entry,
			["<s-tab>"] = actions.select_prev_entry,
			["gf"] = actions.goto_file_edit,
			["<leader>co"] = actions.conflict_choose("ours"),
			["<leader>ct"] = actions.conflict_choose("theirs"),
			["<leader>cb"] = actions.conflict_choose("base"),
			["<leader>ca"] = actions.conflict_choose("all"),
			["dx"] = actions.conflict_choose("none"),
		},
		file_panel = {
			["j"] = actions.select_next_entry,
			["k"] = actions.select_prev_entry,
			["<cr>"] = actions.select_entry,
			["o"] = actions.select_entry,
			["l"] = actions.select_entry,
			["h"] = actions.close_fold,
			["<tab>"] = actions.select_next_entry,
			["<s-tab>"] = actions.select_prev_entry,
			["s"] = actions.toggle_stage_entry,
			["S"] = actions.stage_all,
			["U"] = actions.unstage_all,
			["R"] = actions.refresh_files,
			["q"] = "<cmd>DiffviewClose<cr>",
		},
	},
})
