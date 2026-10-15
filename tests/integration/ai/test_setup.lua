local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

---@param lhs string
---@param mode? string defaults to "n"
---@return string?
local function map_desc(lhs, mode)
	return child.lua([[local lhs, mode = ...; return vim.fn.maparg(lhs, mode, false, true).desc]], { lhs, mode or "n" })
end

T["ai: Keymaps exist after VeryLazy"] = function()
	child.wait_very_lazy()

	eq({ map_desc("<A-9>"), map_desc("<S-CR>") }, { vim.NIL, "AI: Vibe" })
	eq({ map_desc("<A-9>", "v"), map_desc("<S-CR>", "v") }, { "AI: Edit Selection", "AI: Edit Selection" })
	eq(child.lua_get([[package.loaded["gleb.ai"] ~= nil]]), true)
end

return T
