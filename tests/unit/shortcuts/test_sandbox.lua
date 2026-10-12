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

--- `ssh` stub: logs the guest command (last argument); the guest is provisioned at
--- $PROVISION_REV and its GUI session belongs to `lume`.
local SSH_STUB = [[#!/bin/sh
for cmd; do :; done
echo "$cmd" >>"$GUEST_LOG"
case "$cmd" in
"cat ~/.nvim-e2e-provisioned"*) echo "$PROVISION_REV" ;;
"stat -f %Su /dev/console") echo lume ;;
esac
exit 0
]]

--- `rsync` stub: logs `rsync <dest>`.
local RSYNC_STUB = [[#!/bin/sh
for dest; do :; done
echo "rsync $dest" >>"$GUEST_LOG"
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
	local log = read_lines(env.GUEST_LOG)
	local order = {
		sync = first_index(log, function(line)
			return vim.startswith(line, "rsync ") and vim.endswith(line, ":/Users/lume/nvim/")
		end),
		restore = first_index(log, function(line)
			return line:find("tests/sandbox/guest_restore.sh", 1, true) ~= nil
		end),
		e2e = first_index(log, function(line)
			-- `gui` quotes the command with printf %q; the guest shell unescapes it
			return line:gsub("\\ ", " "):find("make -s e2e-local", 1, true) ~= nil
		end),
	}
	eq({ order.sync ~= nil, order.restore ~= nil, order.e2e ~= nil }, { true, true, true })
	eq({ order.sync < order.restore, order.restore < order.e2e }, { true, true })
end

return T
