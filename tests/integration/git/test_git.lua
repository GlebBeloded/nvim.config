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

T["git: vscode-diff setup runs on plugin load"] = function()
	child.lua([[require("lazy").load({ plugins = { "vscode-diff.nvim" } })]])

	eq(child.lua_get([[package.loaded["gleb.git.vscode_diff"] ~= nil]]), true)
	-- the plugin defaults are width 40 and a list view, so these come from the config's setup
	local explorer = child.lua_get([[require("codediff.config").options.explorer]])
	eq({ explorer.position, explorer.width, explorer.view_mode }, { "left", 35, "tree" })
end

return T
