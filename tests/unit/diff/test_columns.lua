local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: Squashed word ranges map to buffer columns"] = function()
	local result = child.lua_get([[(function()
		local engine = require("gleb.diff.engine")
		local lines1 = { "keep", "a b", "c d" }
		local lines2 = { "keep", "a x", "c y" }
		local fragment = engine.compare_lines(lines1, lines2).fragments[1]
		return {
			fragment = fragment,
			columns1 = engine.inner_columns(fragment, 1, lines1),
			columns2 = engine.inner_columns(fragment, 2, lines2),
		}
	end)()]])
	eq(result.fragment, {
		start1 = 1,
		end1 = 3,
		start2 = 1,
		end2 = 3,
		inner = {
			{ start1 = 2, end1 = 3, start2 = 2, end2 = 3 },
			{ start1 = 6, end1 = 7, start2 = 6, end2 = 7 },
		},
	})
	local expected = {
		{ row = 1, col_start = 2, col_end = 3 },
		{ row = 2, col_start = 2, col_end = 3 },
	}
	eq(result.columns1, expected)
	eq(result.columns2, expected)
end

T["diff: A range across a newline splits per row"] = function()
	local result = child.lua_get([[(function()
		local engine = require("gleb.diff.engine")
		local fragment = {
			start1 = 0,
			end1 = 2,
			start2 = 0,
			end2 = 1,
			inner = { { start1 = 2, end1 = 5, start2 = 0, end2 = 0 } },
		}
		return {
			columns1 = engine.inner_columns(fragment, 1, { "a b", "c d" }),
			columns2 = engine.inner_columns(fragment, 2, { "x" }),
		}
	end)()]])
	eq(result.columns1, {
		{ row = 0, col_start = 2, col_end = 3 },
		{ row = 1, col_start = 0, col_end = 1 },
	})
	eq(result.columns2, { { row = 0, col_start = 0, col_end = 0 } })
end

return T
