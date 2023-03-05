local luasnip = require("luasnip")
local cmp = require("cmp")
local types = require("cmp.types")

-- find more here: https://www.nerdfonts.com/cheat-sheet
local cmp_kinds = {
	Text = "",
	Constant = "",
	Method = "",
	Function = "",
	Constructor = "",
	Field = "",
	Variable = "",
	Class = " ",
	Interface = "",
	Module = "",
	Property = "",
	Unit = "塞",
	Value = " ",
	Enum = "練",
	EnumMember = " ",
	Keyword = " ",
	Snippet = "",
	Color = "",
	File = "",
	Reference = "",
	Folder = "",
	Struct = "",
	Event = "",
	Operator = "",
	TypeParameter = "",
	Copilot = "󰚩",
}

local has_words_before = function()
	if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
		return false
	end
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
end

local mapping = {
	["<Tab>"] = vim.schedule_wrap(function(fallback)
		if cmp.visible() and has_words_before() then
			cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
		else
			fallback()
		end
	end),
	["<S-Tab>"] = cmp.mapping.select_prev_item({ behavior = types.cmp.SelectBehavior.Select }),
	["<CR>"] = cmp.mapping.confirm(),
}

cmp.setup({
	mapping = mapping,
	preselect = types.cmp.PreselectMode.Item,
	snippet = { -- cmp does not work without snippet engine
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	formatting = {
		fields = { types.cmp.ItemField.Kind, types.cmp.ItemField.Abbr, types.cmp.ItemField.Menu },
		format = function(entry, vim_item)
			-- Kind icons
			vim_item.kind = string.format("%s", cmp_kinds[vim_item.kind])

			-- this will show more description for the item
			-- also you must add to fields list above
			-- vim_item.menu = entry:get_completion_item().detail

			-- this will show what plugin provided the suggestion
			-- also you must add to fields list above
			-- vim_item.menu = entry.source.name

			return vim_item
		end,
	},
	sources = {
		-- Copilot Source
		{ name = "nvim_lsp", group_index = 1 },
		{ name = "nvim_lua", group_index = 1 },
		{ name = "path", group_index = 1 },
		{ name = "copilot", group_index = 1 }, -- for some reason copilot doesn't work if there is not enough lines
		{ name = "cmdline", group_index = 2 }, -- this will enable completion for neovim cmdline(:)
	},
	confirm_opts = {
		behavior = types.cmp.ConfirmBehavior.Replace,
		select = false,
	},
	window = {
		documentation = {},
	},
	experimental = {
		ghost_text = true,
	},
})
