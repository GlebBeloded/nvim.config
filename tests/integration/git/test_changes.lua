local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local repo

local function start()
	repo = H.git_repo({ ["tracked.txt"] = "base\n" })
	H.write_files(repo, { ["tracked.txt"] = "changed\n" })
	child.start_config()
end

local T = H.child_set(child, start)

T["git: Changes panel status avoids optional locks"] = MiniTest.new_set()

T["git: Changes panel status avoids optional locks"]["refreshes with the lock-free status command"] = function()
	child.lua(
		[[
		_G.changes_status_result = nil
		require("gleb.git.changes.git").refresh(..., function(result)
			_G.changes_status_result = result
		end)
	]],
		{ repo }
	)
	assert(child.wait("_G.changes_status_result ~= nil"), "Changes status did not finish")

	eq(child.lua_get([[require("gleb.git.changes.git").state.last_cmd]]), {
		"git",
		"--no-optional-locks",
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=all",
	})
	eq(child.lua_get("_G.changes_status_result.code"), 0)
	assert(child.lua_get([[_G.changes_status_result.stdout:find("tracked.txt", 1, true) ~= nil]]))
end

T["git: Changes panel highlight colours"] = MiniTest.new_set()

T["git: Changes panel highlight colours"]["come from the palette after a colorscheme change"] = function()
	child.lua([[require("gleb.git.changes.highlights").setup()]])
	child.api.nvim_set_hl(0, "ChangesRoot", { fg = "#000000" })
	child.api.nvim_exec_autocmds("ColorScheme", {})

	H.expect_hl_colors(child, "ChangesRoot", { fg = "#ddc7a1", bold = true })
	H.expect_hl_colors(child, "ChangesCount", { fg = "#928374" })
	H.expect_hl_colors(child, "ChangesStatAdded", { fg = "#a9b665" })
	H.expect_hl_colors(child, "ChangesStatRemoved", { fg = "#ea6962" })
end

return T
