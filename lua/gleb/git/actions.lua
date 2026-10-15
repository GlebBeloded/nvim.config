-- Git entry actions lazy-load their viewer commands; viewer adapters supply buffer-local keys.

---@param id string
local function replay_shortcut(id)
	local store = assert(require("gleb.actions").state.store, "actions are not set up")
	local lhs = assert(store.last_good[id], "shortcut is not configured")[1]
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), "m", false)
end

---@param id string
---@param title string
---@param plugin string
---@return gleb.Action
local function viewer_action(id, title, plugin)
	local action_id = plugin .. "." .. id
	return {
		id = action_id,
		title = title,
		category = "Git | Diff",
		plugin = plugin,
		run = function()
			replay_shortcut(action_id)
		end,
	}
end

---@param id string
---@param title string
---@param scopes string[]
---@param run fun()
---@return gleb.Action
local function diffview_action(id, title, scopes, run)
	return {
		id = "diffview." .. id,
		title = title,
		category = "Git | Diff",
		plugin = "diffview",
		diffview_scopes = scopes,
		run = run,
	}
end

---@param name string
---@return fun()
local function diffview_run(name)
	return function()
		require("diffview.actions")[name]()
	end
end

---@param target "ours"|"theirs"|"base"|"all"
---@return gleb.Action
local function diffview_conflict_action(target)
	return diffview_action(
		"choose_" .. target,
		"Choose Conflict " .. target:gsub("^%l", string.upper),
		{ "view" },
		function()
			require("diffview.actions").conflict_choose(target)()
		end
	)
end

---@type gleb.Action[]
local actions = {
	{
		id = "git.confirm_commit_popup",
		title = "Confirm Commit Message",
		category = "Git",
		plugin = "git-commit-popup",
		run = function(ctx)
			require("gleb.git.ai_commit").confirm(ctx.buf)
		end,
	},
	{
		id = "git.discard_commit_popup",
		title = "Discard Commit Message",
		category = "Git",
		plugin = "git-commit-popup",
		run = function(ctx)
			require("gleb.git.ai_commit").discard(ctx.buf)
		end,
	},
	{
		id = "git.open_differ",
		title = "Open Differ",
		category = "Git | Diff",
		run = function()
			vim.cmd.Differ()
		end,
	},
	diffview_action(
		"select_next_entry",
		"Select Next Diffview Entry",
		{ "view", "file_panel" },
		diffview_run("select_next_entry")
	),
	diffview_action(
		"select_prev_entry",
		"Select Previous Diffview Entry",
		{ "view", "file_panel" },
		diffview_run("select_prev_entry")
	),
	diffview_action("goto_file_edit", "Open Diffview File for Editing", { "view" }, diffview_run("goto_file_edit")),
	diffview_conflict_action("ours"),
	diffview_conflict_action("theirs"),
	diffview_conflict_action("base"),
	diffview_conflict_action("all"),
	diffview_action("choose_none", "Drop All Diffview Conflict Sides", { "view" }, function()
		require("diffview.actions").conflict_choose("none")()
	end),
	diffview_action("select_entry", "Select Diffview Entry", { "file_panel" }, diffview_run("select_entry")),
	diffview_action("close_fold", "Close Diffview Fold", { "file_panel" }, diffview_run("close_fold")),
	diffview_action(
		"toggle_stage_entry",
		"Toggle Diffview Entry Staging",
		{ "file_panel" },
		diffview_run("toggle_stage_entry")
	),
	diffview_action("stage_all", "Stage All Diffview Files", { "file_panel" }, diffview_run("stage_all")),
	diffview_action("unstage_all", "Unstage All Diffview Files", { "file_panel" }, diffview_run("unstage_all")),
	diffview_action("refresh_files", "Refresh Diffview Files", { "file_panel" }, diffview_run("refresh_files")),
	diffview_action("close", "Close Diffview", { "file_panel" }, function()
		vim.cmd.DiffviewClose()
	end),
	viewer_action("next_file", "Select Next Differ File", "differ"),
	viewer_action("next_hunk", "Select Next Differ Hunk", "differ"),
	viewer_action("next_hunk", "Select Next Codediff Hunk", "codediff"),
}

return actions
