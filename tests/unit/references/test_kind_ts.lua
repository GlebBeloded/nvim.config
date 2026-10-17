local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
end)

T["references: Treesitter fallback classifies writes where a parser exists"] = MiniTest.new_set()

T["references: Treesitter fallback classifies writes where a parser exists"]["Go declarations and increments"] = function()
	local actual = child.lua_get([[(function()
		local source = "x := 1\nx++\nprint(x)"
		return require("gleb.references.kind_ts").classify(source, "go", {
			{ line = 0, character = 0 },
			{ line = 1, character = 0 },
			{ line = 2, character = 6 },
		})
	end)()]])

	eq(actual, { "write", "write", "read" })
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
	local path = child.fn.tempname() .. ".tf"
	child.fn.writefile({ 'variable "region" {}', "value = var.region" }, path)
	child.lua(
		[[
		local path = ...
		_G.hcl_usage_kinds = nil
		local original_add = vim.treesitter.language.add
		local original_parse = vim.treesitter.query.parse
		local original_get_parser = vim.treesitter.get_string_parser
		local original_get_clients = vim.lsp.get_clients
		vim.lsp.get_clients = function()
			return {}
		end
		vim.treesitter.language.add = function(language)
			if language == "hcl" then
				return true
			end
			return original_add(language)
		end
		vim.treesitter.query.parse = function(language, query_text)
			if language ~= "hcl" then
				return original_parse(language, query_text)
			end
			assert(query_text:find("(block", 1, true))
			assert(query_text:find("(get_attr", 1, true))
			local nodes = {
				{ range = function() return 0, 10, 0, 16 end },
				{ range = function() return 1, 12, 1, 18 end },
			}
			return {
				captures = { "write", "read" },
				iter_captures = function()
					local index = 0
					return function()
						index = index + 1
						if nodes[index] then
							return index, nodes[index]
						end
					end
				end,
			}
		end
		vim.treesitter.get_string_parser = function(_, language)
			if language ~= "hcl" then
				return original_get_parser(_, language)
			end
			return {
				parse = function()
					return { { root = function() return {} end } }
				end,
			}
		end
		local uri = vim.uri_from_fname(path)
		require("gleb.references.kind").classify({
			{ uri = uri, path = path, lnum = 1, col = 11, filetype = "terraform" },
			{ uri = uri, path = path, lnum = 2, col = 13, filetype = "terraform" },
		}, function(usages)
			_G.hcl_usage_kinds = vim.tbl_map(function(usage)
				return usage.kind
			end, usages)
			vim.treesitter.language.add = original_add
			vim.treesitter.query.parse = original_parse
			vim.treesitter.get_string_parser = original_get_parser
			vim.lsp.get_clients = original_get_clients
		end)
	]],
		{ path }
	)
	eq(child.wait("_G.hcl_usage_kinds ~= nil", 1000), true)

	eq(child.lua_get("_G.hcl_usage_kinds"), { "write", "read" })
end

T["references: Without kinds or a parser a usage is other"] = function()
	local actual = child.lua_get([[(function()
		return require("gleb.references.kind_ts").classify("value", "text", {
			{ line = 0, character = 0 },
		})
	end)()]])

	eq(actual, { "other" })
end

return T
