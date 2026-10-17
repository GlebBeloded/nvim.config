local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
end)

T["references: Every query capture is in the catalogue"] = function()
	local actual = child.lua_get([[(function()
		local catalogue = require("gleb.references.usage_types")
		local query_languages = { ecma = "javascript", ts_angle_cast = "typescript" }
		local languages = {}
		for _, path in ipairs(vim.api.nvim_get_runtime_file("queries/*/usages.scm", true)) do
			languages[path:match("/queries/([^/]+)/usages%.scm$")] = true
		end
		local names = vim.tbl_keys(languages)
		table.sort(names)
		local unknown = {}
		for _, language in ipairs(names) do
			local query_language = query_languages[language] or language
			local loaded, reason = vim.treesitter.language.add(query_language)
			assert(loaded, reason or (language .. " parser is not installed"))
			local query = assert(
				vim.treesitter.query.get(query_language, "usages"),
				language .. " usages query is missing"
			)
			for _, capture in ipairs(query.captures) do
				if not vim.startswith(capture, "_") then
					local id = capture:match("^usage%.(.+)$")
					if id == nil or catalogue[id] == nil then
						table.insert(unknown, language .. ":" .. capture)
					end
				end
			end
		end
		return { languages = names, unknown = unknown }
	end)()]])

	eq(actual.languages, {
		"bash",
		"ecma",
		"go",
		"gomod",
		"hcl",
		"javascript",
		"lua",
		"python",
		"terraform",
		"ts_angle_cast",
		"tsx",
		"typescript",
	})
	eq(actual.unknown, {})
end

T["references: Go types carry GoLand labels"] = MiniTest.new_set()

T["references: Go types carry GoLand labels"]["Go ids have the approved labels"] = function()
	local labels = child.lua_get([[(function()
		local catalogue = require("gleb.references.usage_types")
		local ids = {
			"call",
			"const_declaration",
			"field_declaration",
			"function_argument",
			"import",
			"parameter_declaration",
			"receiver",
			"return_type",
			"struct_initialization",
			"type_alias",
			"type_assertion",
			"type_constraint",
			"type_conversion",
			"type_instantiation",
			"type_parameter_declaration",
			"variable_declaration",
			"read",
			"write",
		}
		return vim.tbl_map(function(id)
			return catalogue[id].label
		end, ids)
	end)()]])

	eq(labels, {
		"Call",
		"Const declaration",
		"Field declaration",
		"Function argument",
		"Import",
		"Parameter declaration",
		"Receiver",
		"Return type",
		"Struct initialization",
		"Type alias",
		"Type assertion",
		"Type constraint",
		"Type conversion",
		"Type instantiation",
		"Type parameter declaration",
		"Variable declaration",
		"Value read",
		"Value write",
	})
end

T["references: Go types carry GoLand labels"]["catalogue metadata is complete and ordered by label"] = function()
	local actual = child.lua_get([[(function()
		local catalogue = require("gleb.references.usage_types")
		local labels = {}
		local complete = true
		for _, item in pairs(catalogue) do
			complete = complete
				and type(item.label) == "string"
				and type(item.icon) == "string"
				and item.icon ~= ""
				and type(item.colour) == "string"
				and type(item.tag) == "string"
				and type(item.order) == "number"
			labels[item.order] = item.label
		end
		local sorted = vim.deepcopy(labels)
		table.sort(sorted)
		return { complete = complete, labels = labels, sorted = sorted }
	end)()]])

	eq(actual.complete, true)
	eq(actual.labels, actual.sorted)
end

return T
