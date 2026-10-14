-- Comment actions delegate to mini.comment's operator mappings while retaining the active mode.

local function toggle(ctx)
	local keys = ctx.mode == "n" and "gcc" or "gc"
	vim.api.nvim_feedkeys(vim.keycode(keys), "m", false)
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
