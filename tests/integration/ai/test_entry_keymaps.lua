-- Entry mappings require the full config, so these cases belong to integration.
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

T["ai: Entry mappings are silent"] = function()
	eq(child.lua_get([[vim.tbl_isempty(vim.fn.maparg("<A-9>", "n", false, true))]]), true)
	eq(child.lua_get([[vim.fn.maparg("<S-CR>", "n", false, true).silent]]), 1)
	eq(child.lua_get([[vim.fn.maparg("<A-9>", "x", false, true).silent]]), 1)
	eq(child.lua_get([[vim.fn.maparg("<S-CR>", "x", false, true).silent]]), 1)
end

T["ai: Select mode keeps its default behavior"] = function()
	eq(child.lua_get([[vim.fn.maparg("<A-9>", "s")]]), "")
	eq(child.lua_get([[vim.fn.maparg("<S-CR>", "s")]]), "")
end

return T
