local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

---@param pid integer
---@return boolean
local function alive(pid)
	return vim.uv.kill(pid, 0) == 0
end

T["loop: A test child outlives no killed worker"] = function()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local pid_file = vim.fs.joinpath(dir, "child.pid")
	local script = vim.fs.joinpath(dir, "worker.lua")
	vim.fn.writefile({
		("vim.opt.rtp:prepend(%q)"):format(H.root),
		("package.path = %q .. '/?.lua;' .. package.path"):format(H.root),
		"vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/mini.nvim')",
		"_G.MiniTest = require('mini.test')",
		"local child = require('tests.helpers').new_child()",
		"child.start()",
		("vim.fn.writefile({ tostring(child.lua_get('vim.uv.os_getpid()')) }, %q)"):format(pid_file),
		"vim.uv.sleep(60000)",
	}, script)
	local worker = vim.system(
		{ vim.v.progpath, "--headless", "-u", "NONE", "-l", script },
		{ env = { XDG_DATA_HOME = vim.env.XDG_DATA_HOME } }
	)
	local child_pid
	vim.wait(15000, function()
		local lines = vim.fn.filereadable(pid_file) == 1 and vim.fn.readfile(pid_file) or {}
		child_pid = tonumber(lines[1])
		return child_pid ~= nil
	end, 50)
	eq(type(child_pid), "number")
	eq(alive(child_pid), true)
	worker:kill(9)
	eq(
		vim.wait(10000, function()
			return not alive(child_pid)
		end, 100),
		true
	)
end

T["loop: A test worker outlives no killed run"] = function()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "test_hang.lua")
	local started = vim.fs.joinpath(dir, "started")
	vim.fn.writefile({
		"local T = require('mini.test').new_set()",
		("T['x: hangs'] = function() vim.fn.writefile({}, %q) vim.wait(120000, function() return false end) end"):format(
			started
		),
		"return T",
	}, file)
	local run = vim.system(
		{ vim.v.progpath, "-u", "tests/minimal_init.lua", "-l", "tests/parallel.lua" },
		{ cwd = H.root, env = { FILE = file, JOBS = "1", TEST_STALL_S = "600" } }
	)
	local worker
	vim.wait(15000, function()
		local out = vim.system({ "pgrep", "-P", tostring(run.pid) }):wait().stdout or ""
		worker = tonumber(out:match("%d+"))
		return worker ~= nil
	end, 100)
	eq(type(worker), "number")
	-- the worker runs its case (a loaded host starts it slowly)
	eq(
		vim.wait(math.ceil(30000 * H.load_factor()), function()
			return vim.fn.filereadable(started) == 1
		end, 100),
		true
	)
	run:kill(9)
	eq(
		vim.wait(10000, function()
			return not alive(worker)
		end, 100),
		true
	)
end

return T
