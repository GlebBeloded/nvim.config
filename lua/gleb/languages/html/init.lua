---@type gleb.Language
return {
	name = "html",
	filetypes = { "html" },
	lsp = {
		servers = { "html" },
		config = {},
		mason = { "html-lsp", "markuplint", "prettier" },
		null_ls = function(null_ls)
			return { null_ls.builtins.diagnostics.markuplint }
		end,
	},
	treesitter = { disabled = "parser is not installed" },
	references = { disabled = "no references fixture; data or markup language" },
}
