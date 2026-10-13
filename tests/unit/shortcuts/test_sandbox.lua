local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

--- `lume` stub: the VM is running at a documentation address.
local LUME_STUB = [[#!/bin/sh
echo "lume $*" >>"$GUEST_LOG"
case "$1" in
get) echo '{"name":"nvim-e2e","status":"running","ipAddress":"192.0.2.1"}' ;;
esac
exit 0
]]

--- Shell lines that append the log line "$line" with whether $SANDBOX_STATE/lock exists to $LOCK_LOG.
local LOG_LOCK = [[held=no
[ -d "$SANDBOX_STATE/lock" ] && held=yes
printf '%s\t%s\n' "$line" "$held" >>"$LOCK_LOG"
]]

--- `ssh` stub: logs the guest command (last argument), also to $LOCK_LOG with the lock state;
--- the guest is provisioned at $PROVISION_REV and its GUI session belongs to `lume`.
local SSH_STUB = [[#!/bin/sh
for cmd; do :; done
line=$cmd
echo "$line" >>"$GUEST_LOG"
]] .. LOG_LOCK .. [[
case "$cmd" in
"cat ~/.nvim-e2e-provisioned"*) echo "$PROVISION_REV" ;;
"stat -f %Su /dev/console") echo lume ;;
esac
exit 0
]]

--- `rsync` stub: logs `rsync <dest>`, also to $LOCK_LOG with the lock state.
local RSYNC_STUB = [[#!/bin/sh
for dest; do :; done
line="rsync $dest"
echo "$line" >>"$GUEST_LOG"
]] .. LOG_LOCK .. [[
exit 0
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
	return child.lua_get("vim.system(..., { cwd = select(2, ...), env = select(3, ...), text = true }):wait(30000)", {
		cmd,
		cwd,
		env or vim.empty_dict(),
	})
end

---@return string
local function tempdir()
	return child.lua_get(
		"(function() local d = vim.fn.tempname(); vim.fn.mkdir(d, 'p'); return vim.uv.fs_realpath(d) end)()"
	)
end

---@param path string
---@return string[]
local function read_lines(path)
	return child.lua_get("vim.fn.filereadable(...) == 1 and vim.fn.readfile(...) or {}", { path })
end

--- PROVISION_REV as tests/sandbox/sandbox.sh defines it.
---@return string
local function provision_rev()
	local source = table.concat(read_lines(vim.fs.joinpath(H.root, "tests/sandbox/sandbox.sh")), "\n")
	return assert(source:match("\nPROVISION_REV=(%d+)"))
end

--- Env with the `lume`, `ssh`, `rsync` and `sysctl` stubs first on PATH, a pre-made SSH key in
--- a temp SANDBOX_STATE, a temp HOME and plugin dir, and no e2e selection from the caller.
---@return table<string, string>
local function sandbox_env()
	local bin, state, data = tempdir(), tempdir(), tempdir()
	write_executable(vim.fs.joinpath(bin, "lume"), LUME_STUB)
	write_executable(vim.fs.joinpath(bin, "ssh"), SSH_STUB)
	write_executable(vim.fs.joinpath(bin, "rsync"), RSYNC_STUB)
	write_executable(vim.fs.joinpath(bin, "sysctl"), SYSCTL_STUB)
	for _, key in ipairs({ "id_ed25519", "id_ed25519.pub" }) do
		child.fn.writefile({}, vim.fs.joinpath(state, key))
	end
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
			return vim.fn.filereadable(owner) == 1 and (vim.fn.readfile(owner)[1] or ""):match("^%d+") == pid
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
	local holder = start_locker("holder", dir, 2 * H.load_factor())
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

	eq(elapsed < 2000 * H.load_factor(), true)
	eq(result.stderr:find("sandbox: reclaiming stale lock", 1, true) ~= nil, true)
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
		{ at_least_timeout = elapsed >= 1000, within_bound = elapsed < 5000 * H.load_factor() },
		{ at_least_timeout = true, within_bound = true }
	)
	eq(result.stderr:find("pid " .. holder.pid, 1, true) ~= nil, true)
	eq(lock_owner(dir), holder.pid)
	eq(wait_locker("holder").code, 0)
end

---@param line string
---@return boolean
local function is_repo_sync(line)
	return vim.startswith(line, "rsync ") and vim.endswith(line, ":/Users/lume/nvim/")
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
	local holder = start_locker("holder", dir, 2 * H.load_factor())
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

return T
