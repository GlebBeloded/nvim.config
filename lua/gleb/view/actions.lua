-- Editor view actions expose window-local display options to the shared action catalog.

---@param ctx gleb.ActionContext
local function toggle_soft_wrap(ctx)
	vim.wo[ctx.win].wrap = not vim.wo[ctx.win].wrap
end

---@param ctx gleb.ActionContext
local function toggle_spell_check(ctx)
	vim.wo[ctx.win].spell = not vim.wo[ctx.win].spell
end

---@type gleb.Action[]
local actions = {
	{
		id = "view.soft_wrap",
		title = "Soft Wrap",
		category = "View | Editor",
		run = toggle_soft_wrap,
		toggle = {
			get = function(ctx)
				return vim.wo[ctx.win].wrap
			end,
			set = function(ctx, value)
				vim.wo[ctx.win].wrap = value
			end,
		},
	},
	{
		id = "view.spell_check",
		title = "Spell Check",
		category = "View | Editor",
		run = toggle_spell_check,
		toggle = {
			get = function(ctx)
				return vim.wo[ctx.win].spell
			end,
			set = function(ctx, value)
				vim.wo[ctx.win].spell = value
			end,
		},
	},
}

return actions
