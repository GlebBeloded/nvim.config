-- File-tree actions own entry points and neo-tree-local behavior; the adapter supplies keys.

local diff_preview = require("gleb.file_tree.diff_preview")

---@param source string
---@param current_source string
local function apply_toggle(source, current_source)
	if current_source == source then
		vim.cmd("Neotree close")
	else
		vim.cmd("Neotree " .. source)
	end
end

---@param callback function
local function after_pending_filesystem_render(callback)
	local state = require("neo-tree.sources.manager").get_state("filesystem")
	local events = require("neo-tree.events")
	local render_generation = 0
	local finished = false
	local subscription
	local function finish()
		if finished then
			return
		end
		finished = true
		events.unsubscribe(subscription)
		callback()
	end
	local function finish_after_debounce()
		render_generation = render_generation + 1
		local expected_generation = render_generation
		vim.defer_fn(function()
			if expected_generation == render_generation and state._ready ~= false then
				finish()
			end
		end, 120)
	end
	subscription = {
		event = events.AFTER_RENDER,
		handler = function(rendered_state)
			if rendered_state == state then
				finish_after_debounce()
			end
		end,
	}
	events.subscribe(subscription)
	finish_after_debounce()
	vim.defer_fn(finish, 5000)
end

---@param source string
local function smart_toggle(source)
	local current_buf = vim.api.nvim_get_current_buf()
	if vim.bo[current_buf].filetype == "neo-tree" then
		local current_source = vim.api.nvim_buf_get_name(current_buf):match("neo%-tree ([%w_]+)")
		if current_source == "filesystem" then
			after_pending_filesystem_render(function()
				apply_toggle(source, current_source)
			end)
		else
			apply_toggle(source, current_source)
		end
	elseif source == "filesystem" then
		local current_file = vim.fn.expand("%:p")
		if current_file ~= "" and not current_file:match("^%w+://") and vim.fn.filereadable(current_file) == 1 then
			vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(current_file) .. " filesystem")
		else
			require("neo-tree.command").execute({ source = "filesystem", action = "focus", reveal = false })
		end
	else
		vim.cmd("Neotree focus " .. source)
	end
end

---@param ctx gleb.ActionContext
---@return table
local function tree_state(ctx)
	return assert(require("neo-tree.sources.manager").get_state_for_window(ctx.win), "neo-tree state not found")
end

---@param command string
---@param config? table
---@return fun(ctx: gleb.ActionContext)
local function tree_command(command, config)
	return function(ctx)
		local state = tree_state(ctx)
		state.config = config or {}
		assert(state.commands[command], "neo-tree command not found: " .. command)(state)
	end
end

---@param state table
local function git_nav_down(state)
	local last_row = vim.api.nvim_buf_line_count(0)
	repeat
		vim.cmd("normal! j")
		if vim.api.nvim_win_get_cursor(0)[1] >= last_row then
			break
		end
	until state.tree:get_node().type == "file"
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path and vim.fn.filereadable(node.path) == 1 then
		diff_preview.open_diff(node.path)
	end
end

---@param state table
local function git_nav_up(state)
	repeat
		vim.cmd("normal! k")
		if vim.api.nvim_win_get_cursor(0)[1] <= 1 then
			break
		end
	until state.tree:get_node().type == "file"
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path and vim.fn.filereadable(node.path) == 1 then
		diff_preview.open_diff(node.path)
	end
end

---@param state table
local function git_open_file(state)
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path then
		diff_preview.close_all_diffs()
		vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(node.path) .. " filesystem")
		vim.cmd("wincmd l")
		vim.cmd("edit " .. vim.fn.fnameescape(node.path))
	end
end

local function git_close()
	diff_preview.return_to_original()
	vim.cmd("Neotree close")
end

---@param path string
---@param cwd string
---@return boolean? staged
---@return string? stderr
local function is_staged(path, cwd)
	local result = vim.system({ "git", "diff", "--cached", "--quiet", "--", path }, { cwd = cwd, text = true }):wait()
	if result.code == 1 then
		return true
	elseif result.code == 0 then
		return false
	end
	return nil, result.stderr
end

---@param args string[]
---@param cwd string
---@param failure_prefix string
local function run_git(args, cwd, failure_prefix)
	local result = vim.system(args, { cwd = cwd, text = true }):wait()
	if result.code ~= 0 then
		vim.notify(failure_prefix .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
	end
end

---@param state table
local function git_toggle_stage(state)
	local node = state.tree:get_node()
	if not (node and node.path) then
		return
	end
	local cwd, path = state.path, node.path
	local staged, stderr = is_staged(path, cwd)
	if staged == nil then
		vim.notify("Stage failed: " .. vim.trim(stderr or ""), vim.log.levels.ERROR)
	elseif staged then
		run_git({ "git", "reset", "-q", "--", path }, cwd, "Unstage failed: ")
	else
		run_git({ "git", "add", "--", path }, cwd, "Stage failed: ")
	end
	require("neo-tree.sources.manager").refresh("git_status")
end

---@param msg string
---@param result vim.SystemCompleted
local function on_commit_exit(msg, result)
	vim.schedule(function()
		if result.code == 0 then
			require("neo-tree.sources.manager").refresh("git_status")
			vim.notify("Committed: " .. vim.split(msg, "\n")[1], vim.log.levels.INFO)
			return
		end
		local stderr, stdout = vim.trim(result.stderr or ""), vim.trim(result.stdout or "")
		local reason = stderr ~= "" and stderr or stdout ~= "" and stdout or ("exit " .. result.code)
		vim.notify("Commit failed: " .. reason, vim.log.levels.ERROR)
	end)
end

local function git_commit()
	require("gleb.git.ai_commit").show_commit_input(function(msg)
		vim.system({ "git", "commit", "-m", msg }, { text = true }, function(result)
			on_commit_exit(msg, result)
		end)
	end)
end

local function git_push()
	vim.notify("Pushing...", vim.log.levels.INFO)
	vim.fn.jobstart("git push", {
		on_exit = function(_, code)
			vim.notify(
				code == 0 and "Pushed successfully" or "Push failed",
				code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
			)
		end,
	})
end

---@param id string
---@param title string
---@param scope "common"|"filesystem"|"git_status"
---@param run fun(ctx: gleb.ActionContext)
---@return gleb.Action
local function neo_tree_action(id, title, scope, run)
	return {
		id = "neo_tree." .. id,
		title = title,
		category = "Tree",
		plugin = "neo-tree",
		neo_tree_scope = scope,
		run = run,
	}
end

---@param id string
---@param title string
---@param scope "common"|"filesystem"|"git_status"
---@param command string
---@return gleb.Action
local function visual_tree_action(id, title, scope, command)
	local action = neo_tree_action(id, title, scope, tree_command(command))
	action.commands = { command }
	action.modes = { "n", "x", "s" }
	return action
end

local function project_open()
	require("gleb.file_tree.view").open()
end

local function project_close_node()
	require("gleb.file_tree.view").close_node()
end

local function project_close()
	require("gleb.file_tree.view").close()
end

local function project_open_vsplit()
	require("gleb.file_tree.view").open_vsplit()
end

local function project_open_split()
	require("gleb.file_tree.view").open_split()
end

local function project_open_tab()
	require("gleb.file_tree.view").open_tab()
end

local function project_toggle_fold()
	require("gleb.file_tree.view").toggle_fold()
end

local function project_fold_all()
	require("gleb.file_tree.view").fold_all()
end

local function project_unfold_all()
	require("gleb.file_tree.view").unfold_all()
end

local function project_add()
	require("gleb.file_tree.ops").add()
end

local function project_rename()
	require("gleb.file_tree.ops").rename()
end

local function project_delete()
	require("gleb.file_tree.ops").delete()
end

---@param ctx gleb.ActionContext
local function project_copy(ctx)
	require("gleb.file_tree.ops").copy(ctx)
end

---@param ctx gleb.ActionContext
local function project_cut(ctx)
	require("gleb.file_tree.ops").cut(ctx)
end

local function project_paste()
	require("gleb.file_tree.ops").paste()
end

local function project_refresh()
	require("gleb.file_tree.ops").refresh()
end

---@type gleb.Action[]
local actions = {
	{
		id = "file_tree.toggle",
		title = "Toggle Project Tree",
		category = "Project",
		run = function()
			require("gleb.file_tree.view").toggle()
		end,
	},
	{
		id = "file_tree.reveal",
		title = "Reveal in Project Tree",
		category = "Project",
		run = function()
			require("gleb.file_tree.view").reveal()
		end,
	},
	{
		id = "file_tree.add",
		title = "New File or Directory",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_add,
	},
	{
		id = "file_tree.rename",
		title = "Rename",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_rename,
	},
	{
		id = "file_tree.delete",
		title = "Delete",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_delete,
	},
	{
		id = "file_tree.copy",
		title = "Copy",
		category = "Project",
		ft = "gleb-file-tree",
		modes = { "n", "x" },
		run = project_copy,
	},
	{
		id = "file_tree.cut",
		title = "Cut",
		category = "Project",
		ft = "gleb-file-tree",
		modes = { "n", "x" },
		run = project_cut,
	},
	{
		id = "file_tree.paste",
		title = "Paste",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_paste,
	},
	{
		id = "file_tree.refresh",
		title = "Refresh",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_refresh,
	},
	{
		id = "file_tree.open",
		title = "Open",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open,
	},
	{
		id = "file_tree.close_node",
		title = "Close Node",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_close_node,
	},
	{
		id = "file_tree.close",
		title = "Close",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_close,
	},
	{
		id = "file_tree.open_vsplit",
		title = "Open in Vertical Split",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open_vsplit,
	},
	{
		id = "file_tree.open_split",
		title = "Open in Horizontal Split",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open_split,
	},
	{
		id = "file_tree.open_tab",
		title = "Open in New Tab",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open_tab,
	},
	{
		id = "file_tree.toggle_fold",
		title = "Toggle Fold",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_toggle_fold,
	},
	{
		id = "file_tree.fold_all",
		title = "Fold All",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_fold_all,
	},
	{
		id = "file_tree.unfold_all",
		title = "Unfold All",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_unfold_all,
	},
	{
		id = "tree.toggle_filesystem",
		title = "Toggle File Tree",
		category = "View | Tool Windows",
		run = function()
			smart_toggle("filesystem")
		end,
	},
	{
		id = "tree.toggle_git_status",
		title = "Toggle Git Status Tree",
		category = "View | Tool Windows",
		run = function()
			smart_toggle("git_status")
		end,
	},
	neo_tree_action("open", "Open Tree Node", "common", tree_command("open")),
	neo_tree_action("git_open_file", "Open Git Tree File", "git_status", function(ctx)
		git_open_file(tree_state(ctx))
	end),
	neo_tree_action("close_node", "Close Tree Node", "common", tree_command("close_node")),
	neo_tree_action("open_vsplit", "Open Tree Node in Vertical Split", "common", tree_command("open_vsplit")),
	neo_tree_action("open_split", "Open Tree Node in Horizontal Split", "common", tree_command("open_split")),
	neo_tree_action("open_tab", "Open Tree Node in New Tab", "common", tree_command("open_tabnew")),
	neo_tree_action("add", "Add Tree Node", "common", tree_command("add", { show_path = "relative" })),
	visual_tree_action("delete", "Delete Tree Node", "common", "delete"),
	neo_tree_action("rename", "Rename Tree Node", "common", tree_command("rename")),
	neo_tree_action("copy", "Copy Tree Node", "common", tree_command("copy")),
	visual_tree_action("cut", "Cut Tree Node", "common", "cut_to_clipboard"),
	neo_tree_action("paste", "Paste Tree Node", "common", tree_command("paste_from_clipboard")),
	neo_tree_action("refresh", "Refresh Tree", "common", tree_command("refresh")),
	neo_tree_action("close", "Close Tree", "common", function(ctx)
		if tree_state(ctx).name == "git_status" then
			git_close()
		else
			tree_command("close_window")(ctx)
		end
	end),
	neo_tree_action("help", "Show Tree Help", "common", tree_command("show_help")),
	neo_tree_action("previous_source", "Show Previous Tree Source", "common", tree_command("prev_source")),
	neo_tree_action("next_source", "Show Next Tree Source", "common", tree_command("next_source")),
	neo_tree_action("toggle_hidden", "Toggle Hidden Tree Files", "filesystem", tree_command("toggle_hidden")),
	neo_tree_action("navigate_down", "Navigate Down Git Status Tree", "git_status", function(ctx)
		git_nav_down(tree_state(ctx))
	end),
	neo_tree_action("navigate_up", "Navigate Up Git Status Tree", "git_status", function(ctx)
		git_nav_up(tree_state(ctx))
	end),
	neo_tree_action("toggle_stage", "Toggle Git Tree Node Staging", "git_status", function(ctx)
		git_toggle_stage(tree_state(ctx))
	end),
	neo_tree_action("commit", "Commit Git Changes with AI", "git_status", function()
		git_commit()
	end),
	neo_tree_action("push", "Push Git Changes", "git_status", function()
		git_push()
	end),
	neo_tree_action("add_all", "Stage All Git Changes", "git_status", tree_command("git_add_all")),
	neo_tree_action("revert", "Revert Git Tree File", "git_status", tree_command("git_revert_file")),
}

return actions
