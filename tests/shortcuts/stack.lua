-- Stack layer harness: tmux (pty only) -> real zellij with the user's keybinds
-- -> Neovim with the real config, driven by raw bytes and observed over RPC.
--
-- Isolation: a temp dir under /tmp (unix sockets need short paths) holds the
-- tmux socket, ZELLIJ_SOCKET_DIR, a HOME for zellij (its cache, permissions and
-- session data live in $HOME/Library/Caches on macOS) and the Neovim socket.
-- Neovim gets the tests/helpers.lua sandbox (XDG dirs, plugins symlinked).
-- zellij's config is a copy with session serialization off; keybinds are
-- byte-identical. Everything is removed by M.stop(), also after failures.

local H = require("tests.helpers")
local C = require("tests.shortcuts.chain")

local M = {}

local NAVIGATOR_PERMISSIONS = { "WriteToStdin", "ReadApplicationState", "ChangeApplicationState" }
local EXTRA_OPTIONS = {
	"session_serialization false",
	"show_release_notes false",
	"show_startup_tips false",
}

---@class shortcuts.Stack
---@field dir string
---@field session string
---@field env table<string, string?>
---@field channel integer? RPC channel to Neovim
---@field nvim_pid integer?
---@field frontend shortcuts.Frontend
local Stack = {}
Stack.__index = Stack

---@param cmd string[]
---@param env? table<string, string>
---@return vim.SystemCompleted
local function run(cmd, env)
	return vim.system(cmd, { text = true, env = env }):wait(10000)
end

---@param path string
---@param lines string[]
local function write(path, lines)
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	assert(vim.fn.writefile(lines, path) == 0, "cannot write " .. path)
end

--- Plugin files referenced by MessagePlugin binds (to pre-grant permissions).
---@return string[]
local function plugin_paths()
	local paths = {}
	for _, binds in pairs(C.configs().zellij.modes) do
		for _, bind in pairs(binds) do
			for _, action in ipairs(bind.actions) do
				local url = action.name == "MessagePlugin" and action.args[1]
				local path = url and url:match("^file:(.+)$")
				if path then
					paths[path] = true
				end
			end
		end
	end
	return vim.tbl_keys(paths)
end

---@param self shortcuts.Stack
local function write_zellij_files(self)
	local config = vim.fn.readfile(C.configs().zellij.file)
	write(vim.fs.joinpath(self.dir, "zellij/config.kdl"), vim.list_extend(config, EXTRA_OPTIONS))
	local permissions = {}
	for _, path in ipairs(plugin_paths()) do
		table.insert(permissions, string.format("%q {", path))
		vim.list_extend(permissions, NAVIGATOR_PERMISSIONS)
		table.insert(permissions, "}")
	end
	write(vim.fs.joinpath(self.dir, "home/Library/Caches/org.Zellij-Contributors.Zellij/permissions.kdl"), permissions)
	local nvim_args = {
		"--cmd",
		"luafile " .. vim.fs.joinpath(H.root, "tests/child_init.lua"),
		"--listen",
		self:nvim_socket(),
	}
	local quoted = table.concat(vim.tbl_map(vim.json.encode, nvim_args), " ")
	write(vim.fs.joinpath(self.dir, "layout.kdl"), {
		"layout {",
		'  pane split_direction="vertical" {',
		'    pane command="nvim" { args ' .. quoted .. "; }",
		'    pane command="cat"',
		"  }",
		"}",
	})
end

---@return string
function Stack:nvim_socket()
	return vim.fs.joinpath(self.dir, "nvim.sock")
end

---@return string
function Stack:tmux_socket()
	return vim.fs.joinpath(self.dir, "tmux.sock")
end

--- Shell command tmux runs: zellij with the copied config and isolated env.
---@return string
function Stack:zellij_command()
	-- tmux exports these into the pane; smart-splits would pick its tmux backend
	local env = { "env", "-u", "TMUX", "-u", "TMUX_PANE", "-u", "TERM_PROGRAM", "-u", "TERM_PROGRAM_VERSION" }
	for name, value in pairs(self.env) do
		table.insert(env, name .. "=" .. vim.fn.shellescape(value))
	end
	local zellij = {
		"zellij",
		"--config-dir",
		vim.fs.joinpath(self.dir, "zellij"),
		"--config",
		vim.fs.joinpath(self.dir, "zellij/config.kdl"),
		"--session",
		self.session,
		"--new-session-with-layout",
		vim.fs.joinpath(self.dir, "layout.kdl"),
	}
	return table.concat(env, " ") .. " " .. table.concat(vim.tbl_map(vim.fn.shellescape, zellij), " ")
end

---@param predicate fun(): boolean
---@param what string
---@param timeout? integer
function M.wait_for(predicate, what, timeout)
	local ok = vim.wait(timeout or 10000, function()
		local done, value = pcall(predicate)
		return done and value
	end, 50)
	assert(ok, "stack: timed out waiting for " .. what)
end

--- Run `zellij action ...` against this session.
---@param ... string
---@return string stdout
function Stack:zellij(...)
	local result = run(vim.list_extend({ "zellij", "--session", self.session, "action" }, { ... }), self.env)
	assert(result.code == 0, "zellij action failed: " .. (result.stderr or ""))
	return result.stdout
end

--- Pane id the (only) client focuses, e.g. "terminal_0".
---@return string
function Stack:focused_pane()
	local lines = vim.split(vim.trim(self:zellij("list-clients")), "\n")
	return assert(lines[2] and lines[2]:match("^%S+%s+(%S+)"), "no client in list-clients")
end

--- Write raw bytes into the tmux pane (zellij's stdin), unchanged.
---@param bytes string
function Stack:send(bytes)
	local hex = vim.tbl_map(function(byte)
		return string.format("%02x", byte)
	end, { bytes:byte(1, -1) })
	local result = run(vim.list_extend({ "tmux", "-S", self:tmux_socket(), "send-keys", "-H" }, hex))
	assert(result.code == 0, "tmux send-keys failed: " .. (result.stderr or ""))
end

--- Run Lua in Neovim over RPC.
---@param code string
---@param args? any[]
---@return any
function Stack:lua(code, args)
	local channel = assert(self.channel, "stack: Neovim not connected")
	-- nvim_get_mode is answered even while Neovim blocks (getchar, prompts),
	-- where nvim_exec_lua would hang the whole run
	local mode = vim.rpcrequest(channel, "nvim_get_mode") --[[@as { mode: string, blocking: boolean }]]
	assert(not mode.blocking, "stack: Neovim is blocked in mode " .. mode.mode)
	return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {})
end

---@param self shortcuts.Stack
local function connect(self)
	M.wait_for(function()
		return vim.uv.fs_stat(self:nvim_socket()) ~= nil
	end, "Neovim socket")
	self.channel = vim.fn.sockconnect("pipe", self:nvim_socket(), { rpc = true })
	assert(self.channel > 0, "cannot connect to " .. self:nvim_socket())
	-- zellij is a real UI, so UIEnter and VeryLazy fire on their own
	self.nvim_pid = self:lua("return vim.fn.getpid()")
	M.wait_for(function()
		return self:lua("return vim.g.did_very_lazy == true")
	end, "VeryLazy")
	self:lua([[local plugin = require("lazy.core.config").plugins["copilot.lua"]
		if plugin then require("lazy.core.handler").disable(plugin) end]])
	M.wait_for(function()
		return self:focused_pane() == "terminal_0"
	end, "zellij client focused on the Neovim pane")
end

--- What runs zellij: a terminal (tmux pty here, a real Alacritty window in
--- tests/e2e/alacritty.lua). start() launches `self:zellij_command()`; stop()
--- must be safe to call twice and after a failed start.
---@class shortcuts.Frontend
---@field term? string TERM for zellij (nil: inherit the terminal's own)
---@field start fun(self: shortcuts.Stack)
---@field stop fun(self: shortcuts.Stack)

---@type shortcuts.Frontend
M.TMUX = {
	term = "xterm-256color",
	start = function(self)
		local tmux = { "tmux", "-S", self:tmux_socket(), "-f", "/dev/null", "new-session", "-d" }
		vim.list_extend(tmux, { "-x", "200", "-y", "50", self:zellij_command() })
		local result = run(tmux)
		assert(result.code == 0, "tmux new-session failed: " .. (result.stderr or ""))
	end,
	stop = function(self)
		run({ "tmux", "-S", self:tmux_socket(), "kill-server" })
	end,
}

--- Start the frontend (default tmux) + zellij + Neovim. Call stack:stop() when done.
---@param frontend? shortcuts.Frontend
---@return shortcuts.Stack
function M.start(frontend)
	H.isolate()
	local self = setmetatable({ frontend = frontend or M.TMUX }, Stack)
	self.dir = vim.trim(vim.fn.system({ "mktemp", "-d", "/tmp/nvst.XXXXXX" }))
	self.session = string.format("nvim-shortcuts-%d-%d", vim.fn.getpid(), vim.uv.hrtime() % 100000)
	self.env = {
		HOME = vim.fs.joinpath(self.dir, "home"),
		ZELLIJ_SOCKET_DIR = vim.fs.joinpath(self.dir, "zsock"),
		XDG_CONFIG_HOME = vim.env.XDG_CONFIG_HOME,
		XDG_DATA_HOME = vim.env.XDG_DATA_HOME,
		XDG_STATE_HOME = vim.env.XDG_STATE_HOME,
		XDG_CACHE_HOME = vim.env.XDG_CACHE_HOME,
		PATH = vim.env.PATH,
		TERM = self.frontend.term,
	}
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			self:stop()
		end,
	})
	local ok, err = pcall(function()
		write_zellij_files(self)
		self.frontend.start(self)
		connect(self)
	end)
	if not ok then
		self:stop()
		error(err, 0)
	end
	return self
end

--- Kill zellij and the frontend, close RPC, delete the temp dir. Safe to call twice.
function Stack:stop()
	if self.channel then
		pcall(vim.fn.chanclose, self.channel)
		self.channel = nil
	end
	if self.dir then
		run({ "zellij", "kill-session", self.session }, self.env)
		self.frontend.stop(self)
		vim.fn.delete(self.dir, "rf")
		self.dir = nil
	end
	if self.nvim_pid then
		-- nvim-debug-log writes /tmp/nvim/<time>_<pid>.txt (see tests/helpers.lua)
		for _, file in ipairs(vim.fn.glob("/tmp/nvim/*_" .. self.nvim_pid .. ".txt", false, true)) do
			vim.fn.delete(file)
		end
		self.nvim_pid = nil
	end
end

-- Recorder mappings: replace the normal-mode mapping of each key with one that
-- logs the key, so arrival is observable for mapped and unmapped keys alike.
local RECORD = [[_G.shortcut_hits = {}
	_G.shortcut_saved = _G.shortcut_saved or {}
	for _, lhs in ipairs(...) do
		if _G.shortcut_saved[lhs] == nil then
			_G.shortcut_saved[lhs] = vim.fn.maparg(lhs, "n", false, true)
		end
		vim.keymap.set("n", lhs, function() table.insert(_G.shortcut_hits, lhs) end)
	end]]

local RESTORE = [[for lhs, saved in pairs(_G.shortcut_saved or {}) do
		pcall(vim.keymap.del, "n", lhs)
		if not vim.tbl_isempty(saved) then vim.fn.mapset(saved) end
	end
	_G.shortcut_saved, _G.shortcut_hits = {}, {}]]

--- Install recorders for `keys` (Neovim notation) and clear the hit log.
---@param keys string[]
function Stack:record(keys)
	self:lua(RECORD, { keys })
end

--- Keys recorded since the last record() call.
---@return string[]
function Stack:hits()
	return self:lua("return _G.shortcut_hits or {}")
end

--- Put the real mappings back.
function Stack:restore()
	self:lua(RESTORE)
end

--- Clear the hit log without touching recorders.
function Stack:clear_hits()
	self:lua("_G.shortcut_hits = {}")
end

-- for frontends (tests/e2e/alacritty.lua)
M.run, M.write = run, write

return M
