-- E2E layer: real Alacritty (repo config) -> real zellij -> Neovim (real
-- config), real macOS key events (tests/e2e/alacritty.lua). Skipped with a
-- one-line fix when Accessibility is not granted, and (unless E2E=1) when key
-- events only arrive with the window focused. Runs inside the sandbox VM only
-- (make e2e delegates there); fails when the VM lacks the app-menu key setup
-- (make sandbox-provision). Quitting chords (Ctrl+Q, Cmd+Option+Control+Q) run
-- in their own last cases; pre_case relaunches the stack when a case left it dead.
local MiniTest = require("mini.test")
local C = require("tests.shortcuts.chain")
local E = require("tests.e2e.alacritty")
local S = require("tests.shortcuts.stack")

local eq = MiniTest.expect.equality
local NEOVIM_PANE, CAT_PANE = "terminal_0", "terminal_1"
local CONSUMED = { "Cmd+J", "Cmd+K", "Cmd+[", "Cmd+]" }
local SETTLE_MS = 300
-- rows that behave unlike the shortcut table from a real key press, each in its own case:
-- Alacritty's chars bindings for Cmd+Shift+-/= never match, so its kitty encoding arrives
-- (spec: "Real key presses ...")
local OWN_CASE = { ["Cmd+Shift+-"] = true, ["Cmd+Shift+="] = true }

---@type e2e.Stack?
local stack
---@type string?
local skipped
---@type string? preflight failure: the VM is set up wrong
local broken

---@return e2e.Stack
local function get()
	if broken then
		error("e2e: " .. broken, 0)
	end
	if skipped then
		MiniTest.skip("SKIPPED (reason on the first line)")
	end
	return assert(stack, "e2e stack not started")
end

local function start()
	local reason, fatal = E.preflight()
	if fatal then
		broken = reason
		io.write("\ne2e: FAILED: " .. reason .. "\n")
		return
	end
	skipped = reason
	if not skipped then
		stack = E.start()
		if not stack.background and vim.env.E2E ~= "1" then
			skipped = "key events need the window focused; that runs only with E2E=1 (make e2e, the loop's gate)"
			stack:stop()
			stack = nil
		end
	end
	if skipped then
		io.write("\ne2e: SKIPPED: " .. skipped .. "\n")
	end
end

local function stop()
	if stack then
		stack:stop()
		stack = nil
	end
end

--- A live stack: the running one, or a fresh one when the last case killed it.
---@return e2e.Stack
local function ensure_alive()
	local s = get()
	if not E.alive(s) then
		s:stop()
		stack = E.start()
		s = stack
	end
	return s
end

--- Real mappings, one Neovim window, zellij focus on Neovim, normal mode.
local function reset()
	if skipped or broken then
		return
	end
	local s = ensure_alive()
	s:restore()
	s:lua([[vim.cmd("stopinsert | silent! only")]])
	if s:focused_pane() ~= NEOVIM_PANE then
		s:zellij("focus-pane-id", NEOVIM_PANE)
	end
	S.wait_for(function()
		return s:focused_pane() == NEOVIM_PANE
	end, "focus on the Neovim pane")
end

local T = MiniTest.new_set({ hooks = { pre_once = start, pre_case = reset, post_once = stop } })

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

--- Press a shortcut and wait until a recorder fires (at most E.NO_HIT_MS);
--- return the recorded keys.
---@param shortcut string
---@return string[]
local function press_and_record(shortcut)
	local s = get()
	E.clear(s)
	E.press(s, E.chord(shortcut))
	if #E.wait_hits(1, E.NO_HIT_MS, s) > 0 then
		E.wait_hits(2, 30, s) -- a second (wrong) key would land now
	end
	E.check_alive(s, "pressing " .. shortcut) -- a quit takes a moment
	return vim.deepcopy(E.events)
end

---@param expr string Lua expression evaluated in Neovim
---@param what string
local function wait_nvim(expr, what)
	S.wait_for(function()
		return get():lua("return " .. expr)
	end, what, 3000)
end

---@param pane string
---@param what string
local function wait_pane(pane, what)
	S.wait_for(function()
		return get():focused_pane() == pane
	end, what, 3000)
end

---@param fn fun()
local function burst(fn)
	E.burst(get(), fn)
end

T["shortcuts: Every passed shortcut reaches its Neovim key from a real key press"] = function()
	local denied = E.denied(vim.tbl_map(function(r)
		return E.chord(r.shortcut)
	end, C.shortcut_rows()))
	local s, rows =
		get(), vim.tbl_filter(function(r)
			return r.receives ~= nil and not OWN_CASE[r.shortcut] and not denied[E.chord(r.shortcut)]
		end, C.shortcut_rows())
	E.record(
		s,
		vim.tbl_map(function(r)
			return r.receives
		end, rows)
	)
	local problems = {}
	burst(function()
		for _, r in ipairs(rows) do
			local hits = press_and_record(r.shortcut)
			if not vim.deep_equal(hits, { r.receives }) then
				local got = #hits > 0 and table.concat(hits, " ") or "nothing"
				table.insert(problems, string.format("%-20s expected %s, got %s", r.shortcut, r.receives, got))
			end
		end
	end)
	if #problems > 0 then
		error(table.concat(problems, "\n"), 0)
	end
end

T["shortcuts: Consumed shortcuts never reach Neovim from a real key press"] = function()
	local s = get()
	E.record(
		s,
		vim.tbl_map(function(physical)
			return C.decode(row(physical).bytes).nvim
		end, CONSUMED)
	)
	burst(function()
		for _, physical in ipairs(CONSUMED) do
			E.press(s, E.chord(physical))
			vim.wait(100)
		end
		E.wait_hits(1, SETTLE_MS)
	end)
	eq(E.events, {})
	eq(s:focused_pane(), NEOVIM_PANE)
end

T["shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press"] = function()
	local s, hits = get(), {}
	E.record(s, { "<C-CR>", "<CR>" })
	burst(function()
		hits = press_and_record("Ctrl+Return")
	end)
	eq(hits, { "<C-CR>" })
end

T["shortcuts: Cmd+Q reaches Neovim as <M-q> from a real key press"] = function()
	local s, hits = get(), {}
	E.record(s, { "<M-q>" })
	burst(function()
		hits = press_and_record("Cmd+Q")
	end)
	eq(hits, { "<M-q>" })
	eq(E.alive(s), true)
	eq(E.hidden(s), false)
end

T["shortcuts: Cmd+H moves to the left Neovim split from a real key press"] = function()
	local s = get()
	s:lua([[vim.cmd("vsplit | wincmd l")]])
	local left = s:lua("return vim.fn.win_getid(vim.fn.winnr('h'))")
	burst(function()
		E.press(s, "cmd+h")
		wait_nvim("vim.api.nvim_get_current_win() == " .. left, "the left Neovim split current")
	end)
	eq(s:focused_pane(), NEOVIM_PANE)
	eq(E.hidden(s), false)
end

T["shortcuts: Cmd+H in a non-Neovim pane moves zellij focus left from a real key press"] = function()
	local s = get()
	s:zellij("focus-pane-id", CAT_PANE)
	wait_pane(CAT_PANE, "focus on the cat pane")
	burst(function()
		E.press(s, "cmd+h")
		wait_pane(NEOVIM_PANE, "zellij focus on the Neovim pane")
	end)
end

T["shortcuts: Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press"] = function()
	local s, hits = get(), {}
	E.record(s, { "<S-D-->", "<S-D-=>", "<M-_>", "<M-+>" })
	burst(function()
		for _, shortcut in ipairs({ "Cmd+Shift+-", "Cmd+Shift+=" }) do
			vim.list_extend(hits, press_and_record(shortcut))
		end
	end)
	eq(hits, { "<S-D-->", "<S-D-=>" })
end

T["shortcuts: Ctrl+Up grows the current Neovim split from a real key press"] = function()
	local s = get()
	s:lua([[vim.cmd("split")]])
	local height = s:lua("return vim.api.nvim_win_get_height(0)")
	burst(function()
		E.press(s, "ctrl+up")
		wait_nvim("vim.api.nvim_win_get_height(0) == " .. (height + 2), "split 2 rows taller")
	end)
end

T["shortcuts: Cmd+L at the rightmost Neovim split moves zellij focus right from a real key press"] = function()
	local s = get()
	burst(function()
		E.press(s, "cmd+l")
		wait_pane(CAT_PANE, "zellij focus on the cat pane")
	end)
end

T["shortcuts: Ctrl+H in a non-Neovim pane moves zellij focus left from a real key press"] = function()
	local s = get()
	s:zellij("focus-pane-id", CAT_PANE)
	wait_pane(CAT_PANE, "focus on the cat pane")
	burst(function()
		E.press(s, "ctrl+h")
		wait_pane(NEOVIM_PANE, "zellij focus on the Neovim pane")
	end)
end

T["shortcuts: Cmd+Shift+Q is never pressed: the key helper refuses it"] = function()
	local result = S.run({ E.keys(), "press", "1", "cmd+shift+q" })
	eq(result.code, 2)
	eq(vim.trim(result.stderr or ""), "keys press: refused, cmd+shift+q is a denied system-wide chord")
end

--- Press a quitting chord; return once Alacritty has exited.
---@param s e2e.Stack
---@param chord string
local function press_until_exit(s, chord)
	local pid = assert(s.alacritty_pid, "Alacritty not running")
	burst(function()
		E.press(s, chord, true)
		S.wait_for(function()
			return vim.uv.kill(pid, 0) ~= 0
		end, "Alacritty to exit after " .. chord, 5000)
	end)
end

T["shortcuts: Ctrl+Q quits zellij and closes the Alacritty window"] = function()
	local s = get()
	press_until_exit(s, "ctrl+q")
	local sessions = S.run({ "zellij", "list-sessions", "--short", "--no-formatting" }, s.env)
	eq(vim.list_contains(vim.split(sessions.stdout or "", "\n"), s.session), false)
end

T["shortcuts: Cmd+Option+Control+Q quits Alacritty from a real key press"] = function()
	press_until_exit(get(), "cmd+ctrl+opt+q")
end

return T
