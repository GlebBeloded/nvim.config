-- Git actions own repository operations, diffview, and the changes panel.

---@param cwd string
---@param args string[]
---@param callback fun(output: string?)
local function git_output(cwd, args, callback)
	vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }, function(result)
		vim.schedule(function()
			callback(result.code == 0 and vim.trim(result.stdout or "") or nil)
		end)
	end)
end

---@param input string
local function notify_unavailable(input)
	vim.notify(input .. " unavailable", vim.log.levels.ERROR)
end

---@param buf integer
---@param file string
---@return boolean
local function captured_file_is_valid(buf, file)
	return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == file
end

---@param ctx gleb.ActionContext
local function copy_file_url(ctx)
	if not vim.api.nvim_buf_is_valid(ctx.buf) then
		return
	end
	local file = vim.api.nvim_buf_get_name(ctx.buf)
	local cwd = vim.fs.dirname(file)
	local cwd_stat = vim.uv.fs_stat(cwd)
	if file == "" or vim.bo[ctx.buf].buftype ~= "" or not cwd_stat or cwd_stat.type ~= "directory" then
		notify_unavailable("Repository-relative file")
		return
	end
	local first_line = ctx.selection and ctx.selection.start[1] or ctx.cursor[1]
	local last_line = ctx.selection and ctx.selection.finish[1] or ctx.cursor[1]
	git_output(cwd, { "rev-parse", "--show-toplevel" }, function(root)
		if not root then
			notify_unavailable("Repository")
			return
		end
		git_output(root, { "remote", "get-url", "origin" }, function(remote)
			if not remote then
				notify_unavailable("Origin remote")
				return
			end
			git_output(root, { "symbolic-ref", "--short", "HEAD" }, function(branch)
				if not branch then
					notify_unavailable("Attached branch")
					return
				end
				local relative = vim.fs.relpath(root, file)
				if not relative then
					notify_unavailable("Repository-relative file")
					return
				end
				git_output(
					root,
					{ "-c", "core.quotePath=false", "ls-files", "--error-unmatch", "--full-name", "--", relative },
					function(path)
						if not path then
							notify_unavailable("Tracked file")
							return
						end
						if not captured_file_is_valid(ctx.buf, file) then
							notify_unavailable("File buffer")
							return
						end
						local url = require("gleb.git.file_url").build(remote, branch, path, first_line, last_line)
						if not url then
							notify_unavailable("Origin remote")
							return
						end
						vim.fn.setreg("+", url)
					end
				)
			end)
		end)
	end)
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
		id = "git.copy_file_url",
		title = "Copy File URL",
		category = "Git",
		modes = { "n", "x" },
		run = copy_file_url,
	},
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
}

vim.list_extend(actions, require("gleb.git.changes.actions"))

return actions
