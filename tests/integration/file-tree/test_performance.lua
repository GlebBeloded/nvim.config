local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

local function create_large_tree()
	root = vim.fn.tempname() .. "/large-tree"
	vim.fn.mkdir(root, "p")
	for directory_index = 1, 1999 do
		local directory = vim.fs.joinpath(root, ("directory-%04d"):format(directory_index))
		vim.fn.mkdir(directory, "p")
		local file_count = directory_index <= 850 and 2 or 1
		for file_index = 1, file_count do
			local path = vim.fs.joinpath(directory, ("file-%03d"):format(file_index))
			local file = assert(vim.uv.fs_open(path, "w", 420))
			assert(vim.uv.fs_close(file))
		end
	end
	for file_index = 1, 50 do
		local path = vim.fs.joinpath(root, ("root-file-%03d"):format(file_index))
		local file = assert(vim.uv.fs_open(path, "w", 420))
		assert(vim.uv.fs_close(file))
	end
	local expandable = vim.fs.joinpath(root, "expand-me")
	vim.fn.mkdir(expandable, "p")
	for file_index = 1, 100 do
		local path = vim.fs.joinpath(expandable, ("file-%03d"):format(file_index))
		local file = assert(vim.uv.fs_open(path, "w", 420))
		assert(vim.uv.fs_close(file))
	end
	H.write_files(root, {
		["ignored-data/status.txt"] = "ignored\n",
	})
	H.git(root, { "init", "-q", "-b", "main" })
	H.write_files(root, { [".git/info/exclude"] = "ignored-data/\n" })
	H.git(root, { "config", "user.name", "Test" })
	H.git(root, { "config", "user.email", "test@example.com" })
	H.git(root, { "config", "commit.gpgsign", "false" })
	H.git(root, { "add", "-A" })
	H.git(root, { "commit", "-q", "-m", "initial" })
end

local function start()
	create_large_tree()
	child.start_config()
	child.wait_very_lazy()
	F.disable_file_tree_nesting(child)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "root-file-001")))
	child.type_keys("<M-e>")
	assert(
		child.wait(
			[=[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil and #view.rows > 0
	end)()]=],
			math.ceil(3000 * H.load_factor())
		),
		"project tree did not open"
	)
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for index = 1, 1999 do
			view.expanded[("directory-%04d"):format(index)] = true
		end
		require("gleb.file_tree.view").redraw_all()
	]])
	assert(
		child.wait(
			[=[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				local git = require("gleb.file_tree.git")
				local state = git.state.roots[view.root]
				return state and git.state.runs > 0 and state.timer == nil and not state.in_flight
			end)()]=],
			3000
		),
		"initial git status did not settle"
	)
end

local T = H.child_set(child, start)

local function install_replacement_counter()
	child.lua([=[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		FileTreeOriginalSetLines = vim.api.nvim_buf_set_lines
		FileTreeReplacementCount = 0
		vim.api.nvim_buf_set_lines = function(buf, ...)
			if buf == view.buf then
				FileTreeReplacementCount = FileTreeReplacementCount + 1
			end
			return FileTreeOriginalSetLines(buf, ...)
		end
	]=])
end

local function change_tracked_file()
	child.lua(
		[=[(function(path)
			local view_module = require("gleb.file_tree.view")
			local tab = vim.api.nvim_get_current_tabpage()
			local editor = assert(view_module.state.last_editor_by_tab[tab])
			vim.api.nvim_set_current_win(editor)
			vim.cmd.edit(vim.fn.fnameescape(path))
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "changed" })
		end)(...)]=],
		{ vim.fs.joinpath(root, "directory-0001", "file-001") }
	)
end

local function wait_for_save_result(baseline_runs)
	return child.lua_get(
		[=[(function(baseline)
			local row_status
			local complete = vim.wait(1000, function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				local git = require("gleb.file_tree.git")
				local state = git.state.roots[view.root]
				if not state or state.timer ~= nil or state.in_flight or git.state.runs <= baseline then
					return false
				end
				local changed_path = vim.fs.joinpath(view.root, "directory-0001", "file-001")
				for _, row in ipairs(view.rows) do
					if row.path == changed_path then
						row_status = row.status or "none"
						return row.status == "modified"
					end
				end
				row_status = "missing"
				return false
			end, 10)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			return {
				complete = complete,
				dirty = view.dirty,
				git_pending = view.git_pending,
				replacements = FileTreeReplacementCount,
				row_status = row_status,
				runs = require("gleb.file_tree.git").state.runs - baseline,
			}
		end)(...)]=],
		{ baseline_runs }
	)
end

T["file-tree: Project tree redraw meets the large-tree bound"] = function()
	eq(child.lua_get([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows]]), 4900)
	install_replacement_counter()

	local result = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local lines = vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)
		local selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path
		local started = vim.uv.hrtime()
		require("gleb.file_tree.view").redraw_all()
		local elapsed_ms = (vim.uv.hrtime() - started) / 1e6
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			elapsed_ms = elapsed_ms,
			replacements = FileTreeReplacementCount,
			rows_preserved = vim.deep_equal(lines, vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)),
			selection_preserved = selected == view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path,
		}
	end)()]=])

	assert(result.elapsed_ms <= 100 * H.load_factor(), ("redraw took %.2f ms"):format(result.elapsed_ms))
	eq(result.replacements, 1)
	eq(result.rows_preserved, true)
	eq(result.selection_preserved, true)
end

T["file-tree: Project tree expansion meets the large-tree bound"] = function()
	eq(child.lua_get([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows]]), 4900)
	local found = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for index, row in ipairs(view.rows) do
			if row.label == "expand-me" then
				vim.api.nvim_set_current_win(view.win)
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return true
			end
		end
		return false
	end)()]=])
	eq(found, true)
	install_replacement_counter()
	child.lua([[FileTreeExpansionStarted = vim.uv.hrtime()]])

	child.type_keys("<CR>")

	local result = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local elapsed_ms = (vim.uv.hrtime() - FileTreeExpansionStarted) / 1e6
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			elapsed_ms = elapsed_ms,
			replacements = FileTreeReplacementCount,
			rows = #view.rows,
			expanded = view.expanded["expand-me"] == true,
		}
	end)()]=])

	assert(result.elapsed_ms <= 100 * H.load_factor(), ("expansion took %.2f ms"):format(result.elapsed_ms))
	eq(result.replacements, 1)
	eq(result.rows, 5000)
	eq(result.expanded, true)
end

T["file-tree: Project tree coalesces a save burst"] = function()
	change_tracked_file()
	install_replacement_counter()
	local baseline_runs = child.lua_get([[require("gleb.file_tree.git").state.runs]])

	child.cmd("write")
	local result = wait_for_save_result(baseline_runs)

	assert(result.complete, vim.inspect(result))
	eq(result.replacements, 1)
	eq(result.runs, 1)
end

T["file-tree: Unchanged git status does not redraw the project tree"] = function()
	install_replacement_counter()
	local baseline_runs = child.lua_get([[require("gleb.file_tree.git").state.runs]])
	child.lua([[require("gleb.file_tree.git").refresh(...)]], { root })
	assert(
		child.wait(
			([=[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				local git = require("gleb.file_tree.git")
				local state = git.state.roots[view.root]
				return git.state.runs == %d and state.timer == nil and not state.in_flight
			end)()]=]):format(baseline_runs + 1),
			1000
		),
		"unchanged git status did not finish"
	)

	eq(child.lua_get([[FileTreeReplacementCount]]), 0)
end

T["file-tree: Project tree save leaves the main path promptly"] = function()
	child.lua([=[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		view.expanded["expand-me"] = true
		require("gleb.file_tree.view").redraw_all()
	]=])
	eq(child.lua_get([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows]]), 5000)
	change_tracked_file()
	install_replacement_counter()
	local baseline_runs = child.lua_get([[require("gleb.file_tree.git").state.runs]])

	local elapsed_ms = child.lua_get([=[(function()
		local started = vim.uv.hrtime()
		vim.cmd.write()
		return (vim.uv.hrtime() - started) / 1e6
	end)()]=])
	local result = wait_for_save_result(baseline_runs)

	assert(elapsed_ms <= 100 * H.load_factor(), ("write took %.2f ms"):format(elapsed_ms))
	assert(result.complete, vim.inspect(result))
end

return T
