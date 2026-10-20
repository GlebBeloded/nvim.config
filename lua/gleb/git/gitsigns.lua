local status_ok, gitsigns = pcall(require, "gitsigns")
if not status_ok then
	return
end

local sign_text = require("gleb.git.sign_text")

gitsigns.setup({
	signs = {
		add = { text = sign_text.bar, hl = "GitSignsAdd", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
		untracked = { text = sign_text.bar, hl = "GitSignsAdd", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
		change = {
			text = sign_text.bar,
			hl = "GitSignsChange",
			numhl = "GitSignsChangeNr",
			linehl = "GitSignsChangeLn",
		},
		delete = {
			text = sign_text.delete,
			hl = "GitSignsDelete",
			numhl = "GitSignsDeleteNr",
			linehl = "GitSignsDeleteLn",
		},
		topdelete = {
			text = sign_text.delete,
			hl = "GitSignsDelete",
			numhl = "GitSignsDeleteNr",
			linehl = "GitSignsDeleteLn",
		},
		changedelete = {
			text = sign_text.bar,
			hl = "GitSignsChange",
			numhl = "GitSignsChangeNr",
			linehl = "GitSignsChangeLn",
		},
	},
	signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
	numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
	linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
	word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
	current_line_blame = false, -- The highlight group used for the text is `GitSignsCurrentLineBlame`.
	current_line_blame_opts = {
		virt_text = true,
		virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
		delay = 300,
	},
})
