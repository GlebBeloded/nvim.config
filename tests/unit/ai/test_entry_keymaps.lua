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

-- Records the chunks passed to nvim_echo, to check the menu's highlight group.
local RECORD_ECHO = [[
	Echoed = {}
	local echo = vim.api.nvim_echo
	vim.api.nvim_echo = function(chunks, ...)
		vim.list_extend(Echoed, chunks)
		return echo(chunks, ...)
	end
]]

local function start()
	child.start_bare()
	child.lua(STUB_99)
end

---@param action string
local function expect_prompt(action)
	child.wait([[vim.fn.mode() == "i"]])
	eq(child.lua_get("Opened"), action)
	eq(child.bo.filetype, "99")
	eq(child.fn.mode(), "i")
end

local T = H.child_set(child, start)

T["ai: Menu shows prompt"] = function()
	child.lua(RECORD_ECHO)
	child.type_keys("<A-9>")
	local message = H.screen_rows(child, -1).text[1]
	child.type_keys("<Esc>")

	eq(vim.trim(table.concat(message)), "99> [s]earch [v]ibe:")
	eq(child.lua_get("Echoed"), { { "99> [s]earch [v]ibe: ", "Question" } })
	eq(child.lua_get("Opened"), vim.NIL)
end

T["ai: Menu s opens search prompt"] = function()
	child.type_keys("<A-9>", "s")
	expect_prompt("search")
end

T["ai: Menu v opens vibe prompt"] = function()
	child.type_keys("<A-9>", "v")
	expect_prompt("vibe")
end

T["ai: Menu ignores other keys"] = function()
	child.type_keys("<A-9>", "x")

	eq(child.lua_get("Opened"), vim.NIL)
	eq(child.bo.filetype, "")
	eq(child.fn.mode(), "n")
end

T["ai: Shift-Enter opens vibe prompt"] = function()
	child.type_keys("<S-CR>")
	expect_prompt("vibe")
end

T["ai: Visual Alt-9 opens visual prompt"] = function()
	child.type_keys("V", "<A-9>")
	expect_prompt("visual")
end

T["ai: Visual Shift-Enter opens visual prompt"] = function()
	child.type_keys("V", "<S-CR>")
	expect_prompt("visual")
end

T["ai: Entry mappings are silent"] = function()
	eq(child.lua_get([[vim.fn.maparg("<A-9>", "n", false, true).silent]]), 1)
	eq(child.lua_get([[vim.fn.maparg("<S-CR>", "n", false, true).silent]]), 1)
	eq(child.lua_get([[vim.fn.maparg("<A-9>", "v", false, true).silent]]), 1)
	eq(child.lua_get([[vim.fn.maparg("<S-CR>", "v", false, true).silent]]), 1)
end

return T
