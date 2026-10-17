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
			{ highlight = "by_line", limits = { myers_threshold = 1 } }
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

T["diff: Patience reduction uses original counts"] = function()
	local result = child.lua_get([[
		require("gleb.diff.engine").compare_lines(
			{
				"left line", "first anchor", "common line", "common line", "common line", "alpha line",
				"alpha line", "bravo line", "bravo line", "bravo line", "second anchor", "right line",
			},
			{
				"right line", "first anchor", "common line", "common line", "common line", "bravo line",
				"bravo line", "alpha line", "alpha line", "alpha line", "second anchor", "left line",
			},
			{ limits = { myers_threshold = 1 } }
		)
	]])
	eq(result.too_big, false)
	eq(result.timed_out, false)
end

T["diff: A too big comparison falls back to xdiff"] = function()
	local result = child.lua_get([[
		require("gleb.diff.engine").compare_lines(
			{ "alpha", "bravo", "alpha", "bravo" },
			{ "bravo", "bravo", "alpha", "alpha" },
			{ limits = { myers_threshold = 1 } }
		)
	]])
	eq(result, {
		fragments = {
			{ start1 = 0, end1 = 1, start2 = 0, end2 = 1 },
			{ start1 = 3, end1 = 4, start2 = 3, end2 = 4 },
		},
		too_big = true,
		timed_out = false,
	})
end

T["diff: A missed deadline falls back to xdiff"] = function()
	local result = child.lua_get([[(function()
		local calls = 0
		local function clock()
			calls = calls + 1
			return calls == 1 and 0 or 5000
		end
		return require("gleb.diff.engine").compare_lines(
			{ "alpha", "bravo" },
			{ "alpha", "charlie" },
			{ limits = { timeout_ms = 1000, clock = clock } }
		)
	end)()]])
	eq(result, {
		fragments = {
			{ start1 = 1, end1 = 2, start2 = 1, end2 = 2 },
		},
		too_big = false,
		timed_out = true,
	})
end

return T
