-- Stack layer: real zellij (user keybinds) in a tmux pty, real Neovim config in
-- the left pane, `cat` in the right one. Bytes are what Alacritty would send.
local MiniTest = require("mini.test")
local C = require("tests.shortcuts.chain")
local S = require("tests.shortcuts.stack")

local eq = MiniTest.expect.equality
local NEOVIM_PANE, CAT_PANE = "terminal_0", "terminal_1"
local CONSUMED = { "Cmd+J", "Cmd+K", "Cmd+[", "Cmd+]" }
local SETTLE_MS = 300
-- Gap between key presses, like a human. Bursts such as "\e[\e]" in one read
-- leave zellij's parser waiting and swallow the next CSI u key.
local KEY_GAP_MS = 100
local CMD_CHORDS = { "Cmd+O", "Cmd+I", "Cmd+D", "Cmd+A" }
-- what each Cmd chord could wrongly arrive as: the Super key, an Alt key, the plain letter
local CMD_CHORD_RECORDERS =
	{ "<D-o>", "<D-i>", "<D-d>", "<D-a>", "<M-o>", "<M-i>", "<M-d>", "<M-a>", "o", "i", "d", "a" }

---@type shortcuts.Stack?
local stack

---@return shortcuts.Stack
local function get()
	return assert(stack, "stack not started")
end

--- Real mappings, one Neovim window, zellij focus on Neovim, normal mode.
local function reset()
	local s = get()
	s:restore()
	s:lua([[vim.cmd("stopinsert | silent! only")]])
	if s:focused_pane() ~= NEOVIM_PANE then
		s:zellij("focus-pane-id", NEOVIM_PANE)
	end
	S.wait_for(function()
		return s:focused_pane() == NEOVIM_PANE
	end, "focus on the Neovim pane")
end

local T = MiniTest.new_set({
	hooks = {
		pre_once = function()
			stack = S.start()
		end,
		pre_case = reset,
		post_once = function()
			if stack then
				stack:stop()
				stack = nil
			end
		end,
	},
})

---@param physical string
---@return shortcuts.Row
local function row(physical)
	for _, r in ipairs(C.shortcut_rows()) do
		if r.shortcut == physical then
			return r
		end
	end
	error("no shortcut table row " .. physical)
end

--- Send bytes and wait until a recorder fires; return the recorded keys.
---@param bytes string
---@return string[]
local function send_and_record(bytes)
	local s = get()
	s:clear_hits()
	s:send(bytes)
	pcall(S.wait_for, function()
		return #s:hits() > 0
	end, "recorder", 1500)
	vim.wait(30) -- a second (wrong) key would land now
	return s:hits()
end

---@param expr string Lua expression evaluated in Neovim
---@param what string
local function wait_nvim(expr, what)
	S.wait_for(function()
		return get():lua("return " .. expr)
	end, what, 3000)
end

T["shortcuts: Every passed shortcut reaches its Neovim key through zellij"] = function()
	local s, rows = get(), vim.tbl_filter(function(r)
		return r.receives ~= nil
	end, C.shortcut_rows())
	s:record(vim.tbl_map(function(r)
		return r.receives
	end, rows))
	local problems = {}
	for _, r in ipairs(rows) do
		local hits = send_and_record(r.bytes)
		if not vim.deep_equal(hits, { r.receives }) then
			local got = #hits > 0 and table.concat(hits, " ") or "nothing"
			table.insert(
				problems,
				string.format("%-20s %-12s expected %s, got %s", r.shortcut, C.escape(r.bytes), r.receives, got)
			)
		end
	end
	if #problems > 0 then
		error(table.concat(problems, "\n"), 0)
	end
end

T["shortcuts: Consumed shortcuts never reach Neovim"] = function()
	local s = get()
	local sent = vim.tbl_map(function(physical)
		return C.decode(row(physical).bytes).nvim
	end, CONSUMED)
	s:record(sent)
	for _, physical in ipairs(CONSUMED) do
		s:send(row(physical).bytes)
		vim.wait(KEY_GAP_MS)
	end
	vim.wait(SETTLE_MS)
	eq(s:hits(), {})
	eq(s:focused_pane(), NEOVIM_PANE)
end

T["shortcuts: Ctrl+Return reaches Neovim through the kitty keyboard protocol"] = function()
	local s, r = get(), row("Ctrl+Return")
	s:record({ "<C-CR>", "<CR>" })
	eq(r.bytes, "\27[13;5u")
	eq(send_and_record(r.bytes), { "<C-CR>" })
end

T["shortcuts: Cmd chords reach Neovim through real zellij"] = function()
	local s = get()
	s:record(CMD_CHORD_RECORDERS)
	for _, physical in ipairs(CMD_CHORDS) do
		s:send(row(physical).bytes)
		vim.wait(KEY_GAP_MS)
	end
	pcall(S.wait_for, function()
		return #s:hits() >= #CMD_CHORDS
	end, "recorders", 1500)
	vim.wait(SETTLE_MS)
	eq(s:hits(), { "<D-o>", "<D-i>", "<D-d>", "<D-a>" })
end

T["shortcuts: Cmd+Shift+A opens Find Action through real zellij"] = function()
	local s = get()
	s:send(row("Cmd+Shift+A").bytes)
	S.wait_for(function()
		return s:active_picker_name() == "Find Action"
	end, "Find Action palette", 3000)
	eq(s:active_picker_name(), "Find Action")
end

T["shortcuts: Cmd+H moves to the left Neovim split"] = function()
	local s = get()
	s:lua([[vim.cmd("vsplit | wincmd l")]])
	local left = s:lua("return vim.api.nvim_tabpage_list_wins(0)[1]")
	s:send(row("Cmd+H").bytes)
	wait_nvim("vim.api.nvim_get_current_win() == " .. left, "left window")
	eq(s:focused_pane(), NEOVIM_PANE)
end

T["shortcuts: Cmd+Shift+J moves to the Neovim split below"] = function()
	local s = get()
	s:lua([[vim.cmd("split | wincmd k")]])
	local bottom = s:lua("return vim.api.nvim_tabpage_list_wins(0)[2]")
	s:send(row("Cmd+Shift+J").bytes)
	wait_nvim("vim.api.nvim_get_current_win() == " .. bottom, "bottom window")
	eq(s:focused_pane(), NEOVIM_PANE)
end

T["shortcuts: Cmd+L at the rightmost Neovim split moves zellij focus right"] = function()
	local s = get()
	s:send(row("Cmd+L").bytes)
	S.wait_for(function()
		return s:focused_pane() == CAT_PANE
	end, "zellij focus on the cat pane", 3000)
end

T["shortcuts: Cmd+H in a non-Neovim pane moves zellij focus left"] = function()
	local s = get()
	s:zellij("focus-pane-id", CAT_PANE)
	S.wait_for(function()
		return s:focused_pane() == CAT_PANE
	end, "focus on the cat pane")
	s:send(row("Cmd+H").bytes)
	S.wait_for(function()
		return s:focused_pane() == NEOVIM_PANE
	end, "zellij focus on the Neovim pane", 3000)
end

return T
