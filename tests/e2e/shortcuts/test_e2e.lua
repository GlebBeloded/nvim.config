-- E2E layer: real Alacritty (repo config) -> real zellij -> Neovim (real
-- config), real macOS key events (tests/e2e/alacritty.lua). Skipped with a
-- one-line fix when Accessibility is not granted, and (unless E2E=1) when key
-- events only arrive with the window focused. Runs inside the sandbox VM only
-- (make e2e delegates there); fails when the VM lacks the app-menu key setup.
-- Quitting chords run in their own cases; pre_case relaunches the stack when a
-- case left it dead.
local MiniTest = require("mini.test")
local C = require("tests.shortcuts.chain")
local E = require("tests.e2e.alacritty")
local H = require("tests.helpers")
local MenuKeys = require("tests.e2e.shortcuts.menu_keys")
local S = require("tests.shortcuts.stack")

local eq = MiniTest.expect.equality
local NEOVIM_PANE, CAT_PANE = "terminal_0", "terminal_1"
local CONSUMED = { "Cmd+J", "Cmd+K", "Cmd+[", "Cmd+]" }
local SETTLE_MS = 300
local CMD_CHORDS = { "Cmd+O", "Cmd+I", "Cmd+D", "Cmd+A" }
-- what each Cmd chord could wrongly arrive as: the Super key, an Alt key, the plain letter
local CMD_CHORD_RECORDERS =
	{ "<D-o>", "<D-i>", "<D-d>", "<D-a>", "<M-o>", "<M-i>", "<M-d>", "<M-a>", "o", "i", "d", "a" }
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
	stack, skipped = E.start_or_skip()
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

---@param fn fun(stack: e2e.Stack)
local function with_menu_keys_absent(fn)
	MenuKeys.with_absent({
		preflight = E.preflight,
		skip = function()
			MiniTest.skip("SKIPPED (reason on the first line)")
		end,
		stop = stop,
		start = E.start,
		run = S.run,
		root = H.root,
		set_stack = function(restored)
			stack = restored
		end,
	}, fn)
end

T["shortcuts: Every passed shortcut reaches its Neovim key from a real key press"] = function()
	local denied = E.denied(vim.tbl_map(function(r)
		return E.chord(r.shortcut)
	end, C.shortcut_rows()))
	local s, rows =
		get(), vim.tbl_filter(function(r)
			return r.receives ~= nil and not denied[E.chord(r.shortcut)]
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

T["shortcuts: Cmd+H never reaches Neovim from a real key press"] = function()
	with_menu_keys_absent(function(s)
		s:lua([[vim.cmd("vsplit | wincmd l")]])
		local right = s:lua("return vim.api.nvim_get_current_win()")
		E.record(s, { "<C-H>" })
		E.burst(s, function()
			E.press(s, "cmd+h")
			E.wait_hits(1, SETTLE_MS)
		end)
		eq(E.events, {})
		eq(s:lua("return vim.api.nvim_get_current_win()"), right)
		eq(E.hidden(s), true)
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

-- two top-level Lua functions: one fold each, starting at these lines
local FOLD_LINES = { 1, 6 }
local FOLD_FIXTURE = {
	"local function first()",
	"\tlocal a = 1",
	"\treturn a",
	"end",
	"",
	"local function second()",
	"\tlocal b = 2",
	"\treturn b",
	"end",
}

--- Open the fold fixture in a scratch buffer, wait for ufo's folds, open them all.
---@param s e2e.Stack
local function open_fold_fixture(s)
	s:lua(
		[[vim.cmd.enew()
		vim.bo.buftype, vim.bo.bufhidden = "nofile", "wipe"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, ...)
		vim.bo.filetype = "lua"]],
		{ FOLD_FIXTURE }
	)
	for _, lnum in ipairs(FOLD_LINES) do
		wait_nvim(string.format("vim.fn.foldlevel(%d) > 0", lnum), "a fold at line " .. lnum)
	end
	s:lua([[vim.cmd("normal! zR")]])
end

--- Wait until every fixture fold is closed (or, with `closed` false, open).
---@param closed boolean
local function wait_folds_closed(closed)
	local op = closed and "~=" or "=="
	for _, lnum in ipairs(FOLD_LINES) do
		wait_nvim(
			string.format("vim.fn.foldclosed(%d) %s -1", lnum, op),
			string.format("fold at line %d %s", lnum, closed and "closed" or "open")
		)
	end
end

T["shortcuts: Cmd+Shift+- and Cmd+Shift+= close and open all folds from a real key press"] = function()
	local s = get()
	open_fold_fixture(s)
	wait_folds_closed(false)
	burst(function()
		E.press(s, E.chord("Cmd+Shift+-"))
		wait_folds_closed(true)
		E.press(s, E.chord("Cmd+Shift+="))
		wait_folds_closed(false)
	end)
end

T["shortcuts: Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press"] = function()
	local s, hits = get(), {}
	E.record(s, CMD_CHORD_RECORDERS)
	burst(function()
		for _, shortcut in ipairs(CMD_CHORDS) do
			vim.list_extend(hits, press_and_record(shortcut))
		end
	end)
	eq(hits, { "<D-o>", "<D-i>", "<D-d>", "<D-a>" })
	eq(E.alive(s), true)
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
	E.burst(s, function()
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

T["shortcuts: Cmd+Q quits Alacritty from a real key press"] = function()
	with_menu_keys_absent(function(s)
		press_until_exit(s, "cmd+q")
		eq(E.alive(s), false)
	end)
end

return T
