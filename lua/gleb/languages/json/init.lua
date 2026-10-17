---@type gleb.Language
return {
	name = "json",
	filetypes = { "json", "jsonc" },
	lsp = {
		servers = { "jsonls" },
		config = {
			settings = { json = { schemas = require("gleb.languages.json.schemas"), validate = { enable = true } } },
		},
		mason = { "json-lsp" },
	},
	treesitter = { parsers = { "json" } },
	references = { disabled = "no references fixture; data or markup language" },
}
