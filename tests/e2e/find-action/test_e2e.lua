-- E2E workflow: real macOS keys drive Find Action through Alacritty and zellij,
-- including a shortcut saved to the sandbox checkout and loaded by a fresh stack.
local MiniTest = require("mini.test")
local E = require("tests.e2e.alacritty")
local S = require("tests.shortcuts.stack")
local approved_screens = require("tests.e2e.find-action.screens")

local STACK_OPTS = { layout = "nvim", columns = 100, lines = 30 }

---@type e2e.Stack?
local stack
---@type string?
local skipped

local function start()
	stack, skipped = E.start_or_skip(STACK_OPTS)
end

local function stop()
	if stack then
		stack:stop()
		stack = nil
	end
end

---@return e2e.Stack
local function get()
	if skipped then
		MiniTest.skip("SKIPPED (reason on the first line)")
	end
	return assert(stack, "e2e stack not started")
end

local T = MiniTest.new_set({ hooks = { pre_once = start, post_once = stop } })

local PALETTE_SCREENS = {
	["opened palette screen"] = true,
	["searched palette screen"] = true,
	["run action screen"] = true,
	["assigned shortcut screen"] = true,
	["persisted shortcut screen"] = true,
}

---@param s e2e.Stack
---@return string
local function screen(s)
	local result = s:action({ "dump-screen", "--pane-id", "terminal_0" })
	assert(result.code == 0, "could not capture Neovim screen: " .. vim.trim(result.stderr or ""))
	return result.stdout or ""
end

---@param s e2e.Stack
---@return table?
local function live_palette(s)
	return s:lua([[
		local pick = require("mini.pick")
		local items = assert(pick.get_picker_items(), "Find Action items are missing")
		local matches = assert(pick.get_picker_matches(), "Find Action matches are missing")
		local rows = {}
		local current = 0
		local total = 0
		for _, item in ipairs(items) do
			if not item.section then
				total = total + 1
			end
		end
		for _, index in ipairs(matches.all_inds) do
			local item = items[index]
			if not item.section then
				current = current + 1
			end
			table.insert(rows, {
				text = item.text,
				secondary = item.secondary,
				category = item.category,
				glyph = item.glyph,
				section = item.section or false,
			})
		end
		return { rows = rows, count = string.format("%d/%d", current, total) }
	]])
end

---@param s e2e.Stack
---@param title string
local function expect_screen(s, title)
	local palette = PALETTE_SCREENS[title] and live_palette(s) or nil
	local expected = approved_screens.build(title, palette)
	local captured
	local matched = vim.wait(3000, function()
		captured = screen(s)
		return captured == expected
	end, 50)
	assert(matched, title .. " did not match its approved render:\n" .. captured)
end

---@param s e2e.Stack
local function press(s, keys)
	E.burst(s, function()
		E.press(s, keys)
	end)
end

---@param s e2e.Stack
local function wait_palette(s)
	S.wait_for(function()
		return s:lua([[return require("mini.pick").is_picker_active()]])
	end, "Find Action palette", 3000)
end

T["find-action: Physical Find Action workflow persists an assignment"] = function()
	local s = get()
	s:lua([[vim.cmd("enew")]])
	press(s, "cmd+shift+a")
	wait_palette(s)
	expect_screen(s, "opened palette screen")

	press(s, { "f", "i", "n", "d" })
	expect_screen(s, "searched palette screen")
	press(s, "return")
	wait_palette(s)
	expect_screen(s, "run action screen")

	press(s, { "f", "i", "n", "d", "opt+return" })
	expect_screen(s, "shortcut capture screen")
	press(s, "cmd+d")
	expect_screen(s, "captured shortcut screen")
	press(s, "return")
	S.wait_for(function()
		return s:lua([[return vim.fn.maparg("<D-d>", "n") ~= ""]])
	end, "saved shortcut to apply", 3000)

	press(s, "escape")
	S.wait_for(function()
		return not s:lua([[return require("mini.pick").is_picker_active()]])
	end, "Find Action palette to close", 3000)
	press(s, "cmd+d")
	wait_palette(s)
	expect_screen(s, "assigned shortcut screen")

	stop()
	stack = E.start(STACK_OPTS)
	s = get()
	press(s, "cmd+d")
	wait_palette(s)
	expect_screen(s, "persisted shortcut screen")
end

return T
