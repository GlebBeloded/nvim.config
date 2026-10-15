-- AI actions expose 99's normal prompts without loading the lazy plugin at startup.

local prompts = require("gleb.ai.entry_keymaps")

---@type gleb.Action[]
local actions = {
	{
		id = "ai.search",
		title = "AI Search",
		category = "AI",
		run = prompts.search_prompt,
	},
	{
		id = "ai.vibe",
		title = "AI Vibe",
		category = "AI",
		modes = { "n" },
		run = prompts.vibe_prompt,
		mapping = prompts.vibe_prompt,
	},
	{
		id = "ai.visual",
		title = "AI Edit Selection",
		category = "AI",
		modes = { "x" },
		run = prompts.visual_prompt,
		mapping = prompts.visual_prompt,
	},
	{
		id = "ai.submit_prompt",
		title = "Submit AI Prompt",
		category = "AI",
		modes = { "n", "i" },
		ft = { "99", "99prompt" },
		run = function()
			vim.cmd.write()
		end,
	},
}

return actions
