local status_ok, vscode_diff = pcall(require, "vscode-diff")
if not status_ok then
	return
end

vscode_diff.setup({
	-- Explorer disabled - we use neo-tree for file navigation
	explorer = {
		position = "left",
		width = 35,
		view_mode = "tree",
	},
	-- Use default keymaps for diff navigation
	-- ]c / [c - next/prev hunk
	-- ]f / [f - next/prev file
	-- q - close
})
