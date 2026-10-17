local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		local function line_range(fragment)
			return { start1 = fragment.start1, end1 = fragment.end1, start2 = fragment.start2, end2 = fragment.end2 }
		end

		function CompareFragments(lines1, lines2, policy)
			local fragments = require("gleb.diff.engine").compare_lines(lines1, lines2, { policy = policy }).fragments
			return vim.tbl_map(line_range, fragments)
		end
	]])
end

local T = H.child_set(child, start)

T["diff: Trim and ignore policies differ on inner spaces"] = function()
	local result = child.lua_get([[
		(function()
			local lines1 = { "x y", "x y", "x y" }
			local lines2 = { "  x y  ", "x y  ", "x   y" }
			return {
				default = CompareFragments(lines1, lines2, "default"),
				trim = CompareFragments(lines1, lines2, "trim_whitespaces"),
				ignore = CompareFragments(lines1, lines2, "ignore_whitespaces"),
			}
		end)()
	]])
	eq(result, {
		default = { { start1 = 0, end1 = 3, start2 = 0, end2 = 3 } },
		trim = { { start1 = 2, end1 = 3, start2 = 2, end2 = 3 } },
		ignore = {},
	})
end

T["diff: Trailing whitespace line under trim"] = function()
	local result = child.lua_get([[
		{
			default = CompareFragments({ "x", "" }, { "x " }, "default"),
			trim = CompareFragments({ "x", "" }, { "x " }, "trim_whitespaces"),
		}
	]])
	eq(result, {
		default = { { start1 = 0, end1 = 2, start2 = 0, end2 = 1 } },
		trim = { { start1 = 1, end1 = 2, start2 = 1, end2 = 1 } },
	})
end

T["diff: Empty lines count unless chunks are ignored"] = function()
	local result = child.lua_get([[
		{
			ignore = CompareFragments({ "", "", "z", "", "" }, { "z" }, "ignore_whitespaces"),
			chunks = CompareFragments({ "", "", "z", "", "" }, { "z" }, "ignore_whitespaces_chunks"),
		}
	]])
	eq(result, {
		ignore = {
			{ start1 = 0, end1 = 2, start2 = 0, end2 = 0 },
			{ start1 = 3, end1 = 5, start2 = 1, end2 = 1 },
		},
		chunks = {},
	})
end

T["diff: Carriage return is not whitespace"] = function()
	eq(child.lua_get([[CompareFragments({ "a\r" }, { "a" }, "ignore_whitespaces")]]), {
		{ start1 = 0, end1 = 1, start2 = 0, end2 = 1 },
	})
end

return T
