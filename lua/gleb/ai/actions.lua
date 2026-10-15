-- AI actions expose 99's normal prompts without loading the lazy plugin at startup.

local prompts = require("gleb.ai.entry_keymaps")

---@type gleb.Action[]
local actions = {
	{
		id = "ai.search",
		title = "99 Search",
		category = "AI",
		run = prompts.search_prompt,
	},
	{
		id = "ai.vibe",
		title = "99 Vibe",
		category = "99",
		modes = { "n" },
		run = prompts.vibe_prompt,
		mapping = prompts.vibe_prompt,
	},
	{
		id = "ai.visual",
		title = "Visual",
		category = "99",
		modes = { "x" },
		run = prompts.visual_prompt,
		mapping = prompts.visual_prompt,
	},
	{
		id = "ai.submit_prompt",
		title = "Submit prompt",
		category = "99",
		modes = { "n", "i" },
		ft = { "99", "99prompt" },
		run = function()
			vim.cmd.write()
		end,
	},
}

return actions
