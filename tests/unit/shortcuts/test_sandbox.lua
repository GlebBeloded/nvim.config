local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

--- Shell lines that append the log line "$line" with whether $SANDBOX_STATE/lock exists to $LOCK_LOG.
local LOG_LOCK = [[held=no
[ -d "$SANDBOX_STATE/lock" ] && held=yes
printf '%s\t%s\n' "$line" "$held" >>"$LOCK_LOG"
]]

--- `lume` stub: the VM is running at a documentation address. `lume ssh` runs a script from the
--- shared folder: the stub logs that script (the guest command) to $GUEST_LOG and $LOCK_LOG; the
--- guest is provisioned at $PROVISION_REV and its GUI session belongs to `lume`. `lume stop` logs
--- whether the locker writing $HOLDER_LOG had left by then, and the VM reports stopped afterwards.
--- `lume run` leaves a live run process ($SANDBOX_STATE/run-alive, seen by the pgrep stub); its first
--- $LUME_MISMATCH_RUNS runs leave the VM reported stopped (Lume lost track), later ones running.
--- `lume ssh` refuses while the VM is reported stopped.
local LUME_STUB = [[#!/bin/sh
echo "lume $*" >>"$GUEST_LOG"
case "$1" in
get)
	empty=$(cat "$SANDBOX_STATE/get-empty" 2>/dev/null || echo 0)
	[ "$empty" -gt 0 ] && { echo $((empty - 1)) >"$SANDBOX_STATE/get-empty"; exit 1; }
	status=running
	[ -f "$SANDBOX_STATE/stopped" ] && status=stopped
	echo '{"name":"nvim-e2e","status":"'$status'","ipAddress":"192.0.2.1"}'
	;;
ls)
	echo "name status"
	echo "nvim-e2e running"
	;;
stop)
	left=no
	grep -q '^left' "${HOLDER_LOG:-/dev/null}" 2>/dev/null && left=yes
	echo "stop holder-left=$left" >>"$GUEST_LOG"
	touch "$SANDBOX_STATE/stopped"
	;;
run)
	runs=$(($(cat "$SANDBOX_STATE/runs" 2>/dev/null || echo 0) + 1))
	echo "$runs" >"$SANDBOX_STATE/runs"
	touch "$SANDBOX_STATE/run-alive"
	[ "$runs" -gt "${LUME_MISMATCH_RUNS:-0}" ] && rm -f "$SANDBOX_STATE/stopped"
	;;
ssh)
	[ -f "$SANDBOX_STATE/stopped" ] && { echo "Error: VM 'nvim-e2e' is not running" >&2; exit 1; }
	for last; do :; done
	case "$last" in *"test -d"*SHARED*) echo SHARED; exit 0 ;; esac
	script=$(printf '%s' "$last" | sed -n "s|^bash '/Volumes/My Shared Files/share/\([^']*\)'.*|\1|p")
	[ -n "$script" ] || exit 0
	line=$(cat "$SANDBOX_STATE/share/$script")
	echo "$line" >>"$GUEST_LOG"
]] .. LOG_LOCK .. [[
	case "$line" in
	"cat ~/.nvim-e2e-provisioned"*) echo "$PROVISION_REV" ;;
	"stat -f %Su /dev/console") echo lume ;;
	esac
	;;
esac
exit 0
]]

--- `ssh` stub: the host never runs ssh to the guest; any call is logged as HOST-SSH.
local SSH_STUB = [[#!/bin/sh
echo "HOST-SSH $*" >>"$GUEST_LOG"
exit 99
]]

--- `rsync` stub (host-side copies into the shared folder only): logs `rsync <dest>`.
local RSYNC_STUB = [[#!/bin/sh
for dest; do :; done
echo "rsync $dest" >>"$GUEST_LOG"
exit 0
]]

--- `pgrep` / `pkill` stubs: the `lume run` process is $SANDBOX_STATE/run-alive; pkill removes it.
--- Nothing real is ever signalled.
local PGREP_STUB = [[#!/bin/sh
echo "pgrep $*" >>"$GUEST_LOG"
[ -f "$SANDBOX_STATE/run-alive" ]
]]
local PKILL_STUB = [[#!/bin/sh
echo "pkill $*" >>"$GUEST_LOG"
[ -f "$SANDBOX_STATE/run-alive" ] || exit 1
rm -f "$SANDBOX_STATE/run-alive"
]]

--- `nc` stub (the SSH port check): logs `nc closed|open <args>`; its first $NC_CLOSED calls
--- report the port closed, later ones open.
local NC_STUB = [[#!/bin/sh
n=$(($(cat "$SANDBOX_STATE/nc-calls" 2>/dev/null || echo 0) + 1))
echo "$n" >"$SANDBOX_STATE/nc-calls"
if [ "$n" -le "${NC_CLOSED:-0}" ]; then
	echo "nc closed $*" >>"$GUEST_LOG"
	exit 1
fi
echo "nc open $*" >>"$GUEST_LOG"
]]

--- `sysctl` stub: not inside a VM.
local SYSCTL_STUB = [[#!/bin/sh
echo 0
]]

---@param path string
---@param content string
local function write_executable(path, content)
	child.lua("vim.fn.writefile(vim.split(..., '\\n'), select(2, ...)); vim.uv.fs_chmod(select(2, ...), 493)", {
		content,
		path,
	})
end

---@param cmd string[]
---@param cwd string
---@param env? table<string, string>
---@return { code: integer, stdout: string, stderr: string }
local function system(cmd, cwd, env)
	-- the restart paths take ~12 s on an idle host; scale the budget so a loaded gate does not cut them off
	local timeout = math.ceil(60000 * H.load_factor())
	return child.lua_get(
		"vim.system(..., { cwd = select(2, ...), env = select(3, ...), text = true }):wait(select(4, ...))",
		{
			cmd,
			cwd,
			env or vim.empty_dict(),
			timeout,
		}
	)
end

---@return string
local function tempdir()
	return child.lua_get(
		"(function() local d = vim.fn.tempname(); vim.fn.mkdir(d, 'p'); return vim.uv.fs_realpath(d) end)()"
	)
end

--- {} when `path` is missing, also when it disappears between check and read (lock.sh moves a stale lock aside).
local READ_LINES = [[(function(path)
	local ok, lines = pcall(vim.fn.readfile, path)
	return ok and lines or {}
end)(...)]]

---@param path string
---@return string[]
local function read_lines(path)
	return child.lua_get(READ_LINES, { path })
end

--- PROVISION_REV as tests/sandbox/sandbox.sh defines it.
---@return string
local function provision_rev()
	local source = table.concat(read_lines(vim.fs.joinpath(H.root, "tests/sandbox/sandbox.sh")), "\n")
	return assert(source:match("\nPROVISION_REV=(%d+)"))
end

--- Env with the `lume`, `ssh`, `rsync`, `nc`, `sysctl`, `pgrep` and `pkill` stubs first on PATH, a temp SANDBOX_STATE,
--- a temp HOME and plugin dir, and no e2e selection from the caller.
---@return table<string, string>
local function sandbox_env()
	local bin, state, data = tempdir(), tempdir(), tempdir()
	write_executable(vim.fs.joinpath(bin, "lume"), LUME_STUB)
	write_executable(vim.fs.joinpath(bin, "ssh"), SSH_STUB)
	write_executable(vim.fs.joinpath(bin, "rsync"), RSYNC_STUB)
	write_executable(vim.fs.joinpath(bin, "sysctl"), SYSCTL_STUB)
	write_executable(vim.fs.joinpath(bin, "nc"), NC_STUB)
	write_executable(vim.fs.joinpath(bin, "pgrep"), PGREP_STUB)
	write_executable(vim.fs.joinpath(bin, "pkill"), PKILL_STUB)
	child.fn.mkdir(vim.fs.joinpath(data, "lazy"), "p")
	child.fn.mkdir(vim.fs.joinpath(data, "site"), "p")
	return {
		PATH = bin .. ":" .. child.lua_get("vim.env.PATH"),
		GUEST_LOG = vim.fs.joinpath(bin, "guest.log"),
		LOCK_LOG = vim.fs.joinpath(bin, "lock.log"),
		PROVISION_REV = provision_rev(),
		SANDBOX_STATE = state,
		HOME = tempdir(),
		NVIM_TEST_DATA_DIR = data,
		CASE = "",
		E2E_FOCUS = "",
		E2E = "",
		-- `make check` exports these for the real sandbox; the stubbed one must not inherit them
		SANDBOX_START = "1",
		CHECK_LOCK_HOLDER = "",
	}
end

--- Index of the first line in `lines` that `matches`, or nil.
---@param lines string[]
---@param matches fun(line: string): boolean
---@return integer?
local function first_index(lines, matches)
	for i, line in ipairs(lines) do
		if matches(line) then
			return i
		end
	end
end

--- Temp checkout with this repo's guest_restore.sh and a `terminal/` holding only `setup`
--- (as `terminal/macos_test.sh`), if given; returns the restore script path.
---@param setup? string
---@return string
local function make_checkout(setup)
	local root = tempdir()
	local sandbox = vim.fs.joinpath(root, "tests/sandbox")
	child.fn.mkdir(sandbox, "p")
	child.fn.mkdir(vim.fs.joinpath(root, "terminal"), "p")
	local script = vim.fs.joinpath(sandbox, "guest_restore.sh")
	child.lua("assert(vim.uv.fs_copyfile(...))", { vim.fs.joinpath(H.root, "tests/sandbox/guest_restore.sh"), script })
	if setup then
		write_executable(vim.fs.joinpath(root, "terminal/macos_test.sh"), setup)
	end
	return script
end

---@return string
local function temp_plist()
	return vim.fs.joinpath(tempdir(), "org.alacritty.plist")
end

--- Bash that takes `sandbox_lock "$1"` from tests/sandbox/lock.sh, appends the time it got it to
--- "$2", and holds the lock for "$3" s; just before exiting it appends its leaving time to "$2".
local LOCK_SCRIPT = [[source "$LOCK_SH"
sandbox_lock "$1"
now() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time'; }
owner=$(head -1 "$1/owner")
echo "got $(now) ${owner%% *}" >>"$2"
sleep "$3"
echo "left $(now)" >>"$2"
]]

---@class SandboxLocker
---@field pid integer
---@field log string the `got <time> <pid>` / `left <time>` lines

--- Starts LOCK_SCRIPT on `dir` in the background, holding the lock `hold` s; `name` keys it in the child.
---@param name string
---@param dir string
---@param hold number
---@param env? table<string, string>
---@return SandboxLocker
local function start_locker(name, dir, hold, env)
	local log = vim.fs.joinpath(tempdir(), "times")
	local pid = child.lua_get(
		[[(function(name, cmd, env)
			_G.lockers = _G.lockers or {}
			_G.lockers[name] = vim.system(cmd, { env = env, text = true })
			return _G.lockers[name].pid
		end)(...)]],
		{
			name,
			{ "bash", "-c", LOCK_SCRIPT, "_", dir, log, tostring(hold) },
			vim.tbl_extend("force", { LOCK_SH = vim.fs.joinpath(H.root, "tests/sandbox/lock.sh") }, env or {}),
		}
	)
	return { pid = pid, log = log }
end

--- Waits for the locker `name` to exit.
---@param name string
---@return { code: integer, stdout: string, stderr: string }
local function wait_locker(name)
	return child.lua_get("_G.lockers[...]:wait(select(2, ...))", { name, math.ceil(30000 * H.load_factor()) })
end

--- The `owner` pid recorded in lock dir `dir`, or nil.
---@param dir string
---@return integer?
local function lock_owner(dir)
	local lines = read_lines(vim.fs.joinpath(dir, "owner"))
	return lines[1] and tonumber(lines[1]:match("^(%d+)"))
end

--- Waits until lock dir `dir` names `pid` as owner.
---@param dir string
---@param pid integer
local function wait_owner(dir, pid)
	local named = [[(function(owner, pid, timeout)
		local function names_pid()
			local ok, lines = pcall(vim.fn.readfile, owner) -- the reclaimer may move it away mid-read: retry
			return ok and (lines[1] or ""):match("^%d+") == pid
		end
		return vim.wait(timeout, names_pid, 20)
	end)(...)]]
	eq(child.lua_get(named, { vim.fs.joinpath(dir, "owner"), tostring(pid), math.ceil(5000 * H.load_factor()) }), true)
end

--- The time (s) on the `kind` line of a locker log.
---@param log string
---@param kind "got"|"left"
---@return number?
local function locker_time(log, kind)
	for _, line in ipairs(read_lines(log)) do
		local time = line:match("^" .. kind .. " ([%d.]+)$") or line:match("^" .. kind .. " ([%d.]+) %d+$")
		if time then
			return tonumber(time)
		end
	end
end

--- The owner pid persisted on the `got` line of a locker log.
---@param log string
---@return integer?
local function locker_owner(log)
	for _, line in ipairs(read_lines(log)) do
		local owner = line:match("^got [%d.]+ (%d+)$")
		if owner then
			return tonumber(owner)
		end
	end
end

---@return number ms
local function now_ms()
	return child.lua_get("vim.uv.hrtime() / 1e6")
end

T["shortcuts: The sandbox lock is taken when free and released by its owner"] = function()
	local dir = vim.fs.joinpath(tempdir(), "lock")

	local locker = start_locker("holder", dir, 1)
	wait_owner(dir, locker.pid)
	local held = child.fn.isdirectory(dir)
	local result = wait_locker("holder")

	eq({ held = held, code = result.code, stderr = result.stderr }, { held = 1, code = 0, stderr = "" })
	eq(child.fn.isdirectory(dir), 0)
end

T["shortcuts: A second sandbox lock waits for the first and says so"] = function()
	local dir = vim.fs.joinpath(tempdir(), "lock")
	local holder = start_locker("holder", dir, 2)
	wait_owner(dir, holder.pid)

	local waiter = start_locker("waiter", dir, 0.5)
	local holder_result, waiter_result = wait_locker("holder"), wait_locker("waiter")

	eq({ holder_result.code, waiter_result.code, locker_owner(waiter.log) }, { 0, 0, waiter.pid })
	eq(waiter_result.stderr:find("sandbox: waiting for", 1, true) ~= nil, true)
	eq(waiter_result.stderr:find("pid " .. holder.pid, 1, true) ~= nil, true)
	local left, got = locker_time(holder.log, "left"), locker_time(waiter.log, "got")
	eq({ left ~= nil, got ~= nil }, { true, true })
	eq(got >= left, true)
end

T["shortcuts: A sandbox lock left by a dead process is reclaimed"] = function()
	local dir = vim.fs.joinpath(tempdir(), "lock")
	local dead = tonumber(vim.trim(system({ "sh", "-c", "echo $$" }, H.root).stdout))
	child.fn.mkdir(dir, "p")
	child.fn.writefile({ dead .. " Thu Jan  1 00:00:00 1970", "/nowhere" }, vim.fs.joinpath(dir, "owner"))
	local t0 = now_ms()

	local locker = start_locker("reclaimer", dir, 3)
	wait_owner(dir, locker.pid)
	local elapsed = now_ms() - t0
	local result = wait_locker("reclaimer")

	-- reclaimed at once, never after a poll sleep: the waiting message precedes every sleep (lock.sh)
	eq(elapsed < 2000 * H.load_factor(), true, { fail_reason = ("took %d ms"):format(elapsed) })
	eq(result.stderr:find("sandbox: reclaiming stale lock", 1, true) ~= nil, true)
	eq(result.stderr:find("sandbox: waiting for", 1, true), nil)
end

T["shortcuts: A sandbox lock wait gives up after SANDBOX_LOCK_TIMEOUT"] = function()
	local dir = vim.fs.joinpath(tempdir(), "lock")
	local holder = start_locker("holder", dir, 4)
	wait_owner(dir, holder.pid)
	local t0 = now_ms()

	start_locker("waiter", dir, 0, { SANDBOX_LOCK_TIMEOUT = "1", SANDBOX_LOCK_POLL = "0.2" })
	local result = wait_locker("waiter")
	local elapsed = now_ms() - t0

	MiniTest.expect.no_equality(result.code, 0)
	eq(
		{ at_least_timeout = elapsed >= 1000, within_bound = elapsed < 5000 },
		{ at_least_timeout = true, within_bound = true }
	)
	eq(result.stderr:find("pid " .. holder.pid, 1, true) ~= nil, true)
	eq(lock_owner(dir), holder.pid)
	eq(wait_locker("holder").code, 0)
end

---@param line string
---@return boolean
local function is_repo_sync(line)
	return line:find("'/Volumes/My Shared Files/share/sync%.[^/]+/repo/' /Users/lume/nvim/") ~= nil
end

---@param line string
---@return boolean
local function is_restore(line)
	return line:find("tests/sandbox/guest_restore.sh", 1, true) ~= nil
end

---@param line string
---@return boolean
local function is_e2e_layer(line)
	-- `gui` quotes the command with printf %q; the guest shell unescapes it
	return line:gsub("\\ ", " "):find("make -s e2e-local", 1, true) ~= nil
end

--- Expects the repo sync, then the guest restore, then the e2e layer in a guest log.
---@param log string[]
local function expect_sync_restore_e2e(log)
	local order = {
		sync = first_index(log, is_repo_sync),
		restore = first_index(log, is_restore),
		e2e = first_index(log, is_e2e_layer),
	}
	eq({ order.sync ~= nil, order.restore ~= nil, order.e2e ~= nil }, { true, true, true })
	eq({ order.sync < order.restore, order.restore < order.e2e }, { true, true })
end

--- Whether the lock existed (`yes`/`no`) at the first $LOCK_LOG line that `matches`, or nil.
---@param lock_log string[]
---@param matches fun(line: string): boolean
---@return string?
local function lock_state_at(lock_log, matches)
	for _, entry in ipairs(lock_log) do
		local line, held = entry:match("^(.*)\t(%a+)$")
		if line and matches(line) then
			return held
		end
	end
end

T["shortcuts: Guest restore drops Alacritty defaults the branch does not define"] = function()
	local script = make_checkout()
	local plist = temp_plist()
	local seed = system({
		"defaults",
		"write",
		plist,
		"NSUserKeyEquivalents",
		"-dict-add",
		"Quit alacritty",
		"@~^q",
		"Hide alacritty",
		"@~^h",
	}, H.root)
	eq(seed.code, 0)

	local restore = system({ script, plist }, H.root)

	eq({ code = restore.code, stderr = restore.stderr }, { code = 0, stderr = "" })
	MiniTest.expect.no_equality(system({ "defaults", "read", plist, "NSUserKeyEquivalents" }, H.root).code, 0)
end

T["shortcuts: Guest restore applies the branch's own terminal setup"] = function()
	local script = make_checkout('#!/bin/sh\ndefaults write "$1" TestKey -string fresh')
	local plist = temp_plist()

	local restore = system({ script, plist }, H.root)

	eq({ code = restore.code, stderr = restore.stderr }, { code = 0, stderr = "" })
	local exported = system({ "sh", "-c", 'defaults export "$1" - | plutil -convert json -o - -', "sh", plist }, H.root)
	eq(exported.code, 0)
	eq(vim.json.decode(exported.stdout), { TestKey = "fresh" })
end

T["shortcuts: sandbox.sh e2e restores guest state after syncing and before the e2e layer"] = function()
	local env = sandbox_env()

	local run = system({ "tests/sandbox/sandbox.sh", "e2e" }, H.root, env)

	eq(run.code, 0)
	expect_sync_restore_e2e(read_lines(env.GUEST_LOG))
end

T["shortcuts: sandbox.sh e2e talks to the guest only through Lume"] = function()
	local env = sandbox_env()

	local run = system({ "tests/sandbox/sandbox.sh", "e2e" }, H.root, env)

	eq(run.code, 0)
	local log = read_lines(env.GUEST_LOG)
	local host_ssh = vim.tbl_filter(function(line)
		return vim.startswith(line, "HOST-SSH")
	end, log)
	local lume_args = vim.tbl_filter(function(line)
		return vim.startswith(line, "lume ssh") and line:find("guest_restore", 1, true) ~= nil
	end, log)
	eq(
		{ host_ssh = host_ssh, guest_command_on_host_argv = lume_args },
		{ host_ssh = {}, guest_command_on_host_argv = {} }
	)
end

T["shortcuts: sandbox.sh e2e holds the sandbox lock from the sync to the end of the e2e layer"] = function()
	local env = sandbox_env()

	local run = system({ "tests/sandbox/sandbox.sh", "e2e" }, H.root, env)

	eq(run.code, 0)
	local lock_log = read_lines(env.LOCK_LOG)
	eq({ sync = lock_state_at(lock_log, is_repo_sync), e2e = lock_state_at(lock_log, is_e2e_layer) }, {
		sync = "yes",
		e2e = "yes",
	})
	eq(child.fn.isdirectory(vim.fs.joinpath(env.SANDBOX_STATE, "lock")), 0)
end

T["shortcuts: sandbox.sh e2e waits while another checkout holds the sandbox lock"] = function()
	local env = sandbox_env()
	local dir = vim.fs.joinpath(env.SANDBOX_STATE, "lock")
	local holder = start_locker("holder", dir, 2)
	wait_owner(dir, holder.pid)

	child.lua("_G.e2e_run = vim.system(..., { cwd = select(2, ...), env = select(3, ...), text = true })", {
		{ "tests/sandbox/sandbox.sh", "e2e" },
		H.root,
		env,
	})
	vim.uv.sleep(1000)
	local synced_early = first_index(read_lines(env.GUEST_LOG), is_repo_sync) ~= nil
	local run = child.lua_get("_G.e2e_run:wait(30000)")

	eq({ synced_early = synced_early, code = run.code }, { synced_early = false, code = 0 })
	eq(run.stderr:find("sandbox: waiting for", 1, true) ~= nil, true)
	expect_sync_restore_e2e(read_lines(env.GUEST_LOG))
	eq(wait_locker("holder").code, 0)
end

T["shortcuts: sandbox.sh down never stops the VM while another checkout holds the sandbox lock"] = function()
	local env = sandbox_env()
	local dir = vim.fs.joinpath(env.SANDBOX_STATE, "lock")
	local holder = start_locker("holder", dir, 2)
	wait_owner(dir, holder.pid)
	env.HOLDER_LOG = holder.log

	local run = system({ "tests/sandbox/sandbox.sh", "down" }, H.root, env)
	eq(run.code, 0, { fail_reason = run.stdout .. run.stderr })
	local wait_line = ("sandbox: waiting for sandbox lock held by pid %d ("):format(holder.pid)
	eq(run.stderr:find(wait_line, 1, true) ~= nil, true, { fail_reason = run.stderr })
	local stops = vim.tbl_filter(function(line)
		return vim.startswith(line, "stop holder-left=")
	end, read_lines(env.GUEST_LOG))
	eq(stops, { "stop holder-left=yes" })
	eq(wait_locker("holder").code, 0)
	eq(child.fn.isdirectory(dir), 0)
end

--- The `lume run` and `pkill -TERM` lines of a guest log, in order.
---@param log string[]
---@return string[]
local function run_and_kill_lines(log)
	return vim.tbl_filter(function(line)
		return vim.startswith(line, "lume run ") or vim.startswith(line, "pkill -TERM")
	end, log)
end

T["shortcuts: sandbox.sh never pulls an image when lume get blips"] = function()
	local env = sandbox_env()
	child.fn.writefile({ "2" }, vim.fs.joinpath(env.SANDBOX_STATE, "get-empty"))

	local run = system({ "tests/sandbox/sandbox.sh", "e2e" }, H.root, env)

	eq(run.code, 0, { fail_reason = run.stderr })
	eq(run.stderr:find("pulling", 1, true), nil)
	eq(
		first_index(read_lines(env.GUEST_LOG), function(line)
			return vim.startswith(line, "lume pull")
		end),
		nil
	)
end

T["shortcuts: sandbox.sh restarts a VM Lume reports stopped while its lume run lives"] = function()
	local env = vim.tbl_extend("force", sandbox_env(), { SANDBOX_MISMATCH_S = "1" })
	child.fn.writefile({}, vim.fs.joinpath(env.SANDBOX_STATE, "stopped"))
	child.fn.writefile({}, vim.fs.joinpath(env.SANDBOX_STATE, "run-alive"))

	local run = system({ "tests/sandbox/sandbox.sh", "e2e" }, H.root, env)

	eq(run.code, 0, { fail_reason = run.stderr })
	MiniTest.expect.no_equality(run.stderr:find("killing it and booting once more", 1, true), nil)
	local log = read_lines(env.GUEST_LOG)
	local lines = run_and_kill_lines(log)
	eq(#lines, 2, { fail_reason = table.concat(lines, "\n") })
	eq({ vim.startswith(lines[1], "pkill -TERM"), vim.startswith(lines[2], "lume run nvim-e2e --no-display") }, {
		true,
		true,
	})
	eq(lines[2]:find("--detach", 1, true), nil)
	-- no VNC server: lume would otherwise write its VNC config into the guest over host ssh at boot
	eq(lines[2]:find("--vnc disabled", 1, true) ~= nil, true)
	eq(first_index(log, is_e2e_layer) ~= nil, true)
end

T["shortcuts: sandbox.sh gives up when Lume loses track of the VM again after one restart"] = function()
	local env = vim.tbl_extend("force", sandbox_env(), { SANDBOX_MISMATCH_S = "1", LUME_MISMATCH_RUNS = "2" })
	child.fn.writefile({}, vim.fs.joinpath(env.SANDBOX_STATE, "stopped"))

	local run = system({ "tests/sandbox/sandbox.sh", "e2e" }, H.root, env)

	MiniTest.expect.no_equality(run.code, 0)
	MiniTest.expect.no_equality(run.stderr:find("after one restart; giving up", 1, true), nil)
	local lines = run_and_kill_lines(read_lines(env.GUEST_LOG))
	eq(#lines, 3, { fail_reason = table.concat(lines, "\n") })
	eq({
		vim.startswith(lines[1], "lume run "),
		vim.startswith(lines[2], "pkill -TERM"),
		vim.startswith(lines[3], "lume run "),
	}, { true, true, true })
	local log = read_lines(env.GUEST_LOG)
	eq(first_index(log, is_e2e_layer), nil)
end

T["shortcuts: sandbox.sh calls lume ssh after a boot only once the guest's SSH port is open"] = function()
	local env = vim.tbl_extend("force", sandbox_env(), { NC_CLOSED = "2" })
	child.fn.writefile({}, vim.fs.joinpath(env.SANDBOX_STATE, "stopped"))

	local run = system({ "tests/sandbox/sandbox.sh", "e2e" }, H.root, env)

	eq(run.code, 0, { fail_reason = run.stderr })
	local log = read_lines(env.GUEST_LOG)
	local function starts(prefix)
		return function(line)
			return vim.startswith(line, prefix)
		end
	end
	local closed = vim.tbl_filter(starts("nc closed"), log)
	eq(closed, { "nc closed -z -G 2 192.0.2.1 22", "nc closed -z -G 2 192.0.2.1 22" })
	local boot, open, ssh =
		first_index(log, starts("lume run ")), first_index(log, starts("nc open")), first_index(log, starts("lume ssh"))
	eq({ boot = boot ~= nil, open = open ~= nil, ssh = ssh ~= nil }, { boot = true, open = true, ssh = true })
	eq({ booted_first = boot < open, port_before_ssh = open < ssh }, { booted_first = true, port_before_ssh = true })
	eq(first_index(log, is_e2e_layer) ~= nil, true)
end

--- `make` stub for tests/check.sh: `deps` passes; every other target appends "<target> start
--- <held>" and "<target> end" to $MAKE_LOG, held = whether $CHECK_LOCK_DIR exists. Target `slow`
--- lasts 2 s; `nested` runs tests/check.sh `inner` with CHECK_LOCK_TIMEOUT=1 and returns its code.
local MAKE_STUB = [[#!/bin/sh
target=$2
[ "$target" = deps ] && exit 0
held=no
[ -d "$CHECK_LOCK_DIR" ] && held=yes
echo "$target start $held" >>"$MAKE_LOG"
rc=0
case "$target" in
slow) sleep 2 ;;
nested) CHECK_LOCK_TIMEOUT=1 "$CHECK_SH" inner >>"$MAKE_LOG.nested" 2>&1 || rc=$? ;;
esac
echo "$target end" >>"$MAKE_LOG"
exit $rc
]]

--- Env for tests/check.sh with the `make` stub, a temp check lock and no inherited lock holder
--- (the suite itself may run under `make check`).
---@return table<string, string>
local function check_env()
	local bin = tempdir()
	write_executable(vim.fs.joinpath(bin, "make"), MAKE_STUB)
	return {
		MAKE = vim.fs.joinpath(bin, "make"),
		MAKE_LOG = vim.fs.joinpath(bin, "make.log"),
		CHECK_SH = vim.fs.joinpath(H.root, "tests/check.sh"),
		CHECK_LOCK_DIR = vim.fs.joinpath(tempdir(), "check-lock"),
		CHECK_LOCK = "1",
		CHECK_LOCK_HOLDER = "",
		CHECK_LOCK_POLL = "0.2",
	}
end

--- Starts tests/check.sh `targets` in the background; `name` keys it for wait_locker.
---@param name string
---@param targets string[]
---@param env table<string, string>
---@return integer pid
local function start_check(name, targets, env)
	local cmd = vim.list_extend({ "tests/check.sh" }, targets)
	return child.lua_get(
		[[(function(name, cmd, cwd, env)
			_G.lockers = _G.lockers or {}
			_G.lockers[name] = vim.system(cmd, { cwd = cwd, env = env, text = true })
			return _G.lockers[name].pid
		end)(...)]],
		{ name, cmd, H.root, env }
	)
end

T["shortcuts: make check holds the check lock for its whole run"] = function()
	local env = check_env()

	local run = system({ "tests/check.sh", "a", "b", "+c" }, H.root, env)

	eq(run.code, 0, { fail_reason = run.stdout .. run.stderr })
	local starts = vim.tbl_filter(function(line)
		return line:find(" start ", 1, true) ~= nil
	end, read_lines(env.MAKE_LOG))
	table.sort(starts)
	eq(starts, { "a start yes", "b start yes", "c start yes" })
	eq(child.fn.isdirectory(env.CHECK_LOCK_DIR), 0)
end

T["shortcuts: A second make check waits for the check lock and says so"] = function()
	local env = check_env()
	local holder = start_check("holder", { "slow" }, env)
	wait_owner(env.CHECK_LOCK_DIR, holder)

	local run = system({ "tests/check.sh", "a" }, H.root, env)

	eq(run.code, 0, { fail_reason = run.stdout .. run.stderr })
	local wait_line = ("check: waiting for the check lock held by pid %d ("):format(holder)
	eq(run.stderr:find(wait_line, 1, true) ~= nil, true, { fail_reason = run.stderr })
	eq(wait_locker("holder").code, 0)
	local log = read_lines(env.MAKE_LOG)
	local slow_end = first_index(log, function(line)
		return line == "slow end"
	end)
	local a_start = first_index(log, function(line)
		return vim.startswith(line, "a start")
	end)
	eq({ slow_end ~= nil, a_start ~= nil }, { true, true })
	eq(slow_end < a_start, true, { fail_reason = table.concat(log, "\n") })
end

T["shortcuts: A make check run inside a make check does not wait for its own lock"] = function()
	local env = check_env()

	local run = system({ "tests/check.sh", "nested" }, H.root, env)

	local nested = table.concat(read_lines(env.MAKE_LOG .. ".nested"), "\n")
	eq(run.code, 0, { fail_reason = run.stdout .. run.stderr .. nested })
	eq(nested:find("waiting for", 1, true), nil, { fail_reason = nested })
	eq(vim.list_contains(read_lines(env.MAKE_LOG), "inner start yes"), true)
	eq(child.fn.isdirectory(env.CHECK_LOCK_DIR), 0)
end

T["shortcuts: CHECK_LOCK=0 runs make check without the check lock"] = function()
	local env = check_env()
	local holder = start_locker("holder", env.CHECK_LOCK_DIR, 4)
	wait_owner(env.CHECK_LOCK_DIR, holder.pid)
	env.CHECK_LOCK = "0"

	local run = system({ "tests/check.sh", "a" }, H.root, env)

	eq(run.code, 0, { fail_reason = run.stdout .. run.stderr })
	eq(run.stderr:find("waiting for", 1, true), nil, { fail_reason = run.stderr })
	eq(locker_time(holder.log, "left"), nil)
	eq(lock_owner(env.CHECK_LOCK_DIR), holder.pid)
	eq(wait_locker("holder").code, 0)
end

return T
