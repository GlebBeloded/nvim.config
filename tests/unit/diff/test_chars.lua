local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		function CompareChars(text1, text2, opts)
			return require("gleb.diff.engine").compare_chars(text1, text2, opts)
		end
	]])
end

local T = H.child_set(child, start)

T["diff: An emoji change spans its whole character"] = function()
	eq(child.lua_get([[CompareChars("x😂y", "x🤫y")]]), {
		{ start1 = 1, end1 = 5, start2 = 1, end2 = 5 },
	})
end

return T
