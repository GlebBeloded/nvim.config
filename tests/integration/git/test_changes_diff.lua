local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

---@param root string
---@param selected? string
local function open_changes(root, selected)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	if selected then
		child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, selected)))
	else
		child.cmd("enew")
	end
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("changes.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	eq(
		child.wait(
			[[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view ~= nil and #view.rows > 0
		end)()]],
			ASYNC_MS
		),
		true
	)
end

local function observe_show()
	child.lua([[
		DiffShows = {}
		local diff = require("gleb.diff.view")
		local show = diff.show
		diff.show = function(win, spec)
			table.insert(DiffShows, {
				path = spec.path,
				relpath = spec.relpath,
				left = spec.left,
				right = spec.right,
				actionable = spec.actionable,
				head_final_newline = spec.head_final_newline,
				filetype = spec.filetype,
			})
			return show(win, spec)
		end
	]])
end

---@param path string
local function cursor_before(path)
	child.lua(
		[[
		local path = ...
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for index, row in ipairs(view.rows) do
			if row.path == path then
				assert(index > 1, "target has no preceding row")
				vim.api.nvim_win_set_cursor(view.win, { index - 1, 0 })
				return
			end
		end
		error("missing row: " .. path)
	]],
		{ path }
	)
end

local function wait_for_shows(count)
	eq(child.wait(("#DiffShows == %d"):format(count), ASYNC_MS), true)
end

---@param path string
---@param content string
local function write_binary(path, content)
	local file = assert(vim.uv.fs_open(path, "w", 420))
	assert(vim.uv.fs_write(file, content, 0))
	assert(vim.uv.fs_close(file))
end

---@param root string
---@param selected? string
local function review_changes(root, selected)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	if selected then
		child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, selected)))
	else
		child.cmd("enew")
	end
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("changes.review"))
		action.run(require("gleb.actions.context").capture())
	]])
end

T["git: Changes panel j shows the next file in the diff view"] = function()
	local root = F.copy("billing", vim.fn.tempname() .. "/billing")
	open_changes(root, "internal/billing/invoice.go")
	observe_show()
	local tabs = #child.api.nvim_list_tabpages()

	child.type_keys("j")
	wait_for_shows(1)

	local result = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local diff = panel.diff_view
		return {
			show = DiffShows[1],
			left = vim.api.nvim_buf_get_lines(diff.left_buf, 0, -1, false),
			right = vim.api.nvim_buf_get_lines(diff.right_buf, 0, -1, false),
			filetype = vim.bo[vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())].filetype,
		}
	end)()]])
	eq(result.show.relpath, "internal/billing/invoice_test.go")
	assert(
		vim.iter(result.left):any(function(line)
			return line:find("TestTotal", 1, true) ~= nil
		end),
		"HEAD side is not invoice_test.go"
	)
	assert(
		vim.iter(result.right):any(function(line)
			return line:find("TestDue", 1, true) ~= nil
		end),
		"working side is not invoice_test.go"
	)
	eq({ #child.api.nvim_list_tabpages(), result.filetype }, { tabs, "gleb-changes" })
end

T["git: Changes panel debounces rapid moves"] = function()
	local root = F.copy("billing", vim.fn.tempname() .. "/billing")
	open_changes(root, "internal/billing/invoice.go")
	observe_show()

	child.type_keys("jj")
	wait_for_shows(1)

	eq(child.lua_get("DiffShows[1].relpath"), "internal/billing/tax.go")
	local seen_invoice_test = child.lua_get([[
		vim.iter(DiffShows):any(function(item) return item.relpath == "internal/billing/invoice_test.go" end)
	]])
	eq(seen_invoice_test, false)
end

T["git: Changes panel shows an untracked file as added"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root)
	observe_show()
	cursor_before("new.txt")

	child.type_keys("j")
	wait_for_shows(1)

	local shown = child.lua_get("DiffShows[1]")
	eq({ shown.relpath, shown.left, shown.right, shown.actionable }, {
		"new.txt",
		{},
		{ "new", "untracked", "file" },
		false,
	})
end

T["git: Changes panel shows a deleted file"] = function()
	local root = H.git_repo({ ["a.txt"] = "one\n" })
	vim.fn.delete(vim.fs.joinpath(root, "a.txt"))
	open_changes(root)
	observe_show()
	cursor_before("a.txt")

	child.type_keys("j")
	wait_for_shows(1)

	local shown = child.lua_get("DiffShows[1]")
	eq({ shown.relpath, shown.left, shown.right, shown.actionable }, {
		"a.txt",
		{ "one" },
		{},
		false,
	})
	local right_buf = child.lua_get([[
		require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].diff_view.right_buf
	]])
	eq(child.lua_get("vim.bo[...].modifiable", { right_buf }), false)
end

T["git: Changes panel binary row uses a read-only diff"] = function()
	local root = H.git_repo({})
	local path = vim.fs.joinpath(root, "image.bin")
	write_binary(path, "old\0binary")
	H.git(root, { "add", "image.bin" })
	H.git(root, { "commit", "-qm", "binary" })
	write_binary(path, "new\0binary")
	open_changes(root)
	observe_show()
	cursor_before("image.bin")

	child.type_keys("j")
	wait_for_shows(1)

	local result = child.lua_get(
		[[(function(path)
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			actionable = DiffShows[1].actionable,
			modifiable = vim.bo[panel.diff_view.right_buf].modifiable,
			named_buf = vim.fn.bufnr(path, false),
		}
	end)(...)]],
		{ path }
	)
	eq(result, { actionable = false, modifiable = false, named_buf = -1 })
end

T["git: Changes panel unmerged row uses a read-only diff"] = function()
	local root = H.git_repo({ ["conflict.txt"] = "base\n" })
	H.git(root, { "checkout", "-q", "-b", "other" })
	H.write_files(root, { ["conflict.txt"] = "other\n" })
	H.git(root, { "commit", "-qam", "other" })
	H.git(root, { "checkout", "-q", "main" })
	H.write_files(root, { ["conflict.txt"] = "main\n" })
	H.git(root, { "commit", "-qam", "main" })
	local merge = vim.system({ "git", "merge", "other" }, { cwd = root, text = true }):wait()
	eq(merge.code ~= 0, true)
	local path = vim.fs.joinpath(root, "conflict.txt")
	open_changes(root)
	observe_show()
	cursor_before("conflict.txt")

	child.type_keys("j")
	wait_for_shows(1)

	local result = child.lua_get(
		[[(function(path)
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			actionable = DiffShows[1].actionable,
			modifiable = vim.bo[panel.diff_view.right_buf].modifiable,
			named_buf = vim.fn.bufnr(path, false),
		}
	end)(...)]],
		{ path }
	)
	eq(result, { actionable = false, modifiable = false, named_buf = -1 })
end

T["git: Changes panel submodule row has no diff"] = function()
	local child_root = H.git_repo({ ["library.txt"] = "old\n" })
	local root = H.git_repo({})
	H.git(root, { "-c", "protocol.file.allow=always", "submodule", "add", "-q", child_root, "vendor/library" })
	H.git(root, { "commit", "-qam", "submodule" })
	H.write_files(vim.fs.joinpath(root, "vendor/library"), { ["library.txt"] = "new\n" })
	open_changes(root)
	observe_show()
	local notifications = H.record_notify(child)
	cursor_before("vendor/library")

	child.type_keys("j")
	eq(child.wait("#Notifications == 1", ASYNC_MS), true)

	eq(child.lua_get("#DiffShows"), 0)
	eq(child.lua_get("vim.fn.bufnr(..., false)", { vim.fs.joinpath(root, "vendor/library") }), -1)
	eq(notifications(), { { msg = "No file content: library", level = vim.log.levels.INFO } })
end

T["git: Changes panel closes a contentless diff"] = function()
	local root = H.git_repo({ ["a.txt"] = "old\n", ["mode.txt"] = "same\n" })
	H.write_files(root, { ["a.txt"] = "new\n" })
	assert(vim.uv.fs_chmod(vim.fs.joinpath(root, "mode.txt"), 493))
	open_changes(root)
	observe_show()
	local notifications = H.record_notify(child)
	cursor_before("a.txt")
	child.type_keys("j")
	wait_for_shows(1)
	cursor_before("mode.txt")

	child.type_keys("j")
	wait_for_shows(2)

	eq(
		child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return panel.diff_view == nil
	end)()]]),
		true
	)
	eq(notifications(), { { msg = "No content changes: mode.txt", level = vim.log.levels.INFO } })
end

T["git: Changes panel keeps the diff on a directory row"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root)
	observe_show()
	cursor_before("lib/c.lua")
	child.type_keys("j")
	wait_for_shows(1)

	child.type_keys("k")
	child.lua([[vim.wait(100)]])

	local result = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local row = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
		return { row = row.kind, diff = panel.diff_view.relpath, shows = #DiffShows }
	end)()]=])
	eq(result, { row = "directory", diff = "lib/c.lua", shows = 1 })
end

T["git: Changes panel drops a stale diff result"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root)
	observe_show()
	child.lua([[
		PendingDiffLoads = {}
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		require("gleb.file_tree.watch").stop_root(panel.root, panel.buf)
		local git = require("gleb.git.changes.git")
		local load_diff = git.load_diff
		git.load_diff = function(load_root, row, callback)
			load_diff(load_root, row, function(spec)
				table.insert(PendingDiffLoads, { callback = callback, spec = spec })
			end)
		end
	]])
	cursor_before("a.txt")
	child.type_keys("j")
	eq(child.wait("#PendingDiffLoads == 1", ASYNC_MS), true)

	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		RowsBeforeRefresh = panel.rows
		require("gleb.git.changes.view").schedule_refresh(panel)
	]])
	eq(
		child.wait(
			[[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].rows ~= RowsBeforeRefresh]],
			ASYNC_MS
		),
		true
	)
	cursor_before("b.txt")
	child.type_keys("j")
	eq(
		child.wait([[vim.iter(PendingDiffLoads):any(function(load) return load.spec.relpath == "b.txt" end)]], ASYNC_MS),
		true
	)
	child.lua([[vim.wait(100)]])

	child.lua([[
		local stale = assert(vim.iter(PendingDiffLoads):find(function(load) return load.spec.relpath == "a.txt" end))
		local current
		for index = #PendingDiffLoads, 1, -1 do
			if PendingDiffLoads[index].spec.relpath == "b.txt" then
				current = PendingDiffLoads[index]
				break
			end
		end
		assert(current, "missing current diff load")
		current.callback(current.spec)
		stale.callback(stale.spec)
	]])
	eq(child.lua_get("vim.iter(DiffShows):map(function(item) return item.relpath end):totable()"), { "b.txt" })
end

T["git: Changes panel skips an unchanged selection"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root)
	observe_show()
	cursor_before("a.txt")
	child.type_keys("j")
	wait_for_shows(1)

	local generation = child.lua_get([[
		require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].generation
	]])
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		require("gleb.git.changes.view").schedule_refresh(panel)
	]])
	eq(
		child.wait(
			("require('gleb.git.changes').state.by_tab[vim.api.nvim_get_current_tabpage()].generation > %d"):format(
				generation
			),
			ASYNC_MS
		),
		true
	)
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_exec_autocmds("CursorMoved", { buffer = panel.buf })
		vim.wait(100)
	]])

	eq(child.lua_get("#DiffShows"), 1)
end

T["git: Changes panel review shows the current file's diff"] = function()
	local root = F.copy("billing", vim.fn.tempname() .. "/billing")
	observe_show()

	review_changes(root, "internal/billing/invoice.go")
	wait_for_shows(1)

	local result = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local row = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
		return {
			current_win = vim.api.nvim_get_current_win(),
			panel_win = panel.win,
			row = row.path,
			diff = panel.diff_view.relpath,
		}
	end)()]=])
	eq(result, {
		current_win = result.panel_win,
		panel_win = result.panel_win,
		row = "internal/billing/invoice.go",
		diff = "internal/billing/invoice.go",
	})
end

T["git: Changes panel review without a changed current file"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	observe_show()

	review_changes(root)
	wait_for_shows(1)

	local result = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local row = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
		return { row = row.path, diff = panel.diff_view.relpath }
	end)()]=])
	eq(result, { row = "lib/c.lua", diff = "lib/c.lua" })
end

T["git: Changes panel review replaces the dashboard"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	eq(child.bo.filetype, "alpha")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("changes.review"))
		action.run(require("gleb.actions.context").capture())
	]])
	eq(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel ~= nil and panel.diff_view ~= nil
			end)()]],
			ASYNC_MS
		),
		true
	)

	local result = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local alpha_windows = vim.iter(vim.api.nvim_tabpage_list_wins(0)):filter(function(win)
			return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "alpha"
		end):totable()
		return {
			current_win = vim.api.nvim_get_current_win(),
			panel_win = panel.win,
			diff = panel.diff_view.relpath,
			alpha_windows = #alpha_windows,
		}
	end)()]=])
	eq(result.alpha_windows, 0)
	eq(result, {
		current_win = result.panel_win,
		panel_win = result.panel_win,
		diff = "lib/c.lua",
		alpha_windows = 0,
	})
end

T["git: Changes panel ]f steps through every changed file"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	observe_show()
	review_changes(root)
	wait_for_shows(1)
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.diff_view.right_win)
	]])

	for count = 2, 5 do
		child.type_keys("]f")
		wait_for_shows(count)
	end

	local result = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local row = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
		return {
			shown = vim.iter(DiffShows):map(function(item) return item.relpath end):totable(),
			row = row.path,
		}
	end)()]=])
	eq(result, {
		shown = { "lib/c.lua", "a.txt", "b.txt", "d.txt", "new.txt" },
		row = "new.txt",
	})
end

T["git: Changes panel ]f keeps diff focus"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	observe_show()
	review_changes(root)
	wait_for_shows(1)
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.diff_view.right_win)
	]])

	child.type_keys("]f")
	wait_for_shows(2)

	local result = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			current_win = vim.api.nvim_get_current_win(),
			right_win = panel.diff_view.right_win,
			relpath = panel.diff_view.relpath,
		}
	end)()]])
	eq(result, {
		current_win = result.right_win,
		right_win = result.right_win,
		relpath = "a.txt",
	})
end

T["git: Changes panel Enter opens the file"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root, "a.txt")
	observe_show()
	cursor_before("b.txt")
	child.type_keys("j")
	wait_for_shows(1)

	child.type_keys("<CR>")

	local result = child.lua_get([[(function()
		local filetypes = {}
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			filetypes[vim.bo[vim.api.nvim_win_get_buf(win)].filetype] = true
		end
		return {
			current = vim.fs.normalize(vim.api.nvim_buf_get_name(0)),
			changes = filetypes["gleb-changes"] or false,
			diff = filetypes["gleb-diff"] or false,
		}
	end)()]])
	eq(result, {
		current = assert(vim.uv.fs_realpath(vim.fs.joinpath(root, "b.txt"))),
		changes = true,
		diff = false,
	})
end

T["git: Changes panel file is an independent normal buffer"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root, "a.txt")
	observe_show()
	cursor_before("b.txt")
	child.type_keys("j")
	wait_for_shows(1)

	child.type_keys("<CR>")

	local opened = child.lua_get([[(function()
		local buf = vim.api.nvim_get_current_buf()
		return {
			buf = buf,
			listed = vim.bo[buf].buflisted,
			buftype = vim.bo[buf].buftype,
			path = vim.fs.normalize(vim.api.nvim_buf_get_name(buf)),
		}
	end)()]])
	eq({ opened.listed, opened.buftype, opened.path }, {
		true,
		"",
		assert(vim.uv.fs_realpath(vim.fs.joinpath(root, "b.txt"))),
	})

	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.win)
	]])
	child.type_keys("q")

	eq(
		child.lua_get(
			[[(function(buf)
				return {
					vim.api.nvim_buf_is_valid(buf),
					vim.api.nvim_buf_is_loaded(buf),
					vim.bo[buf].buflisted,
					vim.bo[buf].buftype,
					vim.fs.normalize(vim.api.nvim_buf_get_name(buf)),
				}
			end)(...)]],
			{ opened.buf }
		),
		{
			true,
			true,
			true,
			"",
			assert(vim.uv.fs_realpath(vim.fs.joinpath(root, "b.txt"))),
		}
	)
end

T["git: Changes panel q closes the panel and the diff view"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root, "a.txt")
	observe_show()
	local tabs = #child.api.nvim_list_tabpages()
	cursor_before("b.txt")
	child.type_keys("j")
	wait_for_shows(1)

	child.type_keys("q")

	local result = child.lua_get([[(function()
		local filetypes = {}
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			filetypes[vim.bo[vim.api.nvim_win_get_buf(win)].filetype] = true
		end
		return {
			current = vim.fs.normalize(vim.api.nvim_buf_get_name(0)),
			changes = filetypes["gleb-changes"] or false,
			diff = filetypes["gleb-diff"] or false,
		}
	end)()]])
	eq({ #child.api.nvim_list_tabpages(), result }, {
		tabs,
		{
			current = assert(vim.uv.fs_realpath(vim.fs.joinpath(root, "a.txt"))),
			changes = false,
			diff = false,
		},
	})
end

T["git: Changes panel close preserves another diff view"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	-- Hold the panel's initial a.txt load so it lands after the cursor left a.txt.
	child.lua([[
		HeldDiffLoads = {}
		local git = require("gleb.git.changes.git")
		local load_diff = git.load_diff
		git.load_diff = function(load_root, row, callback)
			load_diff(load_root, row, function(...)
				if vim.fs.basename(row.path) == "a.txt" then
					table.insert(HeldDiffLoads, { callback = callback, args = vim.F.pack_len(...) })
				else
					callback(...)
				end
			end)
		end
	]])
	open_changes(root, "a.txt")
	local handles = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.editor_win)
		local action = assert(require("gleb.actions").state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
		local other = assert(require("gleb.diff.view").current())
		vim.api.nvim_set_current_tabpage(panel.tab)
		vim.api.nvim_set_current_win(panel.win)
		return { other_left = other.left_win, other_right = other.right_win }
	end)()]])
	eq(child.wait("#HeldDiffLoads == 1", ASYNC_MS), true)
	observe_show()
	cursor_before("b.txt")
	child.type_keys("j")
	child.lua([[
		local held = HeldDiffLoads[1]
		held.callback(vim.F.unpack_len(held.args))
	]])
	wait_for_shows(1)
	local owned = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return { left = panel.diff_view.left_win, right = panel.diff_view.right_win }
	end)()]])

	child.type_keys("q")

	eq(child.api.nvim_win_is_valid(owned.left), false)
	eq(child.api.nvim_win_is_valid(owned.right), true)
	eq(child.api.nvim_win_is_valid(handles.other_left), true)
	eq(child.api.nvim_win_is_valid(handles.other_right), true)
	eq(child.lua_get([[require("gleb.diff.view").state.by_win[...] ~= nil]], { handles.other_right }), true)
end

T["git: Changes panel unloads its clean file buffer"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root, "a.txt")
	local path = assert(vim.uv.fs_realpath(vim.fs.joinpath(root, "b.txt")))
	eq(child.fn.bufloaded(path), 0)
	observe_show()
	cursor_before("b.txt")
	child.type_keys("j")
	wait_for_shows(1)
	eq(child.fn.bufloaded(path), 1)

	child.type_keys("q")

	eq(child.fn.bufloaded(path), 0)
end

T["git: Project tree replaces the changes panel"] = function()
	local root = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(root, "a.txt")
	observe_show()
	cursor_before("b.txt")
	child.type_keys("j")
	wait_for_shows(1)

	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	eq(child.wait([[vim.bo.filetype == "gleb-file-tree"]], ASYNC_MS), true)

	local result = child.lua_get([[(function()
		local filetypes = {}
		local leftmost
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
			filetypes[filetype] = true
			local column = vim.api.nvim_win_get_position(win)[2]
			if not leftmost or column < leftmost.column then
				leftmost = { column = column, filetype = filetype, win = win }
			end
		end
		return {
			changes = filetypes["gleb-changes"] or false,
			diff = filetypes["gleb-diff"] or false,
			leftmost = leftmost.filetype,
			focused = vim.api.nvim_get_current_win() == leftmost.win,
		}
	end)()]])
	eq(result, { changes = false, diff = false, leftmost = "gleb-file-tree", focused = true })
end

return T
