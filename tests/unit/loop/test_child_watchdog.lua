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

return T
