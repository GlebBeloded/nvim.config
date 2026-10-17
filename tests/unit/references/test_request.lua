local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_bare()
end)

T["references: Two attached clients list each usage once"] = function()
	local actual = child.lua_get([[(function()
		local request = require("gleb.references.request")
		local first = {
			uri = "file:///repo/src/price.ts",
			range = {
				start = { line = 4, character = 2 },
				["end"] = { line = 4, character = 7 },
			},
		}
		local second = {
			uri = "file:///repo/src/price.ts",
			range = {
				start = { line = 4, character = 2 },
				["end"] = { line = 4, character = 12 },
			},
		}
		return request.merge({ { first, second }, { vim.deepcopy(first), vim.deepcopy(second) } })
	end)()]])

	eq(actual, {
		{
			uri = "file:///repo/src/price.ts",
			range = {
				start = { line = 4, character = 2 },
				["end"] = { line = 4, character = 7 },
			},
		},
		{
			uri = "file:///repo/src/price.ts",
			range = {
				start = { line = 4, character = 2 },
				["end"] = { line = 4, character = 12 },
			},
		},
	})
end

return T
