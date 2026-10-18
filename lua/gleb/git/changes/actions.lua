-- Changes actions expose panel entry points to the shared action catalog.

---@type gleb.Action[]
local actions = {
	{
		id = "changes.toggle",
		title = "Toggle Changes",
		category = "View | Tool Windows",
		run = function()
			require("gleb.git.changes").toggle()
		end,
	},
	{
		id = "changes.review",
		title = "Review Changes",
		category = "View | Tool Windows",
		run = function()
			require("gleb.git.changes").review()
		end,
	},
}

return actions
