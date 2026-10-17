local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[Registry = require("gleb.languages")]])
end

local T = H.child_set(child, start)

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

return T
