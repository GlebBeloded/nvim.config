local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: Patience takes over when Myers exceeds its threshold"] = function()
	local result = child.lua_get([[
		require("gleb.diff.engine").compare_lines(
			{ "alpha", "bravo", "charlie", "delta", "echo" },
			{ "echo", "bravo", "charlie", "delta", "alpha" },
			{ limits = { myers_threshold = 1 } }
		)
	]])
	eq(result, {
		fragments = {
			{ start1 = 0, end1 = 1, start2 = 0, end2 = 1 },
			{ start1 = 4, end1 = 5, start2 = 4, end2 = 5 },
		},
		too_big = false,
		timed_out = false,
	})
end

return T
