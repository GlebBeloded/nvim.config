-- Fixtures go into the real /tmp/nvim, so they use pids no process can have
-- (> 4·10⁹, distinct per case for parallel workers) and are always removed.
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local LOG_DIR = "/tmp/nvim"
local DAY_S = 24 * 60 * 60

local function start()
	child.start_bare()
end

---@param name string
---@return string path
local function fixture(name)
	vim.fn.mkdir(LOG_DIR, "p")
	local path = vim.fs.joinpath(LOG_DIR, name)
	vim.fn.writefile({ "fixture" }, path)
	return path
end

---@param days integer
---@return integer
local function days_ago(days)
	return os.time() - days * DAY_S
end

---@param path string
---@return boolean
local function exists(path)
	return vim.fn.filereadable(path) == 1
end

--- Runs `case`, then `cleanup`, and rethrows the case's error.
---@param case fun()
---@param cleanup fun()
local function finally(case, cleanup)
	local ok, err = pcall(case)
	cleanup()
	assert(ok, err)
end

local T = H.child_set(child, start)

T["nvim-debug-log: logs older than 7 days are deleted"] = function()
	local old_pid, recent_pid = 4000000001, 4000000002
	local old = fixture(string.format("%d_%d.txt", days_ago(8), old_pid))
	local recent = fixture(string.format("%d_%d.txt", days_ago(1), recent_pid))

	finally(function()
		child.lua([[require("gleb.nvim_debug_log").setup()]])
		eq({ exists(old), exists(recent) }, { false, true })
	end, function()
		H.delete_debug_log(old_pid)
		H.delete_debug_log(recent_pid)
	end)
end

T["nvim-debug-log: other files in the log directory are kept"] = function()
	local old_time = days_ago(8)
	local other_ext = fixture(string.format("%d_%d.log", old_time, 4000000003))
	local other_name = fixture(string.format("notes_%d.txt", old_time))

	finally(function()
		child.lua([[require("gleb.nvim_debug_log").setup()]])
		eq({ exists(other_ext), exists(other_name) }, { true, true })
	end, function()
		vim.fn.delete(other_ext)
		vim.fn.delete(other_name)
	end)
end

return T
