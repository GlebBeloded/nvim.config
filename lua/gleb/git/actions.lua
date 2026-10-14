-- Git entry actions lazy-load their viewer commands when invoked.

---@type gleb.Action[]
local actions = {
	{
		id = "git.open_differ",
		title = "Open Differ",
		category = "Git",
		run = function()
			vim.cmd.Differ()
		end,
	},
}

return actions
