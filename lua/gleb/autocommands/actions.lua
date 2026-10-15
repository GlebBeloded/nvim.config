-- Special-buffer behavior is filetype-scoped by the action registry.

---@type gleb.Action[]
local actions = {
	{
		id = "window.close_special",
		title = "Close Window",
		category = "Window",
		ft = { "qf", "help", "man", "lspinfo" },
		run = function()
			vim.cmd.close()
		end,
	},
}

return actions
