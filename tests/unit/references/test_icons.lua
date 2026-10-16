local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_bare()
end)

T["references: Icons and label shades match the palette"] = function()
	local actual = child.lua_get([[
		require("gleb.references.icons").label_color("#000000", "#646464")
	]])

	eq(actual, "#464646")
end

return T
