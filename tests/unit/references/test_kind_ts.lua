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

T["references: Without kinds or a parser a usage is other"] = function()
	local actual = child.lua_get([[(function()
		return require("gleb.references.kind_ts").classify("value", "text", {
			{ line = 0, character = 0 },
		})
	end)()]])

	eq(actual, { "other" })
end

return T
