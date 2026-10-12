local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

---@param lhs string
---@return string?
local function normal_desc(lhs)
	return child.lua_get([[vim.fn.maparg(..., "n", false, true).desc]], { lhs })
end

T["ai: Keymaps exist after VeryLazy"] = function()
	child.wait_very_lazy()

	eq({ normal_desc("<A-9>"), normal_desc("<S-CR>") }, { "99: Menu", "99: Vibe" })
end

return T
