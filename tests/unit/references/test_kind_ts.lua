local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
end)

T["references: Treesitter fallback classifies writes where a parser exists"] = MiniTest.new_set()

T["references: Treesitter fallback classifies writes where a parser exists"]["Go declarations and increments"] = function()
	child.lua([[
		_G.go_fallback_kinds = nil
		local source = "x := 1\nx++\nprint(x)"
		local path = vim.fn.tempname() .. ".go"
		vim.fn.writefile(vim.split(source, "\n", { plain = true }), path)
		local uri = vim.uri_from_fname(path)
		local usages = vim.tbl_map(function(position)
			return {
				uri = uri,
				path = path,
				lnum = position.line + 1,
				col = position.character + 1,
				filetype = "go",
				range = { start = position, ["end"] = position },
			}
		end, {
			{ line = 0, character = 0 },
			{ line = 1, character = 0 },
			{ line = 2, character = 6 },
		})
		require("gleb.references.kind").classify(usages, function(classified)
			_G.go_fallback_kinds = vim.tbl_map(function(usage) return usage.kind end, classified)
		end)
	]])
	eq(child.wait([[type(_G.go_fallback_kinds) == "table"]]), true)

	eq(child.lua_get("_G.go_fallback_kinds"), { "write", "write", "read" })
end

T["references: Treesitter fallback classifies writes where a parser exists"]["Lua assignments"] = function()
	local actual = child.lua_get([[(function()
		local source = "x = 1\nprint(x)"
		return require("gleb.references.kind_ts").classify(source, "lua", {
			{ line = 0, character = 0 },
			{ line = 1, character = 6 },
		})
	end)()]])

	eq(actual, { "write", "read" })
end

T["references: Treesitter fallback classifies writes where a parser exists"]["Bash assignments"] = function()
	local actual = child.lua_get([[(function()
		local source = "x=1\necho \"$x\""
		return require("gleb.references.kind_ts").classify(source, "bash", {
			{ line = 0, character = 0 },
			{ line = 1, character = 7 },
		})
	end)()]])

	eq(actual, { "write", "read" })
end

T["references: Treesitter fallback classifies writes where a parser exists"]["Bash filetype resolves parser language"] = function()
	local path = child.fn.tempname() .. ".sh"
	child.fn.writefile({ "x=1" }, path)
	child.lua(
		[[
		local path = ...
		_G.bash_usage_kind = nil
		require("gleb.references.kind").classify({ {
			uri = vim.uri_from_fname(path),
			path = path,
			lnum = 1,
			col = 1,
			filetype = vim.filetype.match({ filename = path }),
		} }, function(usages)
			_G.bash_usage_kind = usages[1].kind
		end)
	]],
		{ path }
	)
	eq(child.wait("_G.bash_usage_kind ~= nil", 1000), true)

	eq(child.lua_get("_G.bash_usage_kind"), "write")
end

T["references: HCL fallback classifies variable labels and traversals"] = function()
	local actual = child.lua_get([[(function()
		local loaded, reason = vim.treesitter.language.add("hcl")
		assert(loaded, reason or "hcl parser is not installed")
		local source = 'variable "region" {}\nvalue = var.region'
		return require("gleb.references.kind_ts").classify(source, "hcl", {
			{ line = 0, character = 10 },
			{ line = 1, character = 12 },
		})
	end)()]])

	eq(actual, { "write", "read" })
end

T["references: Without kinds or a parser a usage is other"] = function()
	local actual = child.lua_get([[(function()
		return require("gleb.references.kind_ts").classify("value", "text", {
			{ line = 0, character = 0 },
		})
	end)()]])

	eq(actual, { "unclassified" })
end

T["references: TSX and TypeScript buffers use their own parser"] = function()
	local actual = child.lua_get([[(function()
		local classify = require("gleb.references.kind_ts").classify
		return {
			classify("const price = <Price value={new Money(1)} />;", "typescriptreact", {
				{ line = 0, character = 32 },
			})[1],
			classify("const m = <Money>raw;", "typescript", {
				{ line = 0, character = 11 },
			})[1],
		}
	end)()]])

	eq(actual, { "new", "cast" })
end

local python_call_scenario = "references: A Python call of a class is a new instance creation"
T[python_call_scenario] = MiniTest.new_set()
T[python_call_scenario]["refines a class call but keeps an unknown-target call"] = function()
	local actual = child.lua_get([[(function()
		local source = "local: Thing = Thing(key)"
		local position = { { line = 0, character = 15 } }
		local query_kind = require("gleb.references.kind_ts").classify(source, "python", position)[1]
		local refine = require("gleb.references.kind_refine").refine_query_kind
		return {
			refine(query_kind, "type", "python"),
			refine(query_kind, "unknown", "python"),
		}
	end)()]])

	eq(actual, { "new", "call" })
end

return T
