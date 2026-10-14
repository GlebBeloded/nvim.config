local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		MiniPick = require("mini.pick")
		MiniPick.setup()
		require("gleb.select")
	]])
end

local T = H.child_set(child, start)

T["select: Selection accepts omitted options"] = function()
	child.lua_notify([[
		select_ok, select_error = pcall(vim.ui.select, { "x" }, nil, function() end)
	]])

	eq(child.wait("MiniPick.is_picker_active()"), true)
	child.type_keys("<Esc>")
	eq(child.wait("select_ok ~= nil"), true)
	eq({ child.lua_get("select_ok"), child.lua_get("select_error") }, { true, vim.NIL })
end

return T
