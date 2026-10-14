local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

-- Stub 99: each action records its name and opens a 99 prompt buffer.
local STUB_99 = [[
	local function action(name)
		return function()
			Opened = name
			vim.cmd("enew")
			vim.bo.filetype = "99"
		end
	end
	Stub = { search = action("search"), vibe = action("vibe"), visual = action("visual") }
	require("gleb.ai.entry_keymaps").setup(Stub)
]]

local function start()
	child.start_bare()
	child.lua(STUB_99)
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
