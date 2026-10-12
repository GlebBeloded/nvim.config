-- GUI layer (opt-in, `make e2e-gui`, never in `make check`): a dedicated real
-- Alacritty window with the user's Alacritty config runs zellij (user keybinds)
-- and Neovim (real config). Keys are real macOS key events from System Events,
-- so this needs Accessibility permission for the calling terminal and steals
-- focus while it runs. Only this layer covers Alacritty's own key encoding.
local MiniTest = require("mini.test")
local C = require("tests.shortcuts.chain")
local S = require("tests.shortcuts.stack")

local eq = MiniTest.expect.equality

-- key code 36 = Return (System Events)
local PRESSES = {
	{ shortcut = "Cmd+G", key = { char = "g", mods = { "command" } } },
	{ shortcut = "Cmd+L", key = { char = "l", mods = { "command" } } },
	{ shortcut = "Shift+Return", key = { code = 36, mods = { "shift" } } },
	{ shortcut = "Ctrl+Return", key = { code = 36, mods = { "control" } } },
}

---@type shortcuts.Stack?
local stack

local T = MiniTest.new_set({
	hooks = {
		pre_once = function()
			stack = S.start({ gui = true })
		end,
		post_once = function()
			if stack then
				stack:stop()
				stack = nil
			end
		end,
	},
})

---@param shortcut string
---@return string
local function receives(shortcut)
	for _, row in ipairs(C.shortcut_rows()) do
		if row.shortcut == shortcut then
			return assert(row.receives, shortcut .. " reaches no Neovim key")
		end
	end
	error("no shortcut table row " .. shortcut)
end

T["shortcuts: Physical shortcuts reach their Neovim key in Alacritty"] = function()
	local s = assert(stack, "stack not started")
	local expected = vim.tbl_map(function(press)
		return receives(press.shortcut)
	end, PRESSES)
	s:record(expected)
	local got = {}
	for _, press in ipairs(PRESSES) do
		s:clear_hits()
		s:press(press.key)
		pcall(S.wait_for, function()
			return #s:hits() > 0
		end, press.shortcut, 2000)
		table.insert(got, table.concat(s:hits(), " "))
	end
	eq(got, expected)
end

return T
