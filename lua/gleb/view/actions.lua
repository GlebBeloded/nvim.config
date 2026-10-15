-- Editor view actions expose window-local display options to the shared action catalog.

local function no_op() end

---@type gleb.Action[]
local actions = {
	{
		id = "view.soft_wrap",
		title = "Soft Wrap",
		category = "View | Editor",
		run = no_op,
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
		run = no_op,
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
