-- E2E harness: a dedicated real Alacritty instance (the repo's
-- terminal/alacritty config) -> real zellij (user keybinds) -> Neovim with the
-- real config, driven by real macOS key events and observed over RPC.
--
-- Builds on tests/shortcuts/stack.lua (same zellij copy, layout, sandbox and
-- recorders); only the frontend differs: Alacritty instead of a tmux pty.
-- Key events come from tests/e2e/keys.swift: CGEventPostToPid to the Alacritty
-- pid. Alacritty is launched without activation (NSWorkspace, activates=false).
-- If events posted to the background window do not arrive (probed once per
-- start), every burst of key presses makes the window frontmost first and gives
-- focus back to the previous app afterwards. It only runs inside a VM (the
-- sandbox, tests/sandbox/sandbox.sh); keys refuses to post on the host.
--
-- Waits are event-driven: recorder mappings push each hit over RPC (on_hit).
-- Every press is followed by a liveness check; failures carry the startup
-- timeline, Alacritty's ERROR/WARN log lines and zellij's stderr.
--
-- Cleanup: stop() kills the window, the zellij session and the temp dir; a
-- detached watchdog does the same if the runner dies (timeout, SIGKILL).

local C = require("tests.shortcuts.chain")
local H = require("tests.helpers")
local S = require("tests.shortcuts.stack")

local M = {}

M.COLUMNS, M.LINES = 160, 45
local PROBE_KEY, PROBE_CHORD = "<M-b>", "cmd+b" -- passes zellij, no Neovim mapping
M.NO_HIT_MS = 300 -- how long a row waits for a key that never comes
-- chords whose keyDown CGEventPostToPid loses (Alacritty sees only the key-up);
-- posted at the HID tap with the window focused instead, as a keyboard would
M.HID = { ["ctrl+return"] = true }

---@type string[] keys the recorders pushed since the last clear (on_hit)
M.events = {}

--- Called by the recorder mappings in Neovim over RPC (tests/shortcuts/stack.lua).
---@param lhs string
function M.on_hit(lhs)
	table.insert(M.events, lhs)
end

---@class e2e.Stack: shortcuts.Stack
---@field alacritty_pid integer?
---@field watchdog vim.SystemObj?
---@field background boolean key events arrive without focusing the window
---@field focus_prev integer? app to give focus back to (while a burst runs)
---@field log string? Alacritty's persistent log ($TMPDIR/Alacritty-<pid>.log)

---@type string?
local keys_bin

--- Path of the key helper (built and cached by tests/e2e/build.sh).
---@return string
function M.keys()
	if not keys_bin then
		local result = S.run({ vim.fs.joinpath(H.root, "tests/e2e/build.sh") })
		assert(result.code == 0, "tests/e2e/build.sh failed: " .. (result.stderr or ""))
		keys_bin = vim.trim(result.stdout)
	end
	return keys_bin
end

--- Alacritty.app bundle: $E2E_ALACRITTY_APP, else the one `alacritty` resolves to.
---@return string?
function M.app()
	if vim.env.E2E_ALACRITTY_APP then
		return vim.env.E2E_ALACRITTY_APP
	end
	local exe = vim.fn.exepath("alacritty")
	local real = exe ~= "" and vim.uv.fs_realpath(exe) or "/Applications/Alacritty.app/Contents/MacOS/alacritty"
	return real and real:match("^(.*%.app)/Contents/MacOS/")
end

--- nil when e2e can run, else a one-line reason with the fix.
---@return string?
function M.preflight()
	if vim.env.E2E == "0" then
		return "E2E=0"
	end
	if vim.uv.os_uname().sysname ~= "Darwin" then
		return "e2e needs macOS"
	end
	if vim.trim(vim.fn.system({ "sysctl", "-n", "kern.hv_vmm_present" })) ~= "1" then
		return "e2e posts real key events, so it only runs inside the sandbox VM (host is never targeted)"
	end
	local app = M.app()
	if not app or not vim.uv.fs_stat(app) then
		return "no Alacritty.app found (brew install --cask alacritty, or set E2E_ALACRITTY_APP)"
	end
	local ok, err = pcall(M.keys)
	if not ok then
		return "cannot build the key helper: " .. tostring(err)
	end
	local result = S.run({ M.keys(), "trusted" })
	if result.code ~= 0 then
		local who = vim.trim(result.stdout or ""):gsub("^%S+%s*", "")
		return string.format(
			"Accessibility not granted to %s; fix: System Settings > Privacy & Security > Accessibility, enable it (restart it if e2e still skips)",
			who ~= "" and who or "the app running make"
		)
	end
end

---@param cmd string[]
---@return string stdout
local function keys(cmd)
	local result = S.run(vim.list_extend({ M.keys() }, cmd))
	assert(result.code == 0, "keys " .. cmd[1] .. " failed: " .. vim.trim(result.stderr or ""))
	return vim.trim(result.stdout)
end

---@param pid integer
---@return boolean
local function alive(pid)
	return vim.uv.kill(pid, 0) == 0
end

--- The repo's alacritty.toml with `~/.config/alacritty/` imports pointed at the
--- resolved config dir (the worktree's terminal/alacritty, not ~/.config).
---@param self e2e.Stack
---@return string path
local function write_alacritty_config(self)
	local root = C.configs().alacritty.root
	local lines = vim.tbl_map(function(line)
		return (line:gsub("~/%.config/alacritty/", root .. "/"))
	end, vim.fn.readfile(vim.fs.joinpath(root, "alacritty.toml")))
	local path = vim.fs.joinpath(self.dir, "alacritty/alacritty.toml")
	S.write(path, lines)
	return path
end

--- Where Alacritty writes its log: the per-user temp dir launchd gives apps
--- (an SSH session may have no $TMPDIR).
---@return string
local function temp_dir()
	local dir = vim.trim(vim.fn.system({ "getconf", "DARWIN_USER_TEMP_DIR" }))
	return vim.v.shell_error == 0 and dir ~= "" and dir or (vim.env.TMPDIR or "/tmp")
end

---@param self e2e.Stack
---@return string
local function zellij_err(self)
	return vim.fs.joinpath(self.dir, "zellij.err")
end

--- ERROR/WARN lines of Alacritty's log and zellij's stderr (exit status included).
---@param self e2e.Stack
---@return string[]
local function diagnostics(self)
	local lines = {}
	local log = self.log and vim.uv.fs_stat(self.log) and vim.fn.readfile(self.log) or {}
	for _, line in ipairs(log) do
		if line:find("%[ERROR%]") or line:find("%[WARN") then
			table.insert(lines, "alacritty: " .. line)
		end
	end
	local err = self.dir and vim.uv.fs_stat(zellij_err(self)) and vim.fn.readfile(zellij_err(self)) or {}
	for _, line in ipairs(err) do
		table.insert(lines, "zellij: " .. line)
	end
	local pid = self.alacritty_pid
	table.insert(lines, string.format("alacritty pid %s %s", pid or "-", pid and alive(pid) and "alive" or "gone"))
	return lines
end

--- Kills the window and the zellij session if this runner dies first.
---@param self e2e.Stack
local function start_watchdog(self)
	local script = table.concat({
		"while kill -0 $0 2>/dev/null; do sleep 1; done",
		"kill $1 2>/dev/null; sleep 1; kill -9 $1 2>/dev/null",
		'HOME="$2/home" ZELLIJ_SOCKET_DIR="$2/zsock" zellij kill-session "$3" >/dev/null 2>&1',
		'rm -rf "$2"',
	}, "\n")
	local args = { "sh", "-c", script, tostring(vim.fn.getpid()), tostring(self.alacritty_pid), self.dir, self.session }
	self.watchdog = vim.system(args, { detach = true })
end

---@type shortcuts.Frontend
M.ALACRITTY = {
	term = nil, -- Alacritty sets TERM=alacritty
	start = function(self)
		---@cast self e2e.Stack
		local cmd = { "launch", assert(M.app()), "--config-file", write_alacritty_config(self) }
		vim.list_extend(cmd, { "--title", self.session })
		vim.list_extend(cmd, { "-o", "window.dimensions.columns=" .. M.COLUMNS })
		vim.list_extend(cmd, { "-o", "window.dimensions.lines=" .. M.LINES })
		vim.list_extend(cmd, { "-o", "debug.persistent_logging=true" })
		local err = vim.fn.shellescape(zellij_err(self))
		local shell = string.format('%s 2>>%s; echo "exited with status $?" >>%s', self:zellij_command(), err, err)
		vim.list_extend(cmd, { "-e", "/bin/sh", "-c", shell })
		self.alacritty_pid = assert(tonumber(keys(cmd)), "keys launch printed no pid")
		self.log = vim.fs.joinpath(temp_dir(), "Alacritty-" .. self.alacritty_pid .. ".log")
		self:mark("Alacritty launched (pid " .. self.alacritty_pid .. ")")
		start_watchdog(self)
	end,
	diagnostics = diagnostics,
	stop = function(self)
		---@cast self e2e.Stack
		if self.focus_prev then
			pcall(keys, { "focus", tostring(self.focus_prev) })
			self.focus_prev = nil
		end
		local pid = self.alacritty_pid
		if pid then
			vim.uv.kill(pid, 15)
			if not vim.wait(3000, function()
				return not alive(pid)
			end, 50) then
				vim.uv.kill(pid, 9)
			end
			self.alacritty_pid = nil
		end
		if self.watchdog then
			pcall(self.watchdog.kill, self.watchdog, 9)
			self.watchdog = nil
		end
		if self.log then
			vim.fn.delete(self.log)
			self.log = nil
		end
	end,
}

--- Is the whole stack still up (Alacritty process and Neovim RPC)?
---@param self e2e.Stack
---@return boolean
function M.alive(self)
	return self.alacritty_pid ~= nil and alive(self.alacritty_pid) and pcall(self.lua, self, "return 1")
end

--- Fail fast, with diagnostics, when the stack died after `what`.
---@param self e2e.Stack
---@param what string
function M.check_alive(self, what)
	if not M.alive(self) then
		error(string.format("e2e: the stack died after %s\n  %s", what, self:diagnostics()), 0)
	end
end

--- Post real key events (chords like "cmd+shift+h", "ctrl+return") to the window,
--- then check that the stack survived them (expect_exit: a quitting chord).
---@param self e2e.Stack
---@param chords string|string[]
---@param expect_exit? boolean
function M.press(self, chords, expect_exit)
	chords = type(chords) == "table" and chords or { chords }
	local hid = vim.iter(chords):any(function(chord)
		return M.HID[chord]
	end)
	local cmd = hid and { "press", "--hid" } or { "press" }
	table.insert(cmd, tostring(assert(self.alacritty_pid, "Alacritty not running")))
	keys(vim.list_extend(cmd, chords))
	if not expect_exit then
		M.check_alive(self, "pressing " .. table.concat(chords, " "))
	end
end

--- Clear the pushed hits (and Neovim's own log) before a press.
---@param self e2e.Stack
function M.clear(self)
	M.events = {}
	self:clear_hits()
end

--- Wait until `n` recorded keys were pushed, at most `timeout` ms (or until the
--- window of `self` dies); returns them.
---@param n integer
---@param timeout integer
---@param self? e2e.Stack
---@return string[]
function M.wait_hits(n, timeout, self)
	vim.wait(timeout, function()
		return #M.events >= n or (self ~= nil and not alive(assert(self.alacritty_pid, "Alacritty not running")))
	end, 5)
	return M.events
end

--- Is the Alacritty window hidden (the app menu's Hide)?
---@param self e2e.Stack
---@return boolean
function M.hidden(self)
	return keys({ "hidden", tostring(assert(self.alacritty_pid, "Alacritty not running")) }) == "true"
end

--- Chords on the key helper's denylist (system-wide shortcuts it never presses).
---@param chords string[]
---@return table<string, true>
function M.denied(chords)
	local result = S.run(vim.list_extend({ M.keys(), "denied" }, chords))
	local set = {}
	for _, chord in ipairs(vim.split(vim.trim(result.stdout or ""), " ", { trimempty = true })) do
		set[chord] = true
	end
	return set
end

--- Run `fn` (key presses and checks) with the window frontmost unless background
--- events work; the previous frontmost app gets focus back, also on errors.
---@param self e2e.Stack
---@param fn fun()
function M.burst(self, fn)
	if self.background then
		return fn()
	end
	local pid = tostring(assert(self.alacritty_pid, "Alacritty not running"))
	local prev = tonumber(keys({ "focus", pid }))
	self.focus_prev = prev ~= self.alacritty_pid and prev ~= 0 and prev or nil
	local ok, err = pcall(fn)
	if self.focus_prev then
		pcall(keys, { "focus", tostring(self.focus_prev) })
		self.focus_prev = nil
	end
	if not ok then
		error(err, 0)
	end
end

--- Shortcut table name ("Cmd+Shift+-", "Ctrl+Return") to a helper chord.
---@param shortcut string
---@return string
function M.chord(shortcut)
	local names = { Cmd = "cmd", Shift = "shift", Option = "opt", Ctrl = "ctrl" }
	local parts = vim.split(shortcut, "+", { plain = true })
	local key = table.remove(parts)
	local chord = vim.tbl_map(function(mod)
		return assert(names[mod], "unknown modifier " .. mod .. " in " .. shortcut)
	end, parts)
	table.insert(chord, key:lower())
	return table.concat(chord, "+")
end

--- Install recorders for `keys` that also push their hits to this runner.
---@param self e2e.Stack
---@param lhs string[]
function M.record(self, lhs)
	self:record(lhs)
	-- the runner's channel id as Neovim sees it (nvim_get_api_info is RPC-only)
	local id = vim.rpcrequest(assert(self.channel, "Neovim not connected"), "nvim_get_api_info")[1]
	self:lua("_G.shortcut_notify = ...", { id })
	M.events = {}
end

--- Does a press of the probe chord record exactly the probe key?
---@param self e2e.Stack
---@param timeout integer
---@return boolean
local function probe_arrives(self, timeout)
	M.record(self, { PROBE_KEY })
	M.press(self, PROBE_CHORD)
	local hits = M.wait_hits(1, timeout)
	self:restore()
	return vim.deep_equal(hits, { PROBE_KEY })
end

--- Start Alacritty + zellij + Neovim and find out whether key events need focus
--- ($E2E_FOCUS=1 skips the probe and always focuses). Call stack:stop() when done.
---@return e2e.Stack
function M.start()
	local self = S.start(M.ALACRITTY) --[[@as e2e.Stack]]
	local ok, err = pcall(function()
		self.background = vim.env.E2E_FOCUS ~= "1" and probe_arrives(self, 800)
		self:mark(self.background and "probe key arrived in the background" or "no probe key in the background")
		if not self.background then
			local arrived = false
			M.burst(self, function()
				arrived = probe_arrives(self, 2000)
			end)
			assert(arrived, "e2e: a key event posted to the focused Alacritty window never reached Neovim")
			self:mark("probe key arrived with focus")
		end
	end)
	if not ok then
		local diag = self:diagnostics()
		self:stop()
		error(tostring(err) .. "\n  " .. diag, 0)
	end
	io.write(
		string.format("e2e: key events %s\n", self.background and "arrive in the background" or "need focus (bursts)")
	)
	return self
end

return M
