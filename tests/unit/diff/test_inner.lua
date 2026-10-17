local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		function CompareLines(lines1, lines2, opts)
			return require("gleb.diff.engine").compare_lines(lines1, lines2, opts)
		end
	]])
end

local T = H.child_set(child, start)

T["diff: Changed words inside a line"] = MiniTest.new_set()

T["diff: Changed words inside a line"]["default includes trailing whitespace"] = function()
	eq(child.lua_get([[CompareLines({ "x z " }, { "y z" }).fragments]]), {
		{
			start1 = 0,
			end1 = 1,
			start2 = 0,
			end2 = 1,
			inner = {
				{ start1 = 0, end1 = 1, start2 = 0, end2 = 1 },
				{ start1 = 3, end1 = 4, start2 = 3, end2 = 3 },
			},
		},
	})
end

T["diff: Changed words inside a line"]["trim ignores trailing whitespace"] = function()
	eq(child.lua_get([[CompareLines({ "x z " }, { "y z" }, { policy = "trim_whitespaces" }).fragments]]), {
		{
			start1 = 0,
			end1 = 1,
			start2 = 0,
			end2 = 1,
			inner = { { start1 = 0, end1 = 1, start2 = 0, end2 = 1 } },
		},
	})
end

T["diff: A deleted word leaves an insertion point"] = function()
	eq(child.lua_get([[CompareLines({ "x? y" }, { "x y" }).fragments[1].inner]]), {
		{ start1 = 1, end1 = 2, start2 = 1, end2 = 1 },
	})
end

T["diff: A pure insertion has no inner list"] = function()
	eq(child.lua_get([[CompareLines({ "z" }, { "z", "w" }).fragments]]), {
		{ start1 = 1, end1 = 1, start2 = 1, end2 = 2 },
	})
end

T["diff: A whitespace-only insertion has an empty inner list"] = MiniTest.new_set()

T["diff: A whitespace-only insertion has an empty inner list"]["ignore whitespace keeps an empty inner list"] = function()
	eq(
		child.lua_get([[
		CompareLines({ "z" }, { "z", " " }, { policy = "ignore_whitespaces" }).fragments
	]]),
		{
			{ start1 = 1, end1 = 1, start2 = 1, end2 = 2, inner = {} },
		}
	)
end

T["diff: A whitespace-only insertion has an empty inner list"]["chunk policy removes the fragment"] = function()
	eq(
		child.lua_get([[
		CompareLines({ "z" }, { "z", " " }, { policy = "ignore_whitespaces_chunks" }).fragments
	]]),
		{}
	)
end

T["diff: Line mode and no highlighting"] = function()
	eq(child.lua_get([[CompareLines({ "x z " }, { "y z" }, { highlight = "by_line" }).fragments]]), {
		{ start1 = 0, end1 = 1, start2 = 0, end2 = 1 },
	})
	eq(child.lua_get([[CompareLines({ "x z " }, { "y z" }, { highlight = "none" }).fragments]]), {})
end

return T
