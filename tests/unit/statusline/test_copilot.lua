local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

T["statusline: copilot glyph hidden before load"] = function()
	eq(child.lua_get([[require("gleb.statusline.copilot").component()]]), "")
	eq(child.lua_get([[package.loaded["copilot.client"] == nil]]), true)
end

return T
