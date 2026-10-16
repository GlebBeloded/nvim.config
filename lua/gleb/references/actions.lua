-- Find Usages actions are scoped to its buffers; later controls share the same registry ownership.
local view = require("gleb.references.view")

local function close()
	view.close()
end

local function pending_control()
	return false
end

---@type gleb.Action[]
return {
	{
		id = "references.open",
		title = "Open Usage",
		category = "References",
		ft = "gleb-references",
		run = pending_control,
	},
	{
		id = "references.fold",
		title = "Fold Group",
		category = "References",
		ft = "gleb-references",
		run = pending_control,
	},
	{
		id = "references.cycle_tests",
		title = "Cycle Tests",
		category = "References",
		ft = "gleb-references",
		run = pending_control,
	},
	{
		id = "references.toggle_folders",
		title = "Toggle Folders",
		category = "References",
		ft = "gleb-references",
		run = pending_control,
	},
	{
		id = "references.toggle_preview",
		title = "Toggle Preview",
		category = "References",
		ft = "gleb-references",
		run = pending_control,
	},
	{ id = "references.close", title = "Close", category = "References", ft = "gleb-references", run = close },
}
