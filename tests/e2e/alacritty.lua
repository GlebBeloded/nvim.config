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
-- focus back to the previous app afterwards.
--
-- Cleanup: stop() kills the window, the zellij session and the temp dir; a
-- detached watchdog does the same if the runner dies (timeout, SIGKILL).

local C = require("tests.shortcuts.chain")
local H = require("tests.helpers")
local S = require("tests.shortcuts.stack")

local M = {}

M.COLUMNS, M.LINES = 160, 45
local PROBE_KEY, PROBE_CHORD = "<M-b>", "cmd+b" -- passes zellij, no Neovim mapping

---@class e2e.Stack: shortcuts.Stack
---@field alacritty_pid integer?
---@field watchdog vim.SystemObj?
---@field background boolean key events arrive without focusing the window
---@field focus_prev integer? app to give focus back to (while a burst runs)

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
		vim.list_extend(cmd, { "-e", "/bin/sh", "-c", self:zellij_command() })
		self.alacritty_pid = assert(tonumber(keys(cmd)), "keys launch printed no pid")
		start_watchdog(self)
	end,
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
	end,
}

--- Post real key events (chords like "cmd+shift+h", "ctrl+return") to the window.
---@param self e2e.Stack
---@param ... string
function M.press(self, ...)
	keys({ "press", tostring(assert(self.alacritty_pid, "Alacritty not running")), ... })
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

---@param self e2e.Stack
---@param chord string
---@param timeout integer
---@return boolean
local function probe_arrives(self, chord, timeout)
	self:record({ PROBE_KEY })
	M.press(self, chord)
	local ok = vim.wait(timeout, function()
		return #self:hits() > 0
	end, 20)
	self:restore()
	return ok
end

--- Start Alacritty + zellij + Neovim and find out whether key events need focus
--- ($E2E_FOCUS=1 skips the probe and always focuses). Call stack:stop() when done.
---@return e2e.Stack
function M.start()
	local self = S.start(M.ALACRITTY) --[[@as e2e.Stack]]
	local ok, err = pcall(function()
		self.background = vim.env.E2E_FOCUS ~= "1" and probe_arrives(self, PROBE_CHORD, 800)
		if not self.background then
			local arrived = false
			M.burst(self, function()
				arrived = probe_arrives(self, PROBE_CHORD, 2000)
			end)
			assert(arrived, "e2e: a key event posted to the focused Alacritty window never reached Neovim")
		end
	end)
	if not ok then
		self:stop()
		error(err, 0)
	end
	io.write(
		string.format("e2e: key events %s\n", self.background and "arrive in the background" or "need focus (bursts)")
	)
	return self
end

return M
