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
		if current_file ~= "" and not current_file:match("^%w+://") then
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

---@type gleb.Action[]
local actions = {
	{
		id = "tree.toggle_filesystem",
		title = "Toggle filesystem",
		category = "Tree",
		run = function()
			smart_toggle("filesystem")
		end,
	},
	{
		id = "tree.toggle_git_status",
		title = "Toggle git status",
		category = "Tree",
		run = function()
			smart_toggle("git_status")
		end,
	},
	neo_tree_action("open", "Open", "common", function(ctx)
		local state = tree_state(ctx)
		if state.name == "git_status" then
			git_open_file(state)
		else
			state.config = {}
			state.commands.open(state)
		end
	end),
	neo_tree_action("close_node", "Close node", "common", tree_command("close_node")),
	neo_tree_action("open_vsplit", "Open vertical split", "common", tree_command("open_vsplit")),
	neo_tree_action("open_split", "Open split", "common", tree_command("open_split")),
	neo_tree_action("open_tab", "Open tab", "common", tree_command("open_tabnew")),
	neo_tree_action("add", "Add", "common", tree_command("add", { show_path = "relative" })),
	visual_tree_action("delete", "Delete", "common", "delete"),
	neo_tree_action("rename", "Rename", "common", tree_command("rename")),
	neo_tree_action("copy", "Copy", "common", tree_command("copy")),
	visual_tree_action("cut", "Cut", "common", "cut_to_clipboard"),
	neo_tree_action("paste", "Paste", "common", tree_command("paste_from_clipboard")),
	neo_tree_action("refresh", "Refresh", "common", tree_command("refresh")),
	neo_tree_action("close", "Close", "common", function(ctx)
		if tree_state(ctx).name == "git_status" then
			git_close()
		else
			tree_command("close_window")(ctx)
		end
	end),
	neo_tree_action("help", "Help", "common", tree_command("show_help")),
	neo_tree_action("previous_source", "Previous source", "common", tree_command("prev_source")),
	neo_tree_action("next_source", "Next source", "common", tree_command("next_source")),
	neo_tree_action("toggle_hidden", "Toggle hidden", "filesystem", tree_command("toggle_hidden")),
	neo_tree_action("navigate_down", "Navigate down", "git_status", function(ctx)
		git_nav_down(tree_state(ctx))
	end),
	neo_tree_action("navigate_up", "Navigate up", "git_status", function(ctx)
		git_nav_up(tree_state(ctx))
	end),
	neo_tree_action("toggle_stage", "Toggle stage", "git_status", function(ctx)
		git_toggle_stage(tree_state(ctx))
	end),
	neo_tree_action("commit", "Commit (AI)", "git_status", function()
		git_commit()
	end),
	neo_tree_action("push", "Push", "git_status", function()
		git_push()
	end),
	neo_tree_action("add_all", "Add all", "git_status", tree_command("git_add_all")),
	neo_tree_action("revert", "Revert", "git_status", tree_command("git_revert_file")),
}

return actions
