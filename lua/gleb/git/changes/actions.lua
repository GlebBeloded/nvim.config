-- Changes actions expose panel entry points to the shared action catalog.

---@param name string
---@return fun()
local function run(name)
	return function()
		require("gleb.git.changes")[name]()
	end
end

---@type gleb.Action[]
local actions = {
	{
		id = "changes.toggle",
		title = "Toggle Changes",
		category = "View | Tool Windows",
		run = run("toggle"),
	},
	{
		id = "changes.review",
		title = "Review Changes",
		category = "View | Tool Windows",
		run = run("review"),
	},
	{
		id = "changes.show_local",
		title = "Show Local Changes",
		category = "View | Tool Windows",
		run = run("show_local"),
	},
	{
		id = "changes.show_branch",
		title = "Show Branch Changes",
		category = "View | Tool Windows",
		run = run("show_branch"),
	},
	{
		id = "changes.show_branch_commits",
		title = "Show Branch Commits",
		category = "View | Tool Windows",
		run = run("show_branch_commits"),
	},
	{
		id = "changes.show_comments",
		title = "Show Pull Request Comments",
		category = "View | Tool Windows",
		run = run("show_comments"),
	},
	{
		id = "changes.toggle_commits",
		title = "Toggle Commits",
		category = "Changes",
		ft = "gleb-changes",
		run = run("toggle_commits"),
	},
	{
		id = "changes.toggle_stage",
		title = "Toggle Stage",
		category = "Changes",
		ft = "gleb-changes",
		run = run("toggle_stage"),
	},
	{
		id = "changes.stage_all",
		title = "Stage All",
		category = "Changes",
		ft = "gleb-changes",
		run = run("stage_all"),
	},
	{
		id = "changes.open",
		title = "Open",
		category = "Changes",
		ft = "gleb-changes",
		run = run("open_selected"),
	},
	{
		id = "changes.revert",
		title = "Revert",
		category = "Changes",
		ft = "gleb-changes",
		run = run("revert"),
	},
	{
		id = "changes.commit",
		title = "Commit",
		category = "Changes",
		ft = "gleb-changes",
		nowait = true,
		run = run("commit"),
	},
	{
		id = "changes.push",
		title = "Push",
		category = "Changes",
		ft = "gleb-changes",
		run = run("push"),
	},
	{
		id = "changes.close",
		title = "Close",
		category = "Changes",
		ft = "gleb-changes",
		run = run("close"),
	},
}

vim.list_extend(
	actions,
	require("gleb.ui.tree.actions").fold_actions({
		area = "changes",
		category = "Changes",
		ft = "gleb-changes",
	})
)

return actions
