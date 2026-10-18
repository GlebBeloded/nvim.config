local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local repo

local function start()
	repo = H.git_repo({ ["tracked.txt"] = "base\n" })
	H.write_files(repo, { ["tracked.txt"] = "changed\n" })
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

local function toggle_changes()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("changes.toggle"), "changes.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

local function wait_for_panel()
	assert(
		child.wait(
			[[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view ~= nil and #view.rows > 0
			end)()]],
			3000
		),
		"Changes panel did not draw its initial rows"
	)
end

T["git: Changes panel opens on the left at width 35"] = function()
	local billing = F.copy("billing", vim.fn.tempname() .. "/billing")
	local invoice = vim.fs.joinpath(billing, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(billing))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))

	toggle_changes()
	wait_for_panel()

	local result = child.lua_get([[
		(function()
			local current = vim.api.nvim_get_current_win()
			local wins = vim.api.nvim_tabpage_list_wins(0)
			local editor = wins[1] == current and wins[2] or wins[1]
			return {
				leftmost = wins[1] == current,
				filetype = vim.bo[vim.api.nvim_win_get_buf(current)].filetype,
				width = vim.api.nvim_win_get_width(current),
				line = vim.api.nvim_get_current_line(),
				editor = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(editor)),
			}
		end)()
	]])
	eq({ result.leftmost, result.filetype, result.width, result.editor }, {
		true,
		"gleb-changes",
		35,
		vim.fs.normalize(vim.fn.resolve(invoice)),
	})
	assert(result.line:find("invoice.go", 1, true), "cursor is not on invoice.go: " .. result.line)
end

T["git: Changes panel cursor starts on the first file"] = function()
	local dirty = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	child.cmd("cd " .. vim.fn.fnameescape(dirty))
	child.cmd("enew")

	toggle_changes()
	wait_for_panel()

	assert(child.lua_get([[vim.api.nvim_get_current_line():find("c.lua", 1, true) ~= nil]]))
end

T["git: Changes panel toggle closes the focused panel"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(repo))
	toggle_changes()
	wait_for_panel()

	toggle_changes()

	eq(
		child.lua_get([[
		(function()
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-changes" then
					return false
				end
			end
			return vim.bo.filetype ~= "gleb-changes"
		end)()
	]]),
		true
	)
end

T["git: Changes panel toggle focuses an open panel"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(repo))
	toggle_changes()
	wait_for_panel()
	local window_count = child.lua_get([[#vim.api.nvim_tabpage_list_wins(0)]])
	child.cmd("wincmd l")

	toggle_changes()

	eq({ child.lua_get([[vim.bo.filetype]]), child.lua_get([[#vim.api.nvim_tabpage_list_wins(0)]]) }, {
		"gleb-changes",
		window_count,
	})
end

T["git: Changes panel outside a repository"] = function()
	local outside = vim.fn.tempname()
	vim.fn.mkdir(outside, "p")
	child.cmd("cd " .. vim.fn.fnameescape(outside))
	child.cmd("enew")
	H.record_notify(child)

	toggle_changes()
	assert(child.wait([[#Notifications > 0]]), "Git root error was not reported")

	eq(
		child.lua_get([[
		(function()
			local note = Notifications[#Notifications]
			local panel = false
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				panel = panel or vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-changes"
			end
			return { vim.startswith(note.msg, "Git root error:"), note.level, panel }
		end)()
	]]),
		{ true, vim.log.levels.ERROR, false }
	)
end

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
