-- Colored capture of the real config: start it in a private, detached tmux
-- server sized columns x rows, drive a render case over RPC (--listen socket),
-- wait until the screen stops changing, then `tmux capture-pane -e`.
-- Same isolation as the tests (tests/helpers.lua): temp XDG dirs, plugins
-- linked from NVIM_TEST_DATA_DIR, copilot disabled, no multiplexer env.

local H = require("tests.helpers")

local M = {}

local CONF = vim.fs.joinpath(H.root, "tests/render/tmux.conf")
local SESSION = "render"
local CONNECT_TIMEOUT_MS = 10000
local STABLE_POLLS = 5 -- identical captures in a row that count as "drawn"
local POLL_MS = 50
local SETTLE_TIMEOUT_MS = 5000

---@class render.Size
---@field columns integer
---@field lines integer

---@class render.Tmux
---@field socket string
---@field address string Neovim --listen address

---@param tmux render.Tmux
---@param args string[]
---@return string stdout
local function run_tmux(tmux, args)
	local cmd = vim.list_extend({ "tmux", "-S", tmux.socket, "-f", CONF }, args)
	local result = vim.system(cmd, { text = true }):wait()
	assert(result.code == 0, ("tmux %s failed: %s"):format(args[1], result.stderr))
	return result.stdout or ""
end

--- Command run in the pane: the real config, with tmux's own env vars removed
--- so smart-splits does not treat the render as a multiplexer pane.
---@param address string
---@return string[]
local function nvim_command(address)
	local cmd = { "env", "-u", "TMUX", "-u", "TMUX_PANE", "COLORTERM=truecolor" }
	vim.list_extend(cmd, { vim.v.progpath, "--clean", "-n", "--listen", address })
	return vim.list_extend(cmd, H.config_args())
end

---@param size render.Size
---@return render.Tmux
local function start(size)
	H.isolate()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local tmux = { socket = vim.fs.joinpath(dir, "tmux.sock"), address = vim.fs.joinpath(dir, "nvim.sock") }
	local new_session = { "new-session", "-d", "-s", SESSION, "-c", H.root }
	vim.list_extend(new_session, { "-x", tostring(size.columns), "-y", tostring(size.lines), "--" })
	run_tmux(tmux, vim.list_extend(new_session, nvim_command(tmux.address)))
	return tmux
end

---@param tmux render.Tmux
---@param escapes boolean keep color/attribute escape sequences
---@return string
local function capture(tmux, escapes)
	local args = { "capture-pane", "-p", "-N", "-t", SESSION }
	if escapes then
		table.insert(args, "-e")
	end
	return run_tmux(tmux, args)
end

---@param tmux render.Tmux
---@return integer channel
local function connect(tmux)
	local ok, channel
	local function try_connect()
		ok, channel = pcall(vim.fn.sockconnect, "pipe", tmux.address, { rpc = true })
		return ok
	end
	if not vim.wait(CONNECT_TIMEOUT_MS, try_connect, POLL_MS) then
		error("Neovim in tmux did not start:\n" .. capture(tmux, false))
	end
	return channel
end

---@param channel integer
---@return render.Driver
local function rpc_driver(channel)
	---@param code string
	---@param args? any[]
	local function lua(code, args)
		return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {})
	end

	---@param command string
	local function cmd(command)
		vim.rpcrequest(channel, "nvim_command", command)
	end

	---@param keys string
	local function type_keys(keys)
		vim.rpcrequest(channel, "nvim_input", keys)
	end

	---@param expr string
	---@param timeout? integer
	---@return boolean
	local function wait(expr, timeout)
		local function truthy()
			return lua("return " .. expr) and true or false
		end
		return vim.wait(timeout or 2000, truthy, POLL_MS)
	end

	return { lua = lua, cmd = cmd, type_keys = type_keys, wait = wait }
end

--- Poll the pane until STABLE_POLLS captures in a row are identical (timers of
--- lualine/bufferline and async plugins have redrawn), instead of a fixed sleep.
---@param tmux render.Tmux
---@return string
local function settled_capture(tmux)
	local last, same = capture(tmux, true), 0
	local function stable()
		local screen = capture(tmux, true)
		same = screen == last and same + 1 or 0
		last = screen
		return same >= STABLE_POLLS
	end
	vim.wait(SETTLE_TIMEOUT_MS, stable, POLL_MS)
	return last
end

--- SGR state kind of one escape: "reset", "fg", "bg" or the escape itself.
---@param params string parameters of `ESC[<params>m`
---@return string
local function sgr_kind(params)
	local first = tonumber(params:match("^%d*")) or 0
	if first == 0 then
		return "reset"
	elseif first == 38 or first == 39 or (first >= 30 and first <= 37) or (first >= 90 and first <= 97) then
		return "fg"
	elseif first == 48 or first == 49 or (first >= 40 and first <= 47) or (first >= 100 and first <= 107) then
		return "bg"
	end
	return params
end

--- Fold the SGR escapes of `line` into `state` (kind -> escape).
---@param state table<string, string>
---@param line string
local function track_sgr(state, line)
	for params in line:gmatch("\27%[([%d;:]*)m") do
		local kind = sgr_kind(params)
		if kind == "reset" then
			for key in pairs(state) do
				state[key] = nil
			end
		else
			state[kind] = "\27[" .. params .. "m"
		end
	end
end

--- tmux carries attributes across lines in `capture-pane -e`. Make every line
--- self-contained (restore the carried state at its start, reset at its end)
--- so `cat`, `less -R` and partial views show the right colors.
---@param screen string
---@return string
local function self_contained_lines(screen)
	local state, lines = {}, {}
	for _, line in ipairs(vim.split((screen:gsub("\n$", "")), "\n", { plain = true })) do
		table.insert(lines, table.concat(vim.tbl_values(state)) .. line .. "\27[0m")
		track_sgr(state, line)
	end
	return table.concat(lines, "\n")
end

---@param tmux render.Tmux
---@param channel? integer
---@param pid? integer
local function stop(tmux, channel, pid)
	if channel then
		pcall(vim.rpcrequest, channel, "nvim_command", "qall!") -- errors once the channel closes
		pcall(vim.fn.chanclose, channel)
	end
	if pid then
		-- the TUI's --embed server must be gone before its temp XDG dirs are
		vim.wait(SETTLE_TIMEOUT_MS, function()
			return vim.uv.kill(pid, 0) ~= 0
		end, POLL_MS)
		pcall(vim.uv.kill, pid, "sigkill")
		H.delete_debug_log(pid)
	end
	pcall(run_tmux, tmux, { "kill-server" })
	vim.fn.delete(vim.fs.dirname(tmux.socket), "rf")
end

---@param tmux render.Tmux
---@param case render.Case
---@return string screen
---@return integer channel
---@return integer pid
local function drive(tmux, case)
	local channel = connect(tmux)
	local driver = rpc_driver(channel)
	-- requests are served while the TUI starts, so wait for VimEnter first
	assert(driver.wait("vim.v.vim_did_enter == 1", CONNECT_TIMEOUT_MS), "VimEnter did not fire")
	local pid = driver.lua("return vim.fn.getpid()")
	for _, plugin in ipairs(H.DISABLED_PLUGINS) do
		driver.lua(H.DISABLE_PLUGIN_LUA, { plugin })
	end
	assert(driver.wait("vim.g.did_very_lazy", CONNECT_TIMEOUT_MS), "VeryLazy did not fire")
	case.setup(driver)
	return settled_capture(tmux), channel, pid
end

--- Render `case` in tmux and return the screen with truecolor SGR escapes.
---@param case render.Case
---@param size render.Size
---@return string
function M.capture(case, size)
	local tmux = start(size)
	local ok, screen, channel, pid = pcall(drive, tmux, case)
	stop(tmux, channel, pid)
	assert(ok, screen)
	return self_contained_lines(screen)
end

return M
