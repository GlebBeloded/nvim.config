-- The log path is hard-coded to /tmp/nvim, so cases locate the child's own
-- file by pid instead of wiping the directory (it holds the user's real logs).
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local LOG_DIR = "/tmp/nvim"
local WAIT_MS = 3000

---@type integer
local pid

local function start()
	child.start_bare()
	pid = child.fn.getpid()
	child.lua([[require("gleb.nvim_debug_log")]])
end

---@return string? path of the child's log file
local function log_file()
	return vim.fn.glob(string.format("%s/*_%d.txt", LOG_DIR, pid), false, true)[1]
end

---@return string
local function log_text()
	local file = log_file()
	return file and table.concat(vim.fn.readfile(file), "\n") or ""
end

---@param needle string
local function expect_logged(needle)
	local found = vim.wait(WAIT_MS, function()
		return log_text():find(needle, 1, true) ~= nil
	end, 100)
	if not found then
		error(string.format("expected log to contain %q\n--- actual ---\n%s", needle, log_text()))
	end
end

local T = H.child_set(child, start)

T["nvim-debug-log: Log directory and file created"] = function()
	child.cmd('echom "X"')
	expect_logged("X")

	eq(vim.fn.isdirectory(LOG_DIR), 1)
	eq(vim.fs.basename(log_file()):match("^%d+_" .. pid .. "%.txt$") ~= nil, true)
end

T["nvim-debug-log: captures vim.notify"] = function()
	child.lua([[vim.notify("TEST_notify")]])
	expect_logged("TEST_notify")
end

T["nvim-debug-log: captures :echo from ex command"] = function()
	child.cmd('echo "TEST_echo_excmd"')
	expect_logged("TEST_echo_excmd")
end

T["nvim-debug-log: captures :echom from ex command"] = function()
	child.cmd('echom "TEST_echom_excmd"')
	expect_logged("TEST_echom_excmd")
end

T["nvim-debug-log: captures errors"] = function()
	child.lua([[vim.api.nvim_err_writeln("TEST_err_msg")]])
	expect_logged("TEST_err_msg")
end

T["nvim-debug-log: periodic flush works during session"] = function()
	child.cmd('echom "FLUSH_DURING_SESSION"')
	expect_logged("FLUSH_DURING_SESSION")

	eq(child.is_running(), true)
end

T["nvim-debug-log: Log finalized on exit"] = function()
	child.cmd('echom "BEFORE_EXIT"')
	child.api_notify.nvim_command("qa!")

	local ok, err = pcall(expect_logged, "BEFORE_EXIT")
	vim.fn.delete(log_file() or "")
	assert(ok, err)
end

return T
