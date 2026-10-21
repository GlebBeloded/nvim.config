-- Find Action registers its own palette entry so it is discoverable alongside other actions.

local function open()
	require("gleb.find_action").open()
end

---@type gleb.Action[]
local actions = {
	{
		id = "find_action.open",
		title = "Find Action...",
		category = "Help",
		modes = { "n", "x" },
		run = open,
		mapping = open,
	},
}

return actions
