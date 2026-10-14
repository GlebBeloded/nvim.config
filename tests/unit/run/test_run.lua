local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["run: Run ignores a directory without a supported project marker"] = function()
	child.lua([[
		local empty_dir = vim.fn.tempname()
		vim.fn.mkdir(empty_dir, "p")
		vim.fn.chdir(empty_dir)
		require("gleb.run")
		RunCommands = {}
		vim.cmd = function(command) table.insert(RunCommands, command) end
		vim.api.nvim_cmd({ cmd = "Run" }, {})
	]])

	eq(child.lua_get("RunCommands"), {})
end

return T
