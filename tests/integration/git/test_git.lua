local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

---@type string
local repo

--- Full config in a fresh temp git repo as cwd.
local function start()
	repo = H.git_repo({ ["a.txt"] = "a\n" })
	child.start_config()
	child.cmd("cd " .. repo)
end

local T = H.child_set(child, start)

T["git: Git commands are available after startup"] = function()
	local commands = { "Gitsigns", "Differ", "DiffviewOpen", "Gitlink" }
	local exists = vim.tbl_map(function(cmd)
		return child.fn.exists(":" .. cmd)
	end, commands)
	eq(exists, { 2, 2, 2, 2 })
end

return T
