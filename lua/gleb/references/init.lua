-- Find Usages captures the symbol before the asynchronous request and opens its dedicated view.
local M = {}

local languages = require("gleb.languages")
local request = require("gleb.references.request")
local kind = require("gleb.references.kind")
local view = require("gleb.references.view")

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

---@return nil
function M.open()
	local symbol = vim.fn.expand("<cword>")
	local origin = kind.origin()
	request.start(function(usages)
		local view_id = view.open(symbol, usages, true)
		kind.classify(usages, function(classified)
			view.finish_classification(view_id, classified)
		end, origin)
	end)
end

return M
