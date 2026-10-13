local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

--- `zellij` stub: counts calls in $ZELLIJ_STUB_COUNT. Mode `gone` always reports no session;
--- mode `flaky` reports no session, then lists no client, then a client on terminal_0.
local ZELLIJ_STUB = [[#!/bin/sh
echo call >>"$ZELLIJ_STUB_COUNT"
n=$(wc -l <"$ZELLIJ_STUB_COUNT" | tr -d ' ')
if [ "$ZELLIJ_STUB_MODE" = gone ] || [ "$n" -eq 1 ]; then
	echo 'There is no active session!' >&2
	exit 1
fi
echo 'CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND'
if [ "$n" -ge 3 ]; then
	echo '1 terminal_0 nvim'
fi
exit 0
]]

--- Runs in the child: focused_pane() of a Stack whose `zellij` is the stub,
--- polled for terminal_0 by `M.wait_for` when `outer` (ms) is given.
local FOCUSED_PANE = [[local stub, mode, timeout, outer = ...
-- an idle host whatever the machine's load, so the deadlines stay unscaled
vim.uv.loadavg = function()
	return 0, 0, 0
end
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local zellij = vim.fs.joinpath(dir, "zellij")
vim.fn.writefile(vim.split(stub, "\n"), zellij)
vim.uv.fs_chmod(zellij, 493)
local count = vim.fs.joinpath(dir, "calls")
local M = require("tests.shortcuts.stack")
local stack = setmetatable({
	session = "s",
	env = { PATH = dir .. ":" .. vim.env.PATH, ZELLIJ_STUB_MODE = mode, ZELLIJ_STUB_COUNT = count },
	cli_timeout = timeout ~= vim.NIL and timeout or nil,
}, M.Stack)
local t0 = vim.uv.hrtime()
local function on_neovim_pane()
	return stack:focused_pane() == "terminal_0"
end
local ok, value
if outer then
	ok, value = pcall(M.wait_for, on_neovim_pane, "the Neovim pane", outer)
else
	ok, value = pcall(stack.focused_pane, stack)
end
return {
	ok = ok,
	value = tostring(value),
	calls = vim.fn.filereadable(count) == 1 and #vim.fn.readfile(count) or 0,
	ms = (vim.uv.hrtime() - t0) / 1e6,
}]]

---@class StackCliResult
---@field ok boolean
---@field value string pane id, or the error
---@field calls integer
---@field ms number

---@param mode "flaky"|"gone"
---@param timeout? integer
---@param outer? integer
---@return StackCliResult
local function focused_pane(mode, timeout, outer)
	return child.lua(FOCUSED_PANE, { ZELLIJ_STUB, mode, timeout, outer })
end

T["shortcuts: The stack harness retries a transient zellij CLI failure"] = function()
	local result = focused_pane("flaky")

	eq({ ok = result.ok, value = result.value, calls = result.calls }, { ok = true, value = "terminal_0", calls = 3 })
end

T["shortcuts: The stack harness fails when the zellij session stays gone"] = function()
	local result = focused_pane("gone", 300)

	eq(result.ok, false)
	eq(result.value:find("There is no active session!", 1, true) ~= nil, true)
	eq(result.ms < 2000, true)
end

T["shortcuts: The stack harness keeps a zellij CLI retry within the outer wait"] = function()
	local result = focused_pane("gone", nil, 300)

	eq(result.ok, false)
	eq(result.value:find("There is no active session!", 1, true) ~= nil, true)
	eq(result.ms < 2000, true)
end

--- `zellij` stub whose `dump-screen` prints a Neovim screen stuck on a startup error.
local BLOCKED_SCREEN_STUB = [[#!/bin/sh
case "$*" in
*dump-screen*) printf '~\n~\n\nError detected while processing init.lua:\nE5113: kmap is nil\nPress ENTER or type command to continue\n\n' ;;
*) exit 1 ;;
esac
]]

--- Runs in the child: `lua()` of a Stack whose Neovim reports a blocking mode `r`.
local BLOCKED_LUA = [[local stub = ...
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local zellij = vim.fs.joinpath(dir, "zellij")
vim.fn.writefile(vim.split(stub, "\n"), zellij)
vim.uv.fs_chmod(zellij, 493)
local M = require("tests.shortcuts.stack")
local stack = setmetatable({ session = "s", env = { PATH = dir .. ":" .. vim.env.PATH } }, M.Stack)
function stack.mode()
	return { mode = "r", blocking = true }
end
local ok, err = pcall(stack.lua, stack, "return 1")
return { ok = ok, err = tostring(err) }]]

T["shortcuts: The stack harness shows the screen that blocks Neovim"] = function()
	local result = child.lua(BLOCKED_LUA, { BLOCKED_SCREEN_STUB })

	eq(result.ok, false)
	for _, needle in ipairs({ "blocked in mode r", "E5113: kmap is nil", "Press ENTER or type command to continue" }) do
		eq(result.err:find(needle, 1, true) ~= nil, true, { fail_reason = result.err })
	end
end

--- Runs in the child with `vim.uv.loadavg` / `vim.uv.available_parallelism` pinned to `load` and `cpus`:
--- `M.wait_for` from tests.shortcuts.stack on a predicate that turns true `ready` ms after the call.
local WAIT_UNDER_LOAD = [[local load, cpus, ready, timeout = ...
vim.uv.loadavg = function()
	return load, load, load
end
vim.uv.available_parallelism = function()
	return cpus
end
local M = require("tests.shortcuts.stack")
local t0 = vim.uv.hrtime()
local function ready_yet()
	return (vim.uv.hrtime() - t0) / 1e6 >= ready
end
local ok, err = pcall(M.wait_for, ready_yet, "the ready flag", timeout)
return { ok = ok, err = tostring(err) }]]

--- Runs in the child with the load pinned: `module.fn(...)` for a `module` among tests.helpers and
--- tests.smoke.budget.
local CALL_UNDER_LOAD = [[local loads, cpus, module, fn, args = ...
vim.uv.loadavg = function()
	return unpack(loads)
end
vim.uv.available_parallelism = function()
	return cpus
end
return require(module)[fn](unpack(args))]]

---@param loads number[] 1, 5 and 15 min load average
---@param cpus integer
---@param module string
---@param fn string
---@param args? any[]
---@return any
local function call_under_load(loads, cpus, module, fn, args)
	return child.lua(CALL_UNDER_LOAD, { loads, cpus, module, fn, args or {} })
end

T["load"] = MiniTest.new_set()

T["load"]["shortcuts: The load factor is 1 on an idle host"] = function()
	eq(call_under_load({ 7, 7, 7 }, 14, "tests.helpers", "load_factor"), 1)
end

T["load"]["shortcuts: The load factor is the load per CPU on a busy host"] = function()
	eq(call_under_load({ 70, 60, 50 }, 14, "tests.helpers", "load_factor"), 5)
end

T["load"]["shortcuts: The stack harness wait stretches with host load"] = function()
	local cpus = child.lua_get("vim.uv.available_parallelism()")

	local result = child.lua(WAIT_UNDER_LOAD, { 3 * cpus, cpus, 600, 300 })

	eq(result, { ok = true, err = "nil" })
end

T["load"]["shortcuts: The stack harness wait keeps its timeout on an idle host"] = function()
	local cpus = child.lua_get("vim.uv.available_parallelism()")

	local result = child.lua(WAIT_UNDER_LOAD, { 0, cpus, 600, 300 })

	eq(result.ok, false)
	eq(result.err:find("stack: timed out waiting for", 1, true) ~= nil, true)
end

T["load"]["shortcuts: The smoke startup budget scales with host load only when busy"] = function()
	local budgets = {
		idle = call_under_load({ 14, 14, 14 }, 14, "tests.smoke.budget", "startup_budget", { 400 }),
		busy = call_under_load({ 42, 42, 42 }, 14, "tests.smoke.budget", "startup_budget", { 400 }),
	}

	eq(budgets, { idle = 400, busy = 1200 })
end

return T
