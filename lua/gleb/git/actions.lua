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
		category = "Git",
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
		category = "Git",
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

---@type gleb.Action[]
local actions = {
	{
		id = "git.open_differ",
		title = "Open Differ",
		category = "Git",
		run = function()
			vim.cmd.Differ()
		end,
	},
	diffview_action(
		"select_next_entry",
		"Select next entry",
		{ "view", "file_panel" },
		diffview_run("select_next_entry")
	),
	diffview_action(
		"select_prev_entry",
		"Select previous entry",
		{ "view", "file_panel" },
		diffview_run("select_prev_entry")
	),
	diffview_action("goto_file_edit", "Go to file", { "view" }, diffview_run("goto_file_edit")),
	diffview_action("choose_none", "Drop conflict sides", { "view" }, function()
		require("diffview.actions").conflict_choose("none")()
	end),
	diffview_action("next_entry", "Next entry", { "file_panel" }, diffview_run("next_entry")),
	diffview_action("prev_entry", "Previous entry", { "file_panel" }, diffview_run("prev_entry")),
	diffview_action("select_entry", "Select entry", { "file_panel" }, diffview_run("select_entry")),
	diffview_action("close_fold", "Close fold", { "file_panel" }, diffview_run("close_fold")),
	diffview_action("toggle_stage_entry", "Toggle stage entry", { "file_panel" }, diffview_run("toggle_stage_entry")),
	diffview_action("stage_all", "Stage all", { "file_panel" }, diffview_run("stage_all")),
	diffview_action("unstage_all", "Unstage all", { "file_panel" }, diffview_run("unstage_all")),
	diffview_action("refresh_files", "Refresh files", { "file_panel" }, diffview_run("refresh_files")),
	diffview_action("close", "Close", { "file_panel" }, function()
		vim.cmd.DiffviewClose()
	end),
	viewer_action("next_hunk", "Next hunk", "differ"),
	viewer_action("next_hunk", "Next hunk", "codediff"),
}

return actions
