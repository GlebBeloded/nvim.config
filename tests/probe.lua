-- `make probe`: run a Lua snippet in a headless full-config child Neovim
-- (same sandbox as the tests: H.new_child + start_config, VeryLazy fired),
-- print what it prints, then its return values (vim.inspect).
-- Run: SCRIPT=file.lua | PROBE='lua code' [PROBE_TIMEOUT=ms] nvim -u tests/minimal_init.lua -l tests/probe.lua
-- Exits 1 on a load/runtime error, 124 on timeout.

local TIMEOUT_MS = tonumber(vim.env.PROBE_TIMEOUT) or 30000

--- Child-side: run the code with print captured; returns { prints, values, err? }.
local RUN_LUA = [[
local code = ...
local chunk, err = loadstring(code, "=probe")
if not chunk then return { prints = {}, values = {}, err = err } end
local prints, print_ = {}, print
_G.print = function(...)
	local parts = vim.tbl_map(tostring, { ... })
	prints[#prints + 1] = table.concat(parts, "\t")
end
local result = vim.F.pack_len(pcall(chunk))
_G.print = print_
if not result[1] then return { prints = prints, values = {}, err = tostring(result[2]) } end
local values = {}
for i = 2, result.n do values[#values + 1] = vim.inspect(result[i]) end
return { prints = prints, values = values }
]]

---@param msg string
-- selene: allow(incorrect_standard_library_use)
local function warn(msg)
	io.stderr:write(msg)
end

---@return string? code
local function source()
	if vim.env.SCRIPT and vim.env.SCRIPT ~= "" then
		return table.concat(assert(vim.fn.readfile(vim.env.SCRIPT)), "\n")
	end
	if vim.env.PROBE and vim.env.PROBE ~= "" then
		return vim.env.PROBE
	end
end

--- Inner run (the outer one bounds it with a timeout).
local function inner()
	local H = require("tests.helpers")
	local child = H.new_child()
	local ok, out = pcall(function()
		child.start_config()
		child.wait_very_lazy()
		return child.lua(RUN_LUA, { source() })
	end)
	child.stop()
	if not ok then
		warn("probe error: " .. tostring(out) .. "\n")
		os.exit(1)
	end
	for _, line in ipairs(out.prints) do
		io.write(line, "\n")
	end
	for _, value in ipairs(out.values) do
		io.write(value, "\n")
	end
	if out.err then
		warn("probe error: " .. out.err .. "\n")
	end
	os.exit(out.err and 1 or 0)
end

local function outer()
	if not source() then
		warn("usage: make probe SCRIPT=<file.lua> | make probe PROBE='lua code'\n")
		os.exit(2)
	end
	local cmd =
		{ vim.v.progpath, "-u", vim.fs.joinpath(vim.env.TEST_ROOT, "tests/minimal_init.lua"), "-l", arg[0], "inner" }
	local result = vim.system(cmd, { text = true, timeout = TIMEOUT_MS }):wait()
	io.write(result.stdout or "")
	warn(result.stderr or "")
	if result.code == 124 then
		warn(("probe timed out after %d ms (PROBE_TIMEOUT)\n"):format(TIMEOUT_MS))
	end
	os.exit(result.code)
end

if arg[1] == "inner" then
	inner()
else
	vim.env.TEST_ROOT = vim.fn.fnamemodify(arg[0], ":p:h:h")
	outer()
end
