-- Register language contracts without loading their feature implementations.

local languages = require("gleb.languages")

languages.register_facet("lsp", function(config, language)
	if not vim.islist(config.servers) or not vim.islist(config.mason) then
		return ("languages: %s has invalid lsp facet"):format(language.name)
	end
end)

languages.register_facet("references", function(config, language)
	local usage_types = config.usage_types
	local usage_types_valid = usage_types == true
		or (type(usage_types) == "table" and type(usage_types.disabled) == "string" and usage_types.disabled:find("%S"))
	local write_access_valid = config.write_access == false
		or config.write_access == "documentHighlight"
		or config.write_access == "tsserver"
	local fixture = config.fixture
	if
		not vim.islist(config.test_patterns)
		or not usage_types_valid
		or not write_access_valid
		or type(config.target_kinds) ~= "table"
		or type(fixture) ~= "table"
		or type(fixture.project) ~= "string"
		or type(fixture.symbol) ~= "string"
	then
		return ("languages: %s has invalid references facet"):format(language.name)
	end
end)

languages.register_facet("treesitter", function(config, language)
	if not vim.islist(config.parsers) then
		return ("languages: %s has invalid treesitter facet"):format(language.name)
	end
end)
