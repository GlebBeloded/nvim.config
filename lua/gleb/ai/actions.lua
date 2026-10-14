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
		category = "AI",
		run = prompts.vibe_prompt,
	},
}

return actions
