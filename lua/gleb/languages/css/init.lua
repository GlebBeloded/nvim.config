---@type gleb.Language
return {
	name = "css",
	filetypes = { "css", "less", "scss" },
	lsp = {
		servers = { "cssls" },
		config = {},
		mason = { "css-lsp", "stylelint", "prettier" },
		null_ls = function(null_ls)
			return { null_ls.builtins.diagnostics.stylelint }
		end,
	},
	treesitter = { disabled = "parser is not installed" },
	references = { disabled = "no references fixture; data or markup language" },
}
