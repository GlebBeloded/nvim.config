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

local function toggle_project_tree()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

local function review_changes()
	return child.lua_get([[
		(function()
			local catalog = require("gleb.actions").state.applicator.catalog
			local action = assert(catalog:get("changes.review"), "changes.review is not registered")
			return { pcall(action.run, require("gleb.actions.context").capture()) }
		end)()
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

T["git: Cmd+G from a non-file buffer uses a real directory"] = function()
	local dirty = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	child.cmd("cd " .. vim.fn.fnameescape(dirty))
	child.cmd("enew")
	child.bo.buftype = "nofile"
	child.api.nvim_buf_set_name(0, "gleb-changes://not-a-file")

	local opened = review_changes()
	assert(opened[1], opened[2])
	wait_for_panel()

	eq(
		child.lua_get([[
			(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return { panel.root, vim.uv.fs_stat(panel.root).type }
			end)()
		]]),
		{ assert(vim.uv.fs_realpath(dirty)), "directory" }
	)
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

T["git: Changes panel replaces the project tree"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(repo))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(repo, "tracked.txt")))
	toggle_project_tree()
	assert(child.wait([[vim.bo.filetype == "gleb-file-tree"]]), "Project tree did not open")

	local opened = child.lua_get([[
		(function()
			local catalog = require("gleb.actions").state.applicator.catalog
			local action = assert(catalog:get("changes.toggle"), "changes.toggle is not registered")
			local ok, err = pcall(action.run, require("gleb.actions.context").capture())
			return { ok, err }
		end)()
	]])
	assert(opened[1], opened[2])
	wait_for_panel()

	eq(
		child.lua_get([[
		(function()
			local wins = vim.api.nvim_tabpage_list_wins(0)
			local current = vim.api.nvim_get_current_win()
			local tree_open = false
			for _, win in ipairs(wins) do
				tree_open = tree_open or vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-file-tree"
			end
			return {
				tree_open,
				wins[1] == current,
				vim.bo[vim.api.nvim_win_get_buf(current)].filetype,
				vim.api.nvim_win_get_width(current),
			}
		end)()
	]]),
		{ false, true, "gleb-changes", 35 }
	)
end

T["git: Changes panel normalizes a private-var root"] = function()
	local linked_root = vim.fn.tempname() .. "-linked"
	child.lua([[assert(vim.uv.fs_symlink(...))]], { repo, linked_root })
	child.cmd("cd " .. vim.fn.fnameescape(linked_root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(linked_root, "tracked.txt")))

	toggle_changes()
	wait_for_panel()

	local normalized = assert(vim.uv.fs_realpath(repo))
	eq(
		child.lua_get([[
			(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return {
					view.root,
					vim.api.nvim_buf_get_name(view.buf),
					vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(view.editor_win)),
				}
			end)()
		]]),
		{
			normalized,
			("gleb-changes://%s#%d"):format(normalized, child.api.nvim_get_current_tabpage()),
			vim.fs.joinpath(normalized, "tracked.txt"),
		}
	)
end

T["git: Changes panel revalidates the editor window"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(repo))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(repo, "tracked.txt")))
	toggle_changes()
	wait_for_panel()
	local panel = child.api.nvim_get_current_win()
	child.cmd("wincmd l")
	local stale = child.api.nvim_get_current_win()
	child.cmd("vsplit")
	local replacement = child.api.nvim_get_current_win()
	child.api.nvim_win_close(stale, true)

	local selected = child.lua_get([[
		(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return require("gleb.file_tree.view").eligible_editor(view)
		end)()
	]])

	eq(selected, replacement)
	assert(selected ~= panel, "Changes panel was selected as its own editor window")
end

T["git: Changes panel closes when orphaned"] = function()
	child.cmd("tabnew")
	child.cmd("cd " .. vim.fn.fnameescape(repo))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(repo, "tracked.txt")))
	local panel_tab = child.api.nvim_get_current_tabpage()
	toggle_changes()
	wait_for_panel()
	child.lua(
		[[
		local view = require("gleb.git.changes").state.by_tab[...]
		_G.orphaned_changes_tab = ...
		_G.orphaned_changes = { win = view.win, timer = view.timer }
	]],
		{ panel_tab }
	)
	child.cmd("wincmd l")

	child.cmd("close")

	assert(
		child.wait([[require("gleb.git.changes").state.by_tab[_G.orphaned_changes_tab] == nil]], 1000),
		"Orphaned Changes panel did not close"
	)
	eq(
		child.lua_get([[
			{
				vim.api.nvim_win_is_valid(_G.orphaned_changes.win),
				_G.orphaned_changes.timer:is_closing(),
			}
		]]),
		{ false, true }
	)
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

T["git: Changes panel mappings come from the shortcut file"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(repo))
	toggle_changes()
	wait_for_panel()

	local mappings = child.lua_get([[
		(function()
			local context = require("gleb.actions.context")
			local original = context.execute
			local invoked
			context.execute = function(action)
				invoked = action.id
				return true
			end
			local result = {}
			for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
				invoked = nil
				mapping.callback()
				table.insert(result, { mapping.lhs, mapping.desc, invoked })
			end
			context.execute = original
			table.sort(result, function(a, b) return a[1] < b[1] end)
			return result
		end)()
	]])
	eq(mappings, {
		{ " ", "Changes: Toggle Stage", "changes.toggle_stage" },
		{ "<CR>", "Changes: Open", "changes.open" },
		{ "A", "Changes: Stage All", "changes.stage_all" },
		{ "P", "Changes: Push", "changes.push" },
		{ "X", "Changes: Revert", "changes.revert" },
		{ "gc", "Changes: Commit", "changes.commit" },
		{ "q", "Changes: Close", "changes.close" },
		{ "za", "Changes: Toggle Fold", "changes.toggle_fold" },
	})
end

T["git: Changes panel leaves gr global"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(repo))
	toggle_changes()
	wait_for_panel()

	local mapping = child.lua_get([[
		(function()
			local references = require("gleb.references")
			local original = references.open
			local invoked = false
			references.open = function() invoked = true end
			local current = vim.fn.maparg("gr", "n", false, true)
			current.callback()
			references.open = original
			return { current.buffer, current.desc, invoked }
		end)()
	]])
	eq(mapping, { 0, "LSP: Find References", true })
end

T["git: Changes panel entry points are actions"] = function()
	eq(
		child.lua_get([[
			(function()
				local catalog = require("gleb.actions").state.applicator.catalog
				local result = {}
				for _, id in ipairs({ "changes.toggle", "changes.review" }) do
					local action = assert(catalog:get(id), id .. " is not registered")
					result[id] = { action.title, action.category, action.plugin }
				end
				return result
			end)()
		]]),
		{
			["changes.toggle"] = { "Toggle Changes", "View | Tool Windows" },
			["changes.review"] = { "Review Changes", "View | Tool Windows" },
		}
	)
end

local function open_fixture(name)
	local root = F.copy(name, vim.fn.tempname() .. "/" .. name)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("enew")
	toggle_changes()
	wait_for_panel()
	return root
end

local function panel_lines()
	return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function find_panel_line(text)
	local line = child.fn.search(text, "nw")
	assert(line > 0, "Panel row not found: " .. text)
	child.api.nvim_win_set_cursor(0, { line, 0 })
	return line
end

T["git: Changes panel za folds a nest"] = function()
	open_fixture("billing")
	find_panel_line("invoice.go")

	child.type_keys("za")
	child.cmd("checktime")
	child.api.nvim_exec_autocmds("FocusGained", {})
	assert(child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].generation >= 2]]))

	local lines = panel_lines()
	eq(
		vim.iter(lines):any(function(line)
			return line:find("invoice_test.go", 1, true) ~= nil
		end),
		false
	)
	local invoice = vim.iter(lines):find(function(line)
		return line:find("invoice.go", 1, true) ~= nil
	end)
	assert(invoice and invoice:find("", 1, true), "invoice.go did not show the collapsed expander")
end

T["git: Changes panel Enter folds a directory"] = function()
	open_fixture("billing")
	find_panel_line("web/src 1")
	local panel_buf = child.api.nvim_get_current_buf()

	child.type_keys("<CR>")

	eq(child.api.nvim_get_current_buf(), panel_buf)
	eq(
		vim.iter(panel_lines()):any(function(line)
			return line:find("price.ts", 1, true) ~= nil
		end),
		false
	)
end

T["git: Changes panel refreshes after a write"] = function()
	local dirty = open_fixture("dirty")
	local selected = child.lua_get([=[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path
	end)()]=])
	child.cmd("wincmd l")
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(dirty, "e.txt")))
	child.cmd([[call setline(1, "x")]])
	child.cmd("write")

	assert(
		child.wait(
			[=[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for _, row in ipairs(view.rows) do
			if row.path == "e.txt" then return true end
		end
		return false
	end)()]=],
			500 * H.load_factor()
		),
		"Changes panel did not refresh after the write"
	)
	eq(
		child.lua_get([=[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path
	end)()]=]),
		selected
	)
	assert(vim.iter(child.lua_get([=[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)
	end)()]=]) or {}):any(function(line)
		return line:find("Unversioned Files 2 files", 1, true) ~= nil
	end))
end

T["git: Changes panel refreshes after hunk staging"] = function()
	local dirty = open_fixture("dirty")
	local panel_tab = child.api.nvim_get_current_tabpage()
	child.lua("_G.changes_panel_tab = ...", { panel_tab })
	find_panel_line("b.txt")
	child.type_keys("j")
	assert(
		child.wait(
			[=[(function()
		local view = require("gleb.git.changes").state.by_tab[_G.changes_panel_tab]
		return view ~= nil and view.diff_view ~= nil and view.diff_view.relpath == "d.txt"
	end)()]=],
			2000 * H.load_factor()
		),
		"Changes panel did not show d.txt"
	)
	local right_win =
		child.lua_get([=[require("gleb.git.changes").state.by_tab[...].diff_view.right_win]=], { panel_tab })
	child.api.nvim_set_current_win(right_win)
	child.api.nvim_win_set_cursor(right_win, { 3, 0 })

	child.type_keys("<Space>")

	assert(
		child.wait(
			[=[(function()
		local view = require("gleb.git.changes").state.by_tab[_G.changes_panel_tab]
		if not view then return false end
		for _, row in ipairs(view.rows) do
			if row.path == "d.txt" then return row.checkbox ~= "󰄱" end
		end
		return false
	end)()]=],
			2000 * H.load_factor()
		),
		"Git-dir event did not refresh the panel"
	)
	local staged_line = vim.split(H.git(dirty, { "show", ":d.txt" }), "\n", { plain = true })[3]
	eq(
		child.lua_get([=[require("gleb.git.changes").state.by_tab[...].diff_view.index.lines[3]]=], { panel_tab }),
		staged_line
	)
end

T["git: Changes panels isolate two tabs"] = function()
	local first = open_fixture("dirty")
	local first_tab = child.api.nvim_get_current_tabpage()
	child.cmd("tabnew")
	local second = open_fixture("dirty")
	local second_tab = child.api.nvim_get_current_tabpage()
	child.lua("_G.changes_tabs = { ... }", { first_tab, second_tab })
	H.write_files(first, { ["first.txt"] = "first\n" })
	H.write_files(second, { ["second.txt"] = "second\n" })

	child.api.nvim_exec_autocmds("FocusGained", {})

	assert(
		child.wait(
			[=[(function()
		local state = require("gleb.git.changes").state.by_tab
		local one, two = state[_G.changes_tabs[1]], state[_G.changes_tabs[2]]
		return one and two and one.generation > 1 and two.generation > 1
	end)()]=],
			2000 * H.load_factor()
		),
		"Both tab refreshes did not run"
	)
	assert(
		child.wait(
			[=[(function()
		local state = require("gleb.git.changes").state.by_tab
		local one, two = state[_G.changes_tabs[1]], state[_G.changes_tabs[2]]
		local function has(view, path)
			for _, row in ipairs(view.rows) do if row.path == path then return true end end
		end
		return one and two and has(one, "first.txt") and has(two, "second.txt")
			and not has(one, "second.txt") and not has(two, "first.txt")
	end)()]=],
			2000 * H.load_factor()
		),
		"Tab refreshes were not isolated"
	)
	eq(
		child.lua_get(
			[=[(function(...)
		local state = require("gleb.git.changes").state.by_tab
		local one, two = state[(...)], state[select(2, ...)]
		return { one.timer ~= two.timer, one.generation > 1, two.generation > 1 }
	end)(...)]=],
			{ first_tab, second_tab }
		),
		{ true, true, true }
	)
end

return T
