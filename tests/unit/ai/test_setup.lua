local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["ai: Missing 99 is tolerated"] = function()
	child.lua([[SetupOk = pcall(function() require("gleb.ai").setup() end)]])

	eq(child.lua_get("SetupOk"), true)
	eq(child.lua_get('package.loaded["gleb.ai.pi_provider"]'), vim.NIL)
	eq(child.lua_get('package.loaded["gleb.ai.prompt_keymaps"]'), vim.NIL)
	eq(child.lua_get('package.loaded["gleb.ai.entry_keymaps"]'), vim.NIL)
end

return T
