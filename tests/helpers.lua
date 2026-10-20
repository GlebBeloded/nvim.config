-- Shared helpers for mini.test cases. Runs inside the runner Neovim.
--
-- Child Neovims never touch the user's real state: every XDG directory points
-- into a temp sandbox. `stdpath("config")` is a symlink to this checkout and
-- the cache is shared per run; data/state are fresh for every child start
-- (no sessions, shada, undo files carried over). Only installed plugins
-- (`lazy/`), treesitter parsers (`site/`) and mason packages (`mason/`) are
-- linked from NVIM_TEST_DATA_DIR.

local MiniTest = require("mini.test")

local M = {}

---@type string Absolute path of the config checkout (worktree root).
M.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

---@type string Data dir holding installed plugins (`lazy/`), parsers (`site/`) and mason packages (`mason/`).
M.data_dir = vim.env.NVIM_TEST_DATA_DIR or vim.fs.joinpath(vim.env.HOME, ".local/share/nvim")

--- Env vars that make plugins talk to a terminal multiplexer (smart-splits).
local MULTIPLEXER_ENV = {
	"ZELLIJ",
	"ZELLIJ_SESSION_NAME",
	"ZELLIJ_PANE_ID",
	"TMUX",
	"TMUX_PANE",
	"WEZTERM_PANE",
	"KITTY_LISTEN_ON",
	"KITTY_WINDOW_ID",
}

---@type string?
local sandbox

---@param target string
---@param link string
local function symlink(target, link)
	vim.fn.mkdir(vim.fs.dirname(link), "p")
	if vim.uv.fs_stat(target) then
		assert(vim.uv.fs_symlink(target, link))
	end
end

--- Point XDG_DATA_HOME/XDG_STATE_HOME at fresh dirs so each child starts
--- without sessions, shada or undo history left by earlier children.
local function fresh_state()
	local dir = vim.fn.tempname()
	symlink(vim.fs.joinpath(M.data_dir, "lazy"), vim.fs.joinpath(dir, "data/nvim/lazy"))
	symlink(vim.fs.joinpath(M.data_dir, "site"), vim.fs.joinpath(dir, "data/nvim/site"))
	symlink(vim.fs.joinpath(M.data_dir, "mason"), vim.fs.joinpath(dir, "data/nvim/mason"))
	vim.fn.mkdir(vim.fs.joinpath(dir, "state"), "p")
	vim.env.XDG_DATA_HOME = vim.fs.joinpath(dir, "data")
	vim.env.XDG_STATE_HOME = vim.fs.joinpath(dir, "state")
end

--- Point this process's env (inherited by children) at a sandbox: shared
--- config symlink and cache per run, fresh data/state per call.
---@return string sandbox directory
function M.isolate()
	vim.env.GLEB_TEST_SANDBOX = "1"
	if not sandbox then
		sandbox = vim.fn.tempname()
		symlink(M.root, vim.fs.joinpath(sandbox, "config/nvim"))
		-- vim.loader's mkdir("cache/nvim/luac", "p") races when two Neovims
		-- start at once (E739), so the cache tree exists before any child runs
		vim.fn.mkdir(vim.fs.joinpath(sandbox, "cache/nvim/luac"), "p")
		vim.env.XDG_CONFIG_HOME = vim.fs.joinpath(sandbox, "config")
		vim.env.XDG_CACHE_HOME = vim.fs.joinpath(sandbox, "cache")
		vim.env.PATH = vim.fs.joinpath(M.root, "tests/fixtures/bin") .. ":" .. vim.env.PATH
		-- the Go build cache of every gopls a test starts (the fixtures' too, tests/fixtures.lua): the default
		-- ~/Library/Caches/go-build grew 17 GB in two hours of gates (Oct 2026); tests/check.sh trims this one
		vim.env.GOCACHE = vim.fs.joinpath(M.root, ".tests/go/cache")
		vim.env.NVIM_APPNAME = nil
		for _, name in ipairs(MULTIPLEXER_ENV) do
			vim.env[name] = nil
		end
	end
	fresh_state()
	return sandbox
end

---@class test.RestartOpts
---@field env? table<string, string> env vars set for this start only (e.g. ZELLIJ_PANE_ID)

---@class test.Child: MiniTest.child
---@field start_config fun() Restart with the real config (init.lua); copilot.lua disabled.
---@field restart_config fun(args?: string[], opts?: test.RestartOpts) Start the real config again on the previous start's data/state (sessions, shada kept), with extra Neovim args.
---@field start_bare fun(plugins?: string[]) Restart with tests/minimal_init.lua plus the named lazy plugins on rtp.
---@field disable_plugin fun(name: string) Remove lazy.nvim load handlers of a plugin.
---@field wait_very_lazy fun() Fire UIEnter (absent headless) and wait for VeryLazy.
---@field wait fun(expr: string, timeout?: integer): boolean Wait until Lua `expr` is truthy in the child.

--- Lua run in a full-config Neovim to remove lazy.nvim load handlers of the
--- plugin named by its first argument.
M.DISABLE_PLUGIN_LUA = [[local plugin = require("lazy.core.config").plugins[...]
if plugin then require("lazy.core.handler").disable(plugin) end]]

--- Plugins disabled in every full-config Neovim (copilot.lua lazy-loads on
--- InsertEnter and talks to the network).
M.DISABLED_PLUGINS = { "copilot.lua" }

--- nvim-debug-log writes /tmp/nvim/<time>_<pid>.txt (hard-coded path).
---@param pid integer
function M.delete_debug_log(pid)
	for _, file in ipairs(vim.fn.glob("/tmp/nvim/*_" .. pid .. ".txt", false, true)) do
		vim.fn.delete(file)
	end
end

---@param child MiniTest.child
local function delete_child_debug_log(child)
	local ok, pid = pcall(function()
		return child.fn.getpid() -- indexing child.fn already talks to the child
	end)
	if ok then
		M.delete_debug_log(pid)
	end
end

--- Neovim arguments that load the real config from the sandbox symlink
--- (needed because mini.test and the render harness pass --clean).
---@return string[]
function M.config_args()
	local config = vim.fs.joinpath(vim.env.XDG_CONFIG_HOME, "nvim")
	return {
		"--cmd",
		"set rtp^=" .. config,
		"--cmd",
		"luafile " .. vim.fs.joinpath(M.root, "tests/child_init.lua"),
		"-u",
		vim.fs.joinpath(config, "init.lua"),
	}
end

--- Run `fn` with `env` set in this process (inherited by a child started
--- inside it), then restore the previous values.
---@param env table<string, string>
---@param fn fun()
local function with_env(env, fn)
	local saved = {}
	for name, value in pairs(env) do
		saved[name] = vim.env[name] or false
		vim.env[name] = value
	end
	local ok, err = pcall(fn)
	for name, value in pairs(saved) do
		vim.env[name] = value or nil
	end
	assert(ok, err)
end

--- New child Neovim with config/bare start helpers.
---@return test.Child
--- Polls the parent every second; once it is gone (the child was reparented), stops the LSP clients (their
--- servers exit with them) and quits, then kills itself if a blocking wait keeps it from quitting.
M.WATCHDOG = "lua local p = vim.uv.os_getppid() local t = vim.uv.new_timer() "
	-- p == 1: the parent died before this ran (a loaded host starts Neovim slowly), so p could never change
	.. "t:start(p == 1 and 0 or 1000, 1000, function() if p ~= 1 and vim.uv.os_getppid() == p then return end t:stop() "
	.. "vim.schedule(function() pcall(vim.lsp.stop_client, vim.lsp.get_clients(), true) vim.cmd('qa!') end) "
	.. "vim.uv.new_timer():start(3000, 0, function() vim.uv.kill(vim.uv.os_getpid(), 'sigkill') end) end)"

function M.new_child()
	M.isolate()
	local child = MiniTest.new_child_neovim() --[[@as test.Child]]
	local start = child.start

	--- Every child gets WATCHDOG: a child whose test worker was killed (a hung case, an interrupted run) exits
	--- instead of living on with its `--listen` socket and LSP servers.
	function child.start(args, opts)
		args = args or {}
		if args[2] ~= M.WATCHDOG then
			args = vim.list_extend({ "--cmd", M.WATCHDOG }, args)
		end
		start(args, opts)
	end

	local stop = child.stop

	function child.stop()
		if child.is_running() then
			delete_child_debug_log(child)
		end
		stop()
	end

	function child.start_config()
		-- mini.test always passes --clean, which drops stdpath("config") from rtp
		M.isolate()
		child.restart(M.config_args())
		vim.iter(M.DISABLED_PLUGINS):each(child.disable_plugin)
	end

	function child.restart_config(args, opts)
		with_env(opts and opts.env or {}, function()
			child.restart(vim.list_extend(M.config_args(), args or {}))
		end)
		vim.iter(M.DISABLED_PLUGINS):each(child.disable_plugin)
	end

	function child.disable_plugin(name)
		child.lua(M.DISABLE_PLUGIN_LUA, { name })
	end

	function child.start_bare(plugins)
		M.isolate()
		local args = { "-u", vim.fs.joinpath(M.root, "tests/minimal_init.lua") }
		for _, plugin in ipairs(plugins or {}) do
			vim.list_extend(args, { "--cmd", "set rtp+=" .. vim.fs.joinpath(M.data_dir, "lazy", plugin) })
		end
		child.restart(args)
	end

	function child.wait(expr, timeout)
		local ok = vim.wait(timeout or 2000, function()
			local value = child.lua_get(expr)
			return value ~= nil and value ~= vim.NIL and value ~= false
		end, 20)
		return ok
	end

	function child.wait_very_lazy()
		child.lua([[if not vim.g.did_very_lazy then vim.api.nvim_exec_autocmds("UIEnter", {}) end]])
		assert(child.wait("vim.g.did_very_lazy"), "VeryLazy did not fire")
	end

	return child
end

local SURFACE_OPEN_LUA = [[
local spec = ...
local started = vim.uv.hrtime()
local finished = false
local timer

local function write_state(phase, err)
	local ok_mode, mode = pcall(vim.api.nvim_get_mode)
	local ok_getchar, getchar = pcall(vim.fn.getchar, 1)
	local ok_messages, messages = pcall(vim.api.nvim_exec2, "messages", { output = true })
	local state = {
		phase = phase,
		elapsed = math.floor((vim.uv.hrtime() - started) / 1000000),
		mode = ok_mode and mode.mode or "<unavailable>",
		getchar = ok_getchar and vim.inspect(getchar) or "<unavailable>",
		messages = ok_messages and messages.output or "<unavailable>",
		error = err and tostring(err) or nil,
	}
	pcall(vim.fn.writefile, { vim.json.encode(state) }, spec.state_file)
end

local function finish(phase, err)
	finished = true
	if timer then
		timer:stop()
		timer:close()
	end
	write_state(phase, err)
end

local condition, condition_error = loadstring("return " .. spec.condition)
if not condition then
	finish("condition-error", condition_error)
	return
end

local function poll()
	if finished then
		return
	end
	local ok, ready = pcall(condition)
	if not ok then
		finish("condition-error", ready)
	elseif ready then
		finish("ready")
	else
		write_state("waiting")
	end
end

write_state("scheduled")
vim.schedule(function()
	write_state("opening")
	local open, open_error = loadstring(spec.open)
	if not open then
		finish("open-error", open_error)
		return
	end
	local ok, err = pcall(open)
	if not ok then
		finish("open-error", err)
		return
	end
	poll()
	if not finished then
		timer = vim.uv.new_timer()
		timer:start(20, 20, function()
			vim.schedule(poll)
		end)
	end
end)
]]

---@class tests.SurfaceOpen
---@field open string Lua statement that opens the surface in the child.
---@field condition string Lua expression that is truthy once the surface is ready.
---@field surface string Diagnostic name for the surface.
---@field timeout? integer Process-level deadline in milliseconds.

---@param path string
---@return table?
local function read_surface_state(path)
	if not vim.uv.fs_stat(path) then
		return nil
	end
	local lines = vim.fn.readfile(path)
	if #lines == 0 then
		return nil
	end
	local ok, state = pcall(vim.json.decode, table.concat(lines, "\n"))
	return ok and state or nil
end

---@param pid integer
---@param descendants integer[]
---@return boolean
local function collect_process_tree(pid, descendants)
	local ok_children, children = pcall(vim.api.nvim_get_proc_children, pid)
	if not ok_children then
		return false
	end
	for _, child_pid in ipairs(children) do
		collect_process_tree(child_pid, descendants)
		table.insert(descendants, child_pid)
	end
	return true
end

---@param pid integer
---@return string commands
---@return integer[] pids
local function child_subprocesses(pid)
	local descendants = {}
	if not collect_process_tree(pid, descendants) then
		return "<unavailable>", {}
	end
	local commands = {}
	for _, child_pid in ipairs(descendants) do
		local process = vim.system({ "ps", "-o", "args=", "-p", tostring(child_pid) }, { text = true }):wait()
		local command = process.code == 0 and vim.trim(process.stdout or "") or "<unavailable>"
		table.insert(commands, ("%d: %s"):format(child_pid, command))
	end
	return #commands > 0 and table.concat(commands, ", ") or "<none>", descendants
end

---@param child MiniTest.child
---@param pid integer
local function stop_blocked_child(child, pid)
	local _, subprocess_pids = child_subprocesses(pid)
	for _, subprocess_pid in ipairs(subprocess_pids) do
		pcall(vim.uv.kill, subprocess_pid, "sigkill")
	end
	vim.uv.kill(pid, "sigkill")
	vim.fn.jobwait({ child.job.id }, 1000)
	pcall(vim.fn.chanclose, child.job.channel)
	pcall(vim.fn.chanclose, child.job.id)
	pcall(vim.fn.delete, child.job.address)
	child.job = nil
	M.delete_debug_log(pid)
end

--- Open a child surface without making a blocking RPC request while waiting.
---@param child MiniTest.child
---@param spec tests.SurfaceOpen
function M.open_surface(child, spec)
	local state_file = vim.fn.tempname()
	local timeout = spec.timeout or 10000
	local started = vim.uv.hrtime()
	local state
	local pid = vim.fn.jobpid(child.job.id)
	child.lua_notify(
		SURFACE_OPEN_LUA,
		{ {
			condition = spec.condition,
			open = spec.open,
			state_file = state_file,
		} }
	)

	local completed = vim.wait(timeout, function()
		state = read_surface_state(state_file) or state
		return state ~= nil and state.phase ~= "scheduled" and state.phase ~= "opening" and state.phase ~= "waiting"
	end, 20)
	local elapsed = math.floor((vim.uv.hrtime() - started) / 1000000)
	state = state or {}
	state.subprocesses = child_subprocesses(pid)
	vim.fn.delete(state_file)

	if completed and state.phase == "ready" then
		return
	end
	if not completed and child.job then
		stop_blocked_child(child, pid)
	end

	error(
		("%s surface open failed (phase: %s; elapsed: %d ms; mode: %s; getchar: %s; messages: %s; subprocesses: %s%s)"):format(
			spec.surface,
			state.phase or "no-state",
			elapsed,
			state.mode or "<unavailable>",
			state.getchar or "<unavailable>",
			state.messages ~= "" and (state.messages or "<unavailable>") or "<none>",
			state.subprocesses or "<unavailable>",
			state.error and "; error: " .. state.error or ""
		)
	)
end

--- Test set whose cases each get a fresh child started by `start`.
---@param child test.Child
---@param start fun()
---@return table
function M.child_set(child, start)
	return MiniTest.new_set({
		hooks = {
			pre_case = start,
			post_once = child.stop,
		},
	})
end

--- Expected failure: wrap a case that documents a known bug (see
--- its queued change in openspec/changes/). It is reported as a skipped case with an XFAIL note
--- while it fails, and fails loudly (XPASS) once the bug is fixed.
---@param reason string finding reference shown in the note
---@param case fun()
---@return fun()
function M.xfail(reason, case)
	return function()
		if pcall(case) then
			error("XPASS (bug fixed? remove H.xfail): " .. reason)
		end
		MiniTest.skip("XFAIL: " .. reason)
	end
end

---@class test.GitRepoOpts
---@field remote? string URL added as `origin`

--- Run git in `dir` on the host and fail the case on a non-zero exit.
---@param dir string
---@param args string[]
---@return string stdout
function M.git(dir, args)
	local result = vim.system(vim.list_extend({ "git", "-C", dir }, args), { text = true }):wait()
	assert(result.code == 0, ("git %s: %s"):format(table.concat(args, " "), result.stderr))
	return result.stdout
end

--- Write `files` (path relative to `dir` -> content) into `dir`.
---@param dir string
---@param files table<string, string>
function M.write_files(dir, files)
	for name, content in pairs(files) do
		local path = vim.fs.joinpath(dir, name)
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile(vim.split(content, "\n", { plain = true }), path, "b")
	end
end

--- Temp git repository on branch `main` with `files` committed, so cases
--- that stage, commit or diff never touch this checkout.
---@param files table<string, string> path relative to the repo -> content
---@param opts? test.GitRepoOpts
---@return string path of the repo
function M.git_repo(files, opts)
	local dir = vim.fs.normalize(vim.fn.resolve(vim.fn.tempname()))
	vim.fn.mkdir(dir, "p")
	M.git(dir, { "init", "-q", "-b", "main" })
	M.git(dir, { "config", "user.name", "Test" })
	M.git(dir, { "config", "user.email", "test@example.com" })
	M.git(dir, { "config", "commit.gpgsign", "false" })
	M.write_files(dir, files)
	M.git(dir, { "add", "-A" })
	M.git(dir, { "commit", "-q", "--allow-empty", "-m", "initial" })
	if opts and opts.remote then
		M.git(dir, { "remote", "add", "origin", opts.remote })
	end
	return dir
end

---@class test.JobScript
---@field stdout? string[] `data` passed to `on_stdout` (not called when nil)
---@field code? integer exit code passed to `on_exit` (default 0)
---@field hold? boolean keep the job running until `M.finish_job`

---@class test.JobCall
---@field cmd string|string[] command given to `jobstart`
---@field stdin string everything sent to the job with `chansend`
---@field stopped boolean `jobstop` was called on it

--- Child-side: replace `vim.fn.jobstart` with a recorder (see M.record_jobstart).
--- Fake job ids start at 100000 so `chansend`/`chanclose`/`jobstop` pass
--- other channels through to the originals.
local RECORD_JOBSTART_LUA = [[
local scripts = ...
local orig = { chansend = vim.fn.chansend, chanclose = vim.fn.chanclose, jobstop = vim.fn.jobstop }
local jobs = {}
JobstartCalls = {}

local function program(cmd)
	return type(cmd) == "table" and cmd[1] or vim.split(cmd, " ", { trimempty = true })[1]
end

local function finish(id, opts, script)
	if script.stdout and opts.on_stdout then opts.on_stdout(id, script.stdout, "stdout") end
	if opts.on_exit then opts.on_exit(id, script.code or 0, "exit") end
	-- queued after anything the callbacks schedule, so it runs once that is done
	vim.schedule(function() LastHandledJob = id end)
end

local held_opts

function FinishHeldJob(script)
	local id, opts = HeldJob, held_opts
	vim.schedule(function() finish(id, opts, script) end)
end

function vim.fn.jobstart(cmd, opts)
	opts = opts or {}
	local id = 100000 + #JobstartCalls
	local call = { cmd = cmd, stdin = "", stopped = false }
	table.insert(JobstartCalls, call)
	jobs[id] = call
	local script = scripts[program(cmd)] or {}
	if script.hold then
		HeldJob, held_opts = id, opts
	else
		vim.schedule(function() finish(id, opts, script) end)
	end
	return id
end

function vim.fn.chansend(id, data)
	if not jobs[id] then return orig.chansend(id, data) end
	jobs[id].stdin = jobs[id].stdin .. (type(data) == "table" and table.concat(data, "\n") or data)
	return #jobs[id].stdin
end

function vim.fn.chanclose(id, ...)
	if not jobs[id] then return orig.chanclose(id, ...) end
	return 1
end

function vim.fn.jobstop(id)
	if not jobs[id] then return orig.jobstop(id) end
	jobs[id].stopped = true
	return 1
end]]

--- Replace `vim.fn.jobstart` in `child` with a recorder: no process is
--- spawned; each call records its command and the stdin sent via `chansend`,
--- then on `vim.schedule` calls `on_stdout` (if scripted) and `on_exit` with
--- the script of the command's program (`cmd[1]`, or the first word of a
--- string command; unscripted programs exit 0 without output). A `hold`
--- script keeps the job running until `M.finish_job`.
---@param child MiniTest.child
---@param scripts? table<string, test.JobScript> program name -> scripted result
---@return fun(): test.JobCall[] calls recorded so far
function M.record_jobstart(child, scripts)
	child.lua(RECORD_JOBSTART_LUA, { scripts or vim.empty_dict() })
	return function()
		return child.lua_get("JobstartCalls")
	end
end

--- Finish the last held job (see M.record_jobstart) with stdout `text`, split
--- into lines as a channel delivers it, and exit `code`; wait until the
--- callbacks and what they scheduled have run.
---@param child test.Child
---@param text string
---@param code integer
function M.finish_job(child, text, code)
	child.lua("FinishHeldJob(...)", { { stdout = vim.split(text, "\n"), code = code } })
	assert(child.wait("LastHandledJob == HeldJob"), "job result was not handled")
end

---@class test.Notification
---@field msg string
---@field level? integer vim.log.levels value

--- Replace `vim.notify` in `child` with a recorder (nothing is shown).
---@param child MiniTest.child
---@return fun(): test.Notification[] notifications recorded so far
function M.record_notify(child)
	child.lua([[
		Notifications = {}
		vim.notify = function(msg, level) table.insert(Notifications, { msg = msg, level = level }) end
	]])
	return function()
		return child.lua_get("Notifications")
	end
end

--- Re-encode attr codes of a screenshot slice so it is independent of rows
--- outside the slice (mini.test numbers attrs in order of appearance).
---@param attr string[][]
---@return string[][]
local function encode_attr(attr)
	local codes, next_code = {}, 48
	return vim.tbl_map(function(line)
		return vim.tbl_map(function(code)
			if not codes[code] then
				codes[code] = string.char(next_code)
				next_code = next_code + 1
			end
			return codes[code]
		end, line)
	end, attr)
end

--- Screenshot of rows `from..to` (negative counts from the bottom).
---@param child MiniTest.child
---@param from integer
---@param to? integer
---@return table screenshot usable with expect.reference_screenshot
function M.screen_rows(child, from, to)
	local full = child.get_screenshot()
	local n = #full.text
	from = from < 0 and n + from + 1 or from
	to = to and (to < 0 and n + to + 1 or to) or from
	local text, attr = {}, {}
	for row = from, to do
		table.insert(text, full.text[row])
		table.insert(attr, full.attr[row])
	end
	full.text, full.attr = text, encode_attr(attr)
	return full
end

---@type string Highlight group of unmasked cells in design-render masks.
M.DEFAULT_GROUP = "Normal"

---@type table<string, true> Mask letters that mean `M.DEFAULT_GROUP`.
M.UNMASKED = { ["."] = true, [" "] = true }

---@class test.CellAttrs
---@field fg? integer
---@field bg? integer
---@field sp? integer
---@field bold? boolean
---@field italic? boolean
---@field underline? boolean
---@field undercurl? boolean
---@field strikethrough? boolean
---@field reverse? boolean

---@class test.ScreenCell
---@field text string
---@field attrs test.CellAttrs

---@class test.ScreenCells
---@field cells test.ScreenCell[][]
---@field hls table<string, test.CellAttrs|vim.NIL>

local CELL_FLAGS = { "bold", "italic", "underline", "undercurl", "strikethrough", "reverse" }
local CELL_COLORS = { "fg", "bg", "sp" }

--- Child-side: the drawn cells of `count` rows from screen row `row` (as in
--- `M.screen_rows`) and the resolved highlights of `groups` (vim.NIL when
--- undefined). Floating multigrid rows are matched to their composed screen
--- text so their resolved attributes replace the underlying grid attributes.
local SCREEN_CELLS_LUA = [[
local row, count, groups, include_floats = ...
local first = row < 0 and vim.o.lines + row or row - 1
local hls = {}
for _, name in ipairs(groups) do
	hls[name] = vim.fn.hlexists(name) == 1 and vim.api.nvim_get_hl(0, { name = name, link = false }) or vim.NIL
end

-- A copy: one float row can match several screen rows, and its attrs table is shared.
local function normalize(attrs)
	local result = vim.deepcopy(attrs)
	result.fg, result.bg, result.sp = attrs.foreground, attrs.background, attrs.special
	result.foreground, result.background, result.special = nil, nil, nil
	return result
end

vim.api.nvim__inspect_cell(1, 0, 0)
vim.cmd("redraw!")
local cells = {}
for r = first, first + count - 1 do
	local line = {}
	for col = 0, vim.o.columns - 1 do
		local inspected = vim.api.nvim__inspect_cell(1, r, col)
		table.insert(line, {
			text = vim.fn.screenstring(r + 1, col + 1),
			attrs = normalize(inspected[2]),
		})
	end
	table.insert(cells, line)
end

local function row_matches(grid_line, screen_line, start)
	for col, inspected in ipairs(grid_line) do
		if inspected[1] ~= screen_line[start + col - 1].text then
			return false
		end
	end
	return true
end

if include_floats then
	local float_sizes = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local config = vim.api.nvim_win_get_config(win)
		if config.relative ~= "" then
			local border = config.border or {}
			local function occupied(...)
				for _, index in ipairs({ ... }) do
					if border[index] and border[index] ~= "" then
						return 1
					end
				end
				return 0
			end
			local width = config.width + occupied(1, 8, 7) + occupied(3, 4, 5)
			local height = config.height + occupied(1, 2, 3) + occupied(5, 6, 7)
			float_sizes[width .. "x" .. height] = true
		end
	end
	local grid = 2
	while grid <= 512 do
		local ok, top_left = pcall(vim.api.nvim__inspect_cell, grid, 0, 0)
		if ok and not vim.tbl_isempty(top_left) then
			local width = 0
			while width < vim.o.columns and not vim.tbl_isempty(vim.api.nvim__inspect_cell(grid, 0, width)) do
				width = width + 1
			end
			local height = 0
			while height < vim.o.lines and not vim.tbl_isempty(vim.api.nvim__inspect_cell(grid, height, 0)) do
				height = height + 1
			end
			for grid_row = 0, float_sizes[width .. "x" .. height] and height - 1 or -1 do
				local first_cell = vim.api.nvim__inspect_cell(grid, grid_row, 0)
				if vim.tbl_isempty(first_cell) then
					break
				end
				local grid_line = {}
				local has_text = false
				for col = 0, width - 1 do
					local inspected = vim.api.nvim__inspect_cell(grid, grid_row, col)
					table.insert(grid_line, inspected)
					has_text = has_text or inspected[1] ~= " "
				end
				if has_text then
					for _, screen_line in ipairs(cells) do
						for start = 1, vim.o.columns - width + 1 do
							if row_matches(grid_line, screen_line, start) then
								for col, inspected in ipairs(grid_line) do
									screen_line[start + col - 1].attrs = normalize(inspected[2])
								end
								break
							end
						end
					end
				end
			end
		end
		grid = grid + 1
	end
	vim.cmd("redraw!")
end
return { cells = cells, hls = hls }]]

---@param mask string[]
---@param columns integer
local function check_width(mask, columns)
	for index, row in ipairs(mask) do
		local width = vim.fn.strchars(row)
		if width ~= columns then
			error(("mask row %d is %d cells wide, screen has %d columns"):format(index, width, columns), 0)
		end
	end
end

---@param mask string[]
---@param legend table<string, string>
local function check_letters(mask, legend)
	for index, row in ipairs(mask) do
		for _, letter in ipairs(vim.fn.split(row, [[\zs]])) do
			if not M.UNMASKED[letter] and not legend[letter] then
				error(("mask row %d: letter %s is not in the legend"):format(index, letter), 0)
			end
		end
	end
end

---@param hls table<string, test.CellAttrs|vim.NIL>
---@param legend table<string, string>
local function check_groups(hls, legend)
	for _, letter in ipairs(vim.tbl_keys(legend)) do
		if hls[legend[letter]] == vim.NIL then
			error(("legend %s: unknown highlight group [%s]"):format(letter, legend[letter]), 0)
		end
	end
end

--- Whether a grid cell shows `hl`: colors only where `hl` sets them (missing
--- drawn colors are Normal's), flags always (absent = false).
---@param attrs test.CellAttrs
---@param hl test.CellAttrs
---@param normal test.CellAttrs
---@return boolean
local function cell_matches(attrs, hl, normal)
	for _, key in ipairs(CELL_COLORS) do
		if hl[key] and hl[key] ~= (attrs[key] or normal[key]) then
			return false
		end
	end
	for _, flag in ipairs(CELL_FLAGS) do
		if (hl[flag] or false) ~= (attrs[flag] or false) then
			return false
		end
	end
	return true
end

---@param cell test.ScreenCell
---@param group string
---@param hls table<string, test.CellAttrs>
---@return boolean
local function cell_matches_group(cell, group, hls)
	return cell_matches(cell.attrs, hls[group], hls[M.DEFAULT_GROUP])
end

---@param cells test.ScreenCell[][]
---@param legend table<string, string>
---@param hls table<string, test.CellAttrs>
---@return string[] mask of the first matching letter per cell, `.` for Normal, else `?`
local function actual_mask(cells, legend, hls)
	local letters = vim.tbl_keys(legend)
	table.sort(letters)
	local mask = {}
	for _, line in ipairs(cells) do
		local row = {}
		for _, cell in ipairs(line) do
			local found = vim.iter(letters):find(function(letter)
				return cell_matches_group(cell, legend[letter], hls)
			end)
			table.insert(row, found or (cell_matches_group(cell, M.DEFAULT_GROUP, hls) and ".") or "?")
		end
		table.insert(mask, table.concat(row))
	end
	return mask
end

---@param attrs test.CellAttrs
---@return string
local function format_attrs(attrs)
	local parts = {}
	for _, key in ipairs(CELL_COLORS) do
		if attrs[key] then
			table.insert(parts, ("%s=#%06x"):format(key, attrs[key]))
		end
	end
	for _, flag in ipairs(CELL_FLAGS) do
		if attrs[flag] then
			table.insert(parts, flag)
		end
	end
	return "{ " .. table.concat(parts, " ") .. " }"
end

---@class test.CellMismatch
---@field row integer 1-based index into the mask
---@field col integer 1-based column
---@field letter string
---@field group string

---@param cells test.ScreenCell[][]
---@param mask string[]
---@param groups table<string, string> mask letter (and unmasked) -> group
---@param hls table<string, test.CellAttrs>
---@param columns integer leading cells of each row to check
---@return test.CellMismatch?
local function first_mismatch(cells, mask, groups, hls, columns)
	for row, line in ipairs(cells) do
		local letters = vim.fn.split(mask[row], [[\zs]])
		for col = 1, math.min(columns, #line) do
			local cell = line[col]
			local group = groups[letters[col]]
			if not cell_matches_group(cell, group, hls) then
				return { row = row, col = col, letter = letters[col], group = group }
			end
		end
	end
end

---@param mask string[]
---@param actual string[]
---@param cells test.ScreenCell[][]
---@param hls table<string, test.CellAttrs>
---@param bad test.CellMismatch
---@return string
local function mismatch_message(mask, actual, cells, hls, bad)
	local lines = { "screen colors differ from the mask:" }
	for row in ipairs(mask) do
		table.insert(lines, "expected: " .. mask[row])
		table.insert(lines, "actual:   " .. actual[row])
	end
	local cell = cells[bad.row][bad.col]
	table.insert(
		lines,
		('mask row %d, column %d "%s": expected %s [%s] %s, drawn %s'):format(
			bad.row,
			bad.col,
			cell.text,
			bad.letter,
			bad.group,
			format_attrs(hls[bad.group]),
			format_attrs(cell.attrs)
		)
	)
	return table.concat(lines, "\n")
end

---@param legend table<string, string>
---@return string[] legend groups plus `M.DEFAULT_GROUP`, once each
local function legend_groups(legend)
	local groups = { [M.DEFAULT_GROUP] = true }
	for _, group in pairs(legend) do
		groups[group] = true
	end
	return vim.tbl_keys(groups)
end

--- Assert the drawn colors of screen rows `row ..` against a design-render
--- mask (one string per row, `columns` cells) and legend (letter -> group).
--- `.` and space are `M.DEFAULT_GROUP`. `opts.columns` checks only that many
--- leading cells of each row (a view whose neighbour another check covers).
---@param child MiniTest.child
---@param row integer as in `M.screen_rows` (negative counts from the bottom)
---@param mask string[]
---@param legend table<string, string>
---@param opts? { columns?: integer }
function M.expect_screen_colors(child, row, mask, legend, opts)
	local columns = child.o.columns
	check_width(mask, columns)
	columns = opts and opts.columns or columns
	check_letters(mask, legend)
	local args = { row, #mask, legend_groups(legend), false }
	local screen = child.lua(SCREEN_CELLS_LUA, args) --[[@as test.ScreenCells]]
	check_groups(screen.hls, legend)
	local hls = screen.hls --[[@as table<string, test.CellAttrs>]]
	if hls[M.DEFAULT_GROUP] == vim.NIL then
		hls[M.DEFAULT_GROUP] = {}
	end
	local letter_groups = vim.tbl_extend("force", { ["."] = M.DEFAULT_GROUP, [" "] = M.DEFAULT_GROUP }, legend)
	local bad = first_mismatch(screen.cells, mask, letter_groups, hls, columns)
	if bad then
		args[4] = true
		screen = child.lua(SCREEN_CELLS_LUA, args) --[[@as test.ScreenCells]]
		bad = first_mismatch(screen.cells, mask, letter_groups, hls, columns)
	end
	if bad then
		local actual = actual_mask(screen.cells, legend, hls)
		error(mismatch_message(mask, actual, screen.cells, hls, bad), 0)
	end
end

--- The drawn cells (text and resolved attributes) of `count` screen rows from
--- `row`, to compare two screens cell for cell.
---@param child MiniTest.child
---@param row integer as in `M.screen_rows` (negative counts from the bottom)
---@param count integer
---@return test.ScreenCell[][]
function M.screen_cells(child, row, count)
	return (child.lua(SCREEN_CELLS_LUA, { row, count, {}, false }) --[[@as test.ScreenCells]]).cells
end

---@class test.HlColors
---@field fg? string `#rrggbb`
---@field bg? string `#rrggbb`
---@field bold? boolean

---@param hl test.CellAttrs
---@return test.HlColors
local function hl_colors(hl)
	---@param color integer?
	local function hex(color)
		return color and ("#%06x"):format(color)
	end
	return { fg = hex(hl.fg), bg = hex(hl.bg), bold = hl.bold or false }
end

--- Pin the resolved colors of highlight `group`: only the keys `expected` sets.
--- Masks compare cells with their own group, so this is what catches a wrong
--- palette color.
---@param child MiniTest.child
---@param group string
---@param expected test.HlColors
function M.expect_hl_colors(child, group, expected)
	local hl = child.lua_get("vim.api.nvim_get_hl(0, { name = ..., link = false })", { group }) --[[@as test.CellAttrs]]
	local actual = hl_colors(hl)
	for key, value in pairs(expected) do
		if actual[key] ~= value then
			error(("[%s] %s: expected %s, got %s"):format(group, key, tostring(value), tostring(actual[key])), 0)
		end
	end
end

--- Lists what is left of the retired neo-tree in the child: its modules, command and windows, `NeoTree*`
--- groups drawn in any buffer or window (the colorscheme may still define them), and mappings naming it.
local NEO_TREE_SURFACE = [[
local found = {}
local function add(item) found[item] = true end
for name in pairs(package.loaded) do
	if name:find("^neo%-tree") then add("module " .. name) end
end
if vim.fn.exists(":Neotree") == 2 then add("command Neotree") end
for _, win in ipairs(vim.api.nvim_list_wins()) do
	local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
	if filetype:find("^neo%-tree") then add("window " .. filetype) end
	if vim.wo[win].winhighlight:find("NeoTree") then add("winhighlight " .. vim.wo[win].winhighlight) end
end
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
		local group = mark[4].hl_group
		if type(group) == "string" and group:find("^NeoTree") then add("highlight " .. group) end
	end
end
for _, mode in ipairs({ "n", "x", "i" }) do
	for _, map in ipairs(vim.list_extend(vim.api.nvim_get_keymap(mode), vim.api.nvim_buf_get_keymap(0, mode))) do
		if ((map.desc or "") .. " " .. (map.rhs or "")):lower():find("neo%-?tree") then
			add("mapping " .. mode .. " " .. map.lhs)
		end
	end
end
local list = vim.tbl_keys(found)
table.sort(list)
return list
]]

--- The project tree replaced neo-tree: no neo-tree module, command, window, drawn highlight or mapping remains.
---@param child MiniTest.child
function M.expect_no_neo_tree(child)
	MiniTest.expect.equality(child.lua(NEO_TREE_SURFACE), {})
end

--- `expect.reference_screenshot` that honours UPDATE_SCREENSHOTS=1.
---@param screenshot table
function M.expect_screenshot(screenshot)
	MiniTest.expect.reference_screenshot(screenshot, nil, { force = vim.env.UPDATE_SCREENSHOTS == "1" })
end

--- Git identity and an empty config, so commits in throwaway repos work without the user's
--- (signing) setup.
---@type table<string, string>
M.GIT_ENV = {
	GIT_AUTHOR_NAME = "test",
	GIT_AUTHOR_EMAIL = "test@example.com",
	GIT_COMMITTER_NAME = "test",
	GIT_COMMITTER_EMAIL = "test@example.com",
	GIT_CONFIG_GLOBAL = "/dev/null",
	GIT_CONFIG_NOSYSTEM = "1",
}

---@class test.SystemResult
---@field code integer
---@field stdout string
---@field stderr string

--- Runs `cmd` in the child via `vim.system` and waits for it.
---@param child MiniTest.child
---@param cmd string[]
---@param cwd string
---@param env? table<string, string>
---@param timeout_ms? integer default 30000; a command that starts other CLIs (codex, claude) needs more under load
---@return test.SystemResult
function M.system(child, cmd, cwd, env, timeout_ms)
	return child.lua_get(
		"vim.system(..., { cwd = select(2, ...), env = select(3, ...), text = true }):wait(select(4, ...))",
		{ cmd, cwd, env or vim.empty_dict(), timeout_ms or 30000 }
	)
end

---@class test.AsyncLspDriver
---@field lua fun(code: string, args?: any[]): any Run Lua in the child Neovim.
---@field wait fun(expr: string, timeout?: integer): boolean Wait until a child expression is truthy.

---@class test.ReferenceReadinessOpts
---@field minimum? integer Minimum number of locations in a qualifying result; default 1.
---@field consecutive? integer Consecutive qualifying results required; default 1.
---@field timeout integer Request and wait bound in milliseconds.
---@field method? string LSP request method; default `textDocument/references`.
---@field retry_content_modified? boolean Retry `content modified` errors until the bound.
---@field capture_error? boolean Store an LSP error message in `_G.references_error`.
---@field exclude_origin? boolean Exclude a result at the requested position.

--- Wait until repeated LSP location requests satisfy the readiness contract.
---@param child test.AsyncLspDriver
---@param server string
---@param opts test.ReferenceReadinessOpts
function M.wait_references_ready(child, server, opts)
	child.lua(
		[[
			local server, opts = ...
			_G.references_ready, _G.references_error, _G.references_result = nil, nil, nil
			local bufnr = vim.api.nvim_get_current_buf()
			local started = vim.uv.hrtime()
			local populated = 0
			local function within_bound()
				return (vim.uv.hrtime() - started) / 1e6 < opts.timeout
			end
			local function request()
				local client = vim.lsp.get_clients({ bufnr = bufnr, name = server })[1]
				local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
				params.context = { includeDeclaration = false }
				client:request(opts.method or "textDocument/references", params, function(err, result)
					if err and opts.retry_content_modified and err.message == "content modified" then
						if within_bound() then vim.defer_fn(request, 10) end
						return
					end
					if err and opts.capture_error then _G.references_error = err.message end
					if opts.exclude_origin then
						result = vim.tbl_filter(function(location)
							local start = location.range.start
							return start.line ~= params.position.line or start.character ~= params.position.character
						end, result or {})
					end
					populated = result and #result >= (opts.minimum or 1) and populated + 1 or 0
					if populated >= (opts.consecutive or 1) then
						_G.references_result = result
						_G.references_ready = true
					elseif within_bound() then
						vim.defer_fn(request, 10)
					end
				end, bufnr)
			end
			request()
		]],
		{ server, opts }
	)
	local condition = opts.capture_error and "_G.references_ready == true or _G.references_error ~= nil"
		or "_G.references_ready == true"
	assert(child.wait(condition, opts.timeout), "references did not become ready")
end

--- Record rust-analyzer's quiescent status while preserving its current handler.
---@param child test.AsyncLspDriver
function M.watch_rust_quiescent(child)
	child.lua([[
		_G.rust_analyzer_quiescent = nil
		local server = require("rustaceanvim.config.internal").server
		server.handlers = server.handlers or {}
		_G.previous_server_status_handler = server.handlers["experimental/serverStatus"]
		server.handlers["experimental/serverStatus"] = function(err, result, context, config)
			if result and result.quiescent then _G.rust_analyzer_quiescent = true end
			local handler = _G.previous_server_status_handler or require("rustaceanvim.server_status").handler
			return handler(err, result, context, config)
		end
	]])
end

--- Wait for rust-analyzer to become quiescent, then restore its status handler.
---@param child test.AsyncLspDriver
---@param timeout integer
function M.wait_rust_quiescent(child, timeout)
	assert(child.wait("_G.rust_analyzer_quiescent == true", timeout), "rust-analyzer did not become quiescent")
	child.lua([[
		require("rustaceanvim.config.internal").server.handlers["experimental/serverStatus"] =
			_G.previous_server_status_handler
		_G.previous_server_status_handler = nil
	]])
end

--- How much slower the host runs than idle: the 1-min load average per CPU, at least 1. Timing
--- checks multiply their deadlines by it; read on each call, so a test can stub `vim.uv.loadavg`.
---@return number
function M.load_factor()
	return math.max(1, vim.uv.loadavg() / vim.uv.available_parallelism())
end

--- How long a test waits for a real language server to attach and answer: `$LSP_TIMEOUT_MS` when it is a
--- positive integer (the loop's gate sets it, since gopls can take minutes to load a module), else `default_ms`.
---@param default_ms integer
---@return integer
function M.lsp_timeout(default_ms)
	local ms = tonumber(vim.env.LSP_TIMEOUT_MS)
	return ms and ms > 0 and math.floor(ms) == ms and ms or default_ms
end

--- Fresh temp directory of the child, as a resolved real path.
---@param child MiniTest.child
---@return string
function M.tempdir(child)
	return child.lua_get(
		"(function() local d = vim.fn.tempname(); vim.fn.mkdir(d, 'p'); return vim.uv.fs_realpath(d) end)()"
	)
end

return M
