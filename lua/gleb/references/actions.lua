-- Find Usages actions are scoped to its buffers; later controls share the same registry ownership.
local view = require("gleb.references.view")

local function close()
	view.close()
end

local function open()
	view.open_selected()
end

local function fold()
	view.fold()
end

local function cycle_tests()
	view.cycle_tests()
end

local function toggle_folders()
	view.toggle_folders()
end

local function toggle_preview()
	view.toggle_preview()
end

local function toggle_usage_type()
	view.toggle_usage_type()
end

---@type gleb.Action[]
return {
	{
		id = "references.open",
		title = "Open Usage",
		category = "References",
		ft = "gleb-references",
		run = open,
	},
	{
		id = "references.fold",
		title = "Fold Group",
		category = "References",
		ft = "gleb-references",
		run = fold,
	},
	{
		id = "references.cycle_tests",
		title = "Cycle Tests",
		category = "References",
		ft = "gleb-references",
		run = cycle_tests,
	},
	{
		id = "references.toggle_folders",
		title = "Toggle Folders",
		category = "References",
		ft = "gleb-references",
		run = toggle_folders,
	},
	{
		id = "references.toggle_usage_type",
		title = "Toggle Usage Type",
		category = "References",
		ft = "gleb-references",
		run = toggle_usage_type,
	},
	{
		id = "references.toggle_preview",
		title = "Toggle Preview",
		category = "References",
		ft = "gleb-references",
		run = toggle_preview,
	},
	{ id = "references.close", title = "Close", category = "References", ft = "gleb-references", run = close },
}
