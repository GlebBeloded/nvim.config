-- Find Action registers its own palette entry so it is discoverable alongside other actions.

---@type gleb.Action[]
local actions = {
	{
		id = "find_action.open",
		title = "Find Action...",
		category = "Help",
		modes = { "n", "x" },
		run = function(ctx)
			require("gleb.find_action").open(ctx)
		end,
	},
}

return actions
