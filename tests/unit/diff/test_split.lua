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

T["diff: Split mode keeps unrelated lines apart"] = function()
	eq(
		child.lua_get([[
		CompareLines({ "x", "y" }, { "a", "b y" }, { highlight = "by_word_split" }).fragments
	]]),
		{
			{ start1 = 0, end1 = 1, start2 = 0, end2 = 1, inner = { { start1 = 0, end1 = 1, start2 = 0, end2 = 1 } } },
			{ start1 = 1, end1 = 2, start2 = 1, end2 = 2, inner = { { start1 = 0, end1 = 0, start2 = 0, end2 = 2 } } },
		}
	)
	eq(
		child.lua_get([[
		CompareLines({ "x", "y" }, { "a", "b y" }, { highlight = "by_word" }).fragments
	]]),
		{
			{
				start1 = 0,
				end1 = 2,
				start2 = 0,
				end2 = 2,
				inner = {
					{ start1 = 0, end1 = 1, start2 = 0, end2 = 1 },
					{ start1 = 2, end1 = 2, start2 = 2, end2 = 4 },
				},
			},
		}
	)
end

T["diff: Char mode marks single characters"] = function()
	eq(child.lua_get([[CompareLines({ "x y z" }, { "x  z" }, { highlight = "by_char" }).fragments]]), {
		{
			start1 = 0,
			end1 = 1,
			start2 = 0,
			end2 = 1,
			inner = { { start1 = 2, end1 = 3, start2 = 2, end2 = 2 } },
		},
	})
end

return T
