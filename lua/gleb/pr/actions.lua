-- Pull request actions expose refresh and thread navigation through Find Action without owning a shortcut.

---@param ctx gleb.ActionContext
---@return nil
local function refresh(ctx)
	local path = vim.api.nvim_buf_get_name(ctx.buf)
	if path == "" then
		path = vim.fn.getcwd()
	end
	require("gleb.git.base").resolve(path, function(_, root)
		if root then
			require("gleb.pr").refresh(root, { force = true })
		end
	end)
end

---@param direction 1|-1
---@return fun(ctx: gleb.ActionContext)
local function thread_jumper(direction)
	return function(ctx)
		require("gleb.pr.navigate").jump(ctx.win, direction)
	end
end

---@param ctx gleb.ActionContext
---@return nil
local function open_thread(ctx)
	require("gleb.pr.thread_window").open_at_cursor(ctx.win, ctx.buf)
end

---@param name "send"|"resolve"|"open_web"|"close_current"
---@return fun()
local function thread_action(name)
	return function()
		require("gleb.pr.thread_window")[name]()
	end
end

---@type gleb.Action[]
local actions = {
	{
		id = "pr.refresh",
		title = "Refresh Pull Request Comments",
		category = "Git | Pull Request",
		run = refresh,
	},
	{
		id = "pr.next_thread",
		title = "Next Review Thread",
		category = "Git | Pull Request",
		run = thread_jumper(1),
	},
	{
		id = "pr.prev_thread",
		title = "Previous Review Thread",
		category = "Git | Pull Request",
		run = thread_jumper(-1),
	},
	{
		id = "pr.open_thread",
		title = "Open Review Thread",
		category = "Git | Pull Request",
		run = open_thread,
	},
	{
		id = "pr.thread_send",
		title = "Reply to Thread",
		category = "Git | Pull Request",
		ft = "gleb-pr-thread",
		run = thread_action("send"),
	},
	{
		id = "pr.thread_resolve",
		title = "Resolve or Unresolve Thread",
		category = "Git | Pull Request",
		ft = "gleb-pr-thread",
		run = thread_action("resolve"),
	},
	{
		id = "pr.thread_open_web",
		title = "Open Thread on Web",
		category = "Git | Pull Request",
		ft = "gleb-pr-thread",
		run = thread_action("open_web"),
	},
	{
		id = "pr.thread_close",
		title = "Close Thread",
		category = "Git | Pull Request",
		ft = "gleb-pr-thread",
		run = thread_action("close_current"),
	},
}

return actions
