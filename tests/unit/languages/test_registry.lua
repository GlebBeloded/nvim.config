local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[Registry = require("gleb.languages")]])
end

local T = H.child_set(child, start)

local function register_base_facets()
	child.lua([[
		Registry.register_facet("lsp", function(config)
			return config.servers == nil and "lsp requires servers" or nil
		end)
		Registry.register_facet("references", function() end)
		Registry.register_facet("treesitter", function() end)
	]])
end

local function validation_error()
	return child.lua_get([[(function()
		local ok, err = pcall(Registry.validate)
		return ok and "" or tostring(err)
	end)()]])
end

T["languages: Every configured language is registered"] = function()
	eq(
		child.lua_get([[vim.tbl_map(function(language) return language.name end, Registry.all())]]),
		{ "css", "go", "html", "js", "json", "lua", "python", "rust", "shell", "terraform", "yaml" }
	)
end

T["languages: A filetype resolves to its language"] = function()
	eq(
		child.lua_get([[
			vim.tbl_map(function(filetype)
				local language = Registry.for_filetype(filetype)
				return language and language.name or vim.NIL
			end, { "typescriptreact", "sh", "tf", "gomod" })
		]]),
		{ "js", "shell", "terraform", "go" }
	)
end

T["languages: A new language folder is discovered"] = function()
	local runtime = H.tempdir(child)
	child.lua(
		[[
			local runtime = ...
			local path = vim.fs.joinpath(runtime, "lua/gleb/languages/zig/init.lua")
			vim.fn.mkdir(vim.fs.dirname(path), "p")
			vim.fn.writefile({
				"---@type gleb.Language",
				"return {",
				'  name = "zig",',
				'  filetypes = { "zig" },',
				'  lsp = { disabled = "not configured" },',
				'  treesitter = { disabled = "not configured" },',
				'  references = { disabled = "not configured" },',
				"}",
			}, path)
			vim.opt.runtimepath:prepend(runtime)
			Registry.reset()
		]],
		{ runtime }
	)

	eq(child.lua_get([[Registry.for_filetype("zig").name]]), "zig")
	eq(
		child.lua_get(
			[[vim.tbl_contains(vim.tbl_map(function(language) return language.name end, Registry.all()), "zig")]]
		),
		true
	)
end

T["languages: Registered facets"] = MiniTest.new_set()

T["languages: Registered facets"]["lists names and returns enabled configurations"] = function()
	register_base_facets()

	eq(child.lua_get([[Registry.facet_names()]]), { "lsp", "references", "treesitter" })
	eq(
		child.lua_get([[
			vim.tbl_map(function(entry) return entry.language.name end, Registry.facet("treesitter"))
		]]),
		{ "go", "js", "json", "lua", "python", "rust", "shell", "terraform", "yaml" }
	)
end

T["languages: Registered facets"]["rejects unknown facet keys"] = function()
	register_base_facets()
	child.lua([[
		local language = Registry.all()[1]
		language.surprise = {}
	]])

	eq(
		validation_error():match("languages: css has unknown facet surprise"),
		"languages: css has unknown facet surprise"
	)
end

T["languages: A language missing a facet fails at startup"] = function()
	register_base_facets()
	child.lua([[
		local language = Registry.all()[1]
		language.name = "zig"
		language.references = nil
	]])

	eq(validation_error():match("languages: zig lacks facet references"), "languages: zig lacks facet references")
end

T["languages: A disabled facet needs a reason"] = MiniTest.new_set()

T["languages: A disabled facet needs a reason"]["rejects an empty reason"] = function()
	register_base_facets()
	child.lua([[Registry.all()[1].references = { disabled = "" }]])

	eq(
		validation_error():match("languages: css facet references has no disabled reason"),
		"languages: css facet references has no disabled reason"
	)
end

T["languages: A disabled facet needs a reason"]["reports validator errors"] = function()
	register_base_facets()
	child.lua([[
		Registry.register_facet("references", function(_, language)
			return language.name == "css" and "references validator rejected css" or nil
		end)
		Registry.all()[1].references = {}
	]])

	eq(validation_error():match("references validator rejected css"), "references validator rejected css")
end

T["languages: A new facet must be answered by every language"] = function()
	register_base_facets()
	child.lua([[Registry.register_facet("testing", function() end)]])

	eq(validation_error():match("languages: css lacks facet testing"), "languages: css lacks facet testing")

	child.lua([[
		for _, language in ipairs(Registry.all()) do
			language.testing = { adapter = "none" }
		end
	]])
	eq(child.lua_get([[pcall(Registry.validate)]]), true)
	eq(child.lua_get([[#Registry.facet("testing")]]), 11)
end

return T
