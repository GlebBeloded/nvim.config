local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- Bare child: none of the optional git plugins is on the runtimepath.
local function start()
	child.start_bare()
end

--- Child-side: require each module named in the arguments, return the errors.
local REQUIRE_ALL_LUA = [[
local errors = {}
for _, name in ipairs({ ... }) do
	local ok, err = pcall(require, name)
	if not ok then errors[name] = err end
end
return errors]]

local T = H.child_set(child, start)

T["git: Missing optional git plugins are tolerated"] = function()
	local modules = { "gleb.git.gitsigns", "gleb.git.diffview" }
	eq(child.lua(REQUIRE_ALL_LUA, modules), {})
end

return T
