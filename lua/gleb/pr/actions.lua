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
}

return actions
