---@type gleb.Language
return {
	name = "yaml",
	filetypes = { "yaml" },
	lsp = {
		servers = { "yamlls" },
		config = require("yaml-companion").setup({
			lspconfig = { settings = { yaml = { schemas = require("gleb.languages.yaml.schemas") } } },
		}),
		mason = { "yaml-language-server" },
	},
	treesitter = { parsers = { "yaml" } },
	references = { disabled = "no references fixture; data or markup language" },
}
