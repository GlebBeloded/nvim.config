-- Find Usages actions are scoped to its buffers; later controls share the same registry ownership.
local function close()
	require("gleb.references.view").close()
end

local function open()
	require("gleb.references.view").open_selected()
end

local function cycle_tests()
	require("gleb.references.view").cycle_tests()
end

local function toggle_folders()
	require("gleb.references.view").toggle_folders()
end

local function toggle_preview()
	require("gleb.references.view").toggle_preview()
end

local function toggle_usage_type()
	require("gleb.references.view").toggle_usage_type()
end

---@type gleb.Action[]
local actions = {
	{
		id = "references.open",
		title = "Open Usage",
		category = "References",
		ft = "gleb-references",
		run = open,
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

local fold_actions = require("gleb.ui.tree.actions").fold_actions({
	area = "references",
	category = "References",
	ft = "gleb-references",
	toggle_id = "references.fold",
})
fold_actions[3].title = "Fold Group"
vim.list_extend(actions, fold_actions)

return actions
