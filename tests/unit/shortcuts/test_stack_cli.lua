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

--- Runs in the child: focused_pane() of a Stack whose `zellij` is the stub.
local FOCUSED_PANE = [[local stub, mode, timeout = ...
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
	cli_timeout = timeout,
}, M.Stack)
local t0 = vim.uv.hrtime()
local ok, value = pcall(stack.focused_pane, stack)
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
---@return StackCliResult
local function focused_pane(mode, timeout)
	return child.lua(FOCUSED_PANE, { ZELLIJ_STUB, mode, timeout })
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

return T
