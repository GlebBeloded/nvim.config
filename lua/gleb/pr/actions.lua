-- Pull request actions expose refresh through Find Action without owning a shortcut.

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

---@type gleb.Action[]
local actions = {
	{
		id = "pr.refresh",
		title = "Refresh Pull Request Comments",
		category = "Git | Pull Request",
		run = refresh,
	},
}

return actions
