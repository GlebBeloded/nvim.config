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

T["run: Run executes cargo run when Cargo.lock is readable"] = function()
	child.lua([[
		GitRoot = vim.fn.tempname() .. " git root"
		GitRoot = vim.fn.resolve(GitRoot)
		CargoDir = GitRoot .. "/nested crate"
		vim.fn.mkdir(CargoDir, "p")
		vim.fn.system({ "git", "init", GitRoot })
		assert(vim.v.shell_error == 0)
		vim.fn.chdir(CargoDir)
		require("gleb.run")
		RunCommands = {}
		vim.cmd = function(command) table.insert(RunCommands, command) end
		vim.fn.writefile({}, "Cargo.toml")
		vim.fn.writefile({}, "Cargo.lock")
		vim.api.nvim_cmd({ cmd = "Run" }, {})
	]])

	eq(child.lua_get("RunCommands"), { "!cd '" .. child.lua_get("CargoDir") .. "';cargo run" })
end

T["run: Run opens the browser when index.html is readable"] = function()
	child.lua([[
		local index_dir = vim.fn.tempname()
		vim.fn.mkdir(index_dir, "p")
		vim.fn.chdir(index_dir)
		require("gleb.run")
		RunCommands = {}
		vim.cmd = function(command) table.insert(RunCommands, command) end
		vim.fn.writefile({}, "index.html")
		vim.api.nvim_cmd({ cmd = "Run" }, {})
	]])

	eq(child.lua_get("RunCommands"), { "silent !open -a Safari index.html" })

	child.lua([[
		local both_markers_dir = vim.fn.tempname()
		vim.fn.mkdir(both_markers_dir, "p")
		vim.fn.chdir(both_markers_dir)
		vim.fn.writefile({}, "index.html")
		vim.fn.writefile({}, "Cargo.lock")
		RunCommands = {}
		vim.api.nvim_cmd({ cmd = "Run" }, {})
	]])

	eq(child.lua_get("RunCommands"), { "silent !open -a Safari index.html" })
end

return T
