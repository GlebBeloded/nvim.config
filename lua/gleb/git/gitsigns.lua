local status_ok, gitsigns = pcall(require, "gitsigns")
if not status_ok then
	return
end

--- On macOS libuv backs a directory `fs_event` with FSEvents, whose every close waits for fseventsd to
--- re-register the remaining paths, so a busy fseventsd holds `:quit` past Neovim's loop-close bound.
--- gitsigns' own `fs_poll` backend (its fallback) watches the same git metadata files without FSEvents.
local function poll_git_dir_on_macos()
	local ok, Watcher = pcall(require, "gitsigns.git.repo.watcher")
	if vim.uv.os_uname().sysname ~= "Darwin" or not ok or type(Watcher._sync_watches) ~= "function" then
		return
	end
	local sync_watches = Watcher._sync_watches
	---@diagnostic disable-next-line: invisible
	function Watcher:_sync_watches()
		---@diagnostic disable-next-line: invisible
		self._backend = "fs_poll"
		return sync_watches(self)
	end
end

poll_git_dir_on_macos()

gitsigns.setup({
	signs = {
		add = { text = "┃", hl = "GitSignsAdd", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
		untracked = { text = "┃", hl = "GitSignsAdd", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
		change = { text = "┃", hl = "GitSignsChange", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
		delete = { text = "", hl = "GitSignsDelete", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
		topdelete = { text = "", hl = "GitSignsDelete", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
		changedelete = { text = "┃", hl = "GitSignsChange", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
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
