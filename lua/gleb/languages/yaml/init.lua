---@type gleb.Language
return {
	name = "yaml",
	filetypes = { "yaml" },
	lsp = { servers = { "yamlls" }, mason = { "yaml-language-server" } },
	treesitter = { parsers = { "yaml" } },
	references = { disabled = "no references fixture; data or markup language" },
}
