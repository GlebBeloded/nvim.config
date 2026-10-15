-- Comment actions delegate to mini.comment's operator mappings while retaining the active mode.

local Context = require("gleb.actions.context")

---@param ctx gleb.ActionContext
local function toggle(ctx)
	local keys = ctx.mode == "n" and "gcc" or "gc"
	vim.api.nvim_feedkeys(vim.keycode(Context.counted(ctx, keys)), "m", false)
end

---@type gleb.Action[]
local actions = {
	{
		id = "comments.toggle",
		title = "Toggle",
		category = "Comments",
		modes = { "n", "x" },
		run = toggle,
	},
}

return actions
