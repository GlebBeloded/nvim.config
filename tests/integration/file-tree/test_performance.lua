local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root
local second_root
local unfold_root

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
				return state
					and git.state.runs > 0
					and state.timer == nil
					and not state.in_flight
					and not view.dirty
					and view.dirty_timer == nil
					and not view.git_pending
					and not require("gleb.file_tree.expanded").state.loading
			end)()]=],
			math.ceil(3000 * H.load_factor())
		),
		"initial project tree did not settle"
	)
end

local T = H.child_set(child, start)

local unfold_child = H.new_child()

local function create_unfold_tree()
	unfold_root = vim.fn.tempname() .. "/unfold-tree"
	vim.fn.mkdir(unfold_root, "p")
	H.write_files(unfold_root, {
		[".gitignore"] = "folder-60/\n",
		["README.md"] = "fixture\n",
	})
	for folder_index = 1, 60 do
		local directory = vim.fs.joinpath(unfold_root, ("folder-%02d"):format(folder_index))
		vim.fn.mkdir(directory, "p")
		for file_index = 1, 50 do
			for _, suffix in ipairs({ ".ts", ".test.ts" }) do
				local path = vim.fs.joinpath(directory, ("source-%03d%s"):format(file_index, suffix))
				local file = assert(vim.uv.fs_open(path, "w", 420))
				assert(vim.uv.fs_close(file))
			end
		end
	end
	H.git(unfold_root, { "init", "-q", "-b", "main" })
end

local function start_unfold()
	create_unfold_tree()
	unfold_child.start_config()
	unfold_child.wait_very_lazy()
	unfold_child.lua([[require("gleb.file_tree.settings").setup({ path = ... })]], {
		vim.fs.joinpath(H.root, "settings", "file_tree.json"),
	})
	unfold_child.cmd("cd " .. vim.fn.fnameescape(unfold_root))
	unfold_child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(unfold_root, "README.md")))
	unfold_child.type_keys("<M-e>")
	assert(
		unfold_child.wait(
			[=[(function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view ~= nil and #view.rows > 0
			end)()]=],
			math.ceil(3000 * H.load_factor())
		),
		"project tree did not open"
	)
	assert(
		unfold_child.wait(
			[=[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				local git = require("gleb.file_tree.git")
				local state = git.state.roots[view.root]
				if not state or git.state.runs == 0 or state.timer ~= nil or state.in_flight then
					return false
				end
				return not vim.iter(view.rows):any(function(row)
					return row.label == "folder-60"
				end)
			end)()]=],
			math.ceil(10000 * H.load_factor())
		),
		"project tree ignore state did not settle"
	)
end

T["file-tree: Project tree unfold all meets the large-tree bound"] = H.child_set(unfold_child, start_unfold)
T["file-tree: Project tree unfold all meets the large-tree bound"]["stops promptly at the row limit"] = function()
	local notifications = H.record_notify(unfold_child)
	eq(
		unfold_child.lua_get(
			[[vim.tbl_count(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded)]]
		),
		0
	)
	unfold_child.lua([[FileTreeUnfoldStarted = vim.uv.hrtime()]])

	unfold_child.type_keys("zR")

	local result = unfold_child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return {
			elapsed_ms = (vim.uv.hrtime() - FileTreeUnfoldStarted) / 1e6,
			rows = #view.rows,
		}
	end)()]])
	assert(result.elapsed_ms <= 500 * H.load_factor(), ("unfold all took %.2f ms"):format(result.elapsed_ms))
	assert(result.rows <= 5001, "unfold all exceeded the row limit")
	eq(notifications(), {
		{ msg = "Unfold all stopped at 5000 rows", level = vim.log.levels.WARN },
	})
end

local function create_second_worktree()
	second_root = vim.fn.tempname() .. "-worktree"
	H.git(root, { "worktree", "add", "-q", "-b", "performance-reroot", second_root })
	second_root = assert(vim.uv.fs_realpath(second_root))
end

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

local function install_cpu_measurement()
	child.lua([=[
		local function process_cpu_ms(usage)
			return (usage.utime.sec + usage.stime.sec) * 1000 + (usage.utime.usec + usage.stime.usec) / 1000
		end

		FileTreeStartMeasurement = function()
			return {
				cpu_ms = process_cpu_ms(vim.uv.getrusage()),
				elapsed_ns = vim.uv.hrtime(),
			}
		end

		FileTreeFinishMeasurement = function(started)
			return {
				cpu_ms = process_cpu_ms(vim.uv.getrusage()) - started.cpu_ms,
				elapsed_ms = (vim.uv.hrtime() - started.elapsed_ns) / 1e6,
			}
		end
	]=])
end

local function make_next_git_refresh_immediate()
	child.lua(
		[=[
		local root = ...
		local original = vim.system
		local prefix = original({ "git", "-C", root, "rev-parse", "--show-prefix" }, { text = true }):wait()
		local command = assert(require("gleb.file_tree.git").state.last_cmd)
		local status = original(command, { text = true }):wait()
		local results = { prefix, status }
		local expected = {
			{ "git", "-C", root, "rev-parse", "--show-prefix" },
			command,
		}
		local next_result = 1
		vim.system = function(cmd, opts, callback)
			if callback and vim.deep_equal(cmd, expected[next_result]) then
				local result = results[next_result]
				next_result = next_result + 1
				if next_result > #results then
					vim.system = original
				end
				vim.schedule(function()
					callback(result)
				end)
				return {}
			end
			return original(cmd, opts, callback)
		end
	]=],
		{ root }
	)
end

local function install_open_replacement_counter()
	child.lua([=[
		FileTreeOriginalSetLines = vim.api.nvim_buf_set_lines
		FileTreeReplacementCount = 0
		vim.api.nvim_buf_set_lines = function(buf, ...)
			local name = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) or ""
			if vim.startswith(name, "gleb-file-tree://") then
				FileTreeReplacementCount = FileTreeReplacementCount + 1
			end
			return FileTreeOriginalSetLines(buf, ...)
		end
	]=])
end

local function delay_next_expansion_read()
	child.lua([=[
		local original = vim.uv.fs_open
		vim.uv.fs_open = function(path, flags, mode, callback)
			if callback and flags == "r" and vim.endswith(path, "/file_tree/expanded.json") then
				vim.uv.fs_open = original
				vim.defer_fn(function()
					original(path, flags, mode, callback)
				end, 500)
				return
			end
			return original(path, flags, mode, callback)
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
		[=[(function(baseline, timeout)
			local row_status
			local complete = vim.wait(timeout, function()
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
		{ baseline_runs, math.ceil(1000 * H.load_factor()) }
	)
end

T["file-tree: Project tree redraw meets the large-tree bound"] = function()
	eq(child.lua_get([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows]]), 4900)
	install_replacement_counter()
	install_cpu_measurement()

	local result = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local lines = vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)
		local selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path
		local started = FileTreeStartMeasurement()
		require("gleb.file_tree.view").redraw_all()
		local measurement = FileTreeFinishMeasurement(started)
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			cpu_ms = measurement.cpu_ms,
			elapsed_ms = measurement.elapsed_ms,
			replacements = FileTreeReplacementCount,
			rows_preserved = vim.deep_equal(lines, vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)),
			selection_preserved = selected == view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path,
		}
	end)()]=])

	assert(result.cpu_ms <= 100, ("redraw consumed %.2f ms process CPU"):format(result.cpu_ms))
	if vim.env.PERF == "1" then
		assert(result.elapsed_ms <= 100 * H.load_factor(), ("redraw took %.2f ms"):format(result.elapsed_ms))
	end
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
	install_cpu_measurement()
	child.lua([[FileTreeExpansionStarted = FileTreeStartMeasurement()]])

	child.type_keys("<CR>")

	local result = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local measurement = FileTreeFinishMeasurement(FileTreeExpansionStarted)
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			cpu_ms = measurement.cpu_ms,
			elapsed_ms = measurement.elapsed_ms,
			replacements = FileTreeReplacementCount,
			rows = #view.rows,
			expanded = view.expanded["expand-me"] == true,
		}
	end)()]=])

	assert(result.cpu_ms <= 100, ("expansion consumed %.2f ms process CPU"):format(result.cpu_ms))
	if vim.env.PERF == "1" then
		assert(result.elapsed_ms <= 100 * H.load_factor(), ("expansion took %.2f ms"):format(result.elapsed_ms))
	end
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
	make_next_git_refresh_immediate()
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
			math.ceil(1000 * H.load_factor())
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

T["file-tree: Project tree follows an already listed row promptly"] = function()
	child.lua([=[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		view.expanded["expand-me"] = true
		require("gleb.file_tree.view").redraw_all()
	]=])
	eq(child.lua_get([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows]]), 5000)
	install_replacement_counter()

	local target = assert(vim.uv.fs_realpath(vim.fs.joinpath(root, "root-file-050")))
	local result = child.lua_get(
		[=[(function(path)
			local view_module = require("gleb.file_tree.view")
			local view = assert(view_module.state.by_tab[vim.api.nvim_get_current_tabpage()])
			local editor = assert(view_module.state.last_editor_by_tab[view.tab])
			vim.api.nvim_set_current_win(editor)
			local started = vim.uv.hrtime()
			vim.cmd.edit(vim.fn.fnameescape(path))
			local elapsed_ms = (vim.uv.hrtime() - started) / 1e6
			local selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
			vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
			return {
				elapsed_ms = elapsed_ms,
				focused = vim.api.nvim_get_current_win() == editor,
				replacements = FileTreeReplacementCount,
				selected = selected and selected.path,
			}
		end)(...)]=],
		{ target }
	)

	assert(result.elapsed_ms <= 50 * H.load_factor(), ("follow took %.2f ms"):format(result.elapsed_ms))
	eq(result.replacements, 0)
	eq(result.selected, target)
	eq(result.focused, true)
end

T["file-tree: Project tree opens once with saved expansion"] = function()
	assert(
		child.wait([[next(require("gleb.file_tree.expanded").state.pending) == nil]], math.ceil(1000 * H.load_factor())),
		"initial expansion state did not persist"
	)
	child.restart_config({ "--cmd", "cd " .. vim.fn.fnameescape(root) })
	child.wait_very_lazy()
	F.disable_file_tree_nesting(child)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "root-file-001")))
	delay_next_expansion_read()
	install_open_replacement_counter()

	child.type_keys("<M-e>")

	assert(
		child.wait(
			[[(function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view
					and not view.initializing
					and not require("gleb.file_tree.expanded").state.loading
					and view.expanded["directory-0001"] == true
			end)()]],
			math.ceil(3000 * H.load_factor())
		),
		"project tree did not open with saved expansion state"
	)
	local result = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			replacements = FileTreeReplacementCount,
			child_listed = view.rows_by_path[vim.fs.joinpath(view.root, "directory-0001", "file-001")] ~= nil,
		}
	end)()]])
	eq(result.child_listed, true)
	eq(result.replacements, 1)
end

T["file-tree: Project tree re-roots without waiting for repository discovery"] = function()
	create_second_worktree()

	local result = child.lua_get(
		[=[(function(path)
			local started = vim.uv.hrtime()
			vim.cmd.cd(vim.fn.fnameescape(path))
			return (vim.uv.hrtime() - started) / 1e6
		end)(...)]=],
		{ second_root }
	)

	assert(result <= 100 * H.load_factor(), ("re-root took %.2f ms"):format(result))
	assert(
		child.wait(
			([=[(function(path)
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				local watched = require("gleb.file_tree.watch").state.roots[path]
				return view and view.root == path and watched and watched.git_handle ~= nil
			end)(%q)]=]):format(second_root),
			1000
		),
		"re-rooted tree did not settle with a git-directory watch"
	)
end

T["file-tree: Project tree re-roots once with saved expansion"] = function()
	create_second_worktree()
	child.lua([[require("gleb.file_tree.expanded").save(..., { ["directory-0001"] = true })]], { second_root })
	assert(
		child.wait([[next(require("gleb.file_tree.expanded").state.pending) == nil]], math.ceil(1000 * H.load_factor())),
		"second-root expansion state did not persist"
	)
	child.lua([[require("gleb.file_tree.expanded").reset()]])
	delay_next_expansion_read()
	install_replacement_counter()

	child.cmd("cd " .. vim.fn.fnameescape(second_root))

	assert(
		child.wait(
			([[(function(path)
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view
					and view.root == path
					and not view.initializing
					and not require("gleb.file_tree.expanded").state.loading
					and view.expanded["directory-0001"] == true
			end)(%q)]]):format(second_root),
			math.ceil(3000 * H.load_factor())
		),
		"re-rooted tree did not load saved expansion state"
	)
	local rerooted = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			replacements = FileTreeReplacementCount,
			child_listed = view.rows_by_path[vim.fs.joinpath(view.root, "directory-0001", "file-001")] ~= nil,
		}
	end)()]])
	eq(rerooted.child_listed, true)
	eq(rerooted.replacements, 1)
end

T["file-tree: Project tree persists folds off the action path"] = function()
	local found = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for index, row in ipairs(view.rows) do
			if row.label == "directory-0001" then
				vim.api.nvim_set_current_win(view.win)
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return true
			end
		end
		return false
	end)()]=])
	eq(found, true)
	child.lua([[FileTreeFoldStarted = vim.uv.hrtime()]])

	child.type_keys("za")

	local elapsed_ms = child.lua_get([[(vim.uv.hrtime() - FileTreeFoldStarted) / 1e6]])
	assert(elapsed_ms <= 100 * H.load_factor(), ("fold took %.2f ms"):format(elapsed_ms))
	local normalized_root = assert(vim.uv.fs_realpath(root))
	assert(
		child.wait(
			([=[(function(expected_root)
				local path = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "expanded.json")
				local file = io.open(path, "r")
				if not file then
					return false
				end
				local content = file:read("*a")
				file:close()
				local ok, stored = pcall(vim.json.decode, content)
				if not ok or type(stored[expected_root]) ~= "table" then
					return false
				end
				return not vim.tbl_contains(stored[expected_root], "directory-0001")
			end)(%q)]=]):format(normalized_root),
			1000
		),
		"collapsed expansion state was not persisted"
	)
end

T["file-tree: Project tree persists a last-moment fold on exit"] = function()
	local found = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for index, row in ipairs(view.rows) do
			if row.label == "directory-0001" then
				vim.api.nvim_set_current_win(view.win)
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return row.expanded
			end
		end
		return false
	end)()]=])
	eq(found, true)

	child.type_keys("za")
	child.api_notify.nvim_command("qa!")
	child.restart_config({ "--cmd", "cd " .. vim.fn.fnameescape(root) })
	child.wait_very_lazy()
	F.disable_file_tree_nesting(child)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "root-file-001")))
	child.type_keys("<M-e>")
	assert(
		child.wait(
			[[(function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view and not view.initializing and not require("gleb.file_tree.expanded").state.loading
			end)()]],
			math.ceil(3000 * H.load_factor())
		),
		"restarted project tree did not settle"
	)
	local restored = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return {
			expanded = view.expanded["directory-0001"] == true,
			child_listed = view.rows_by_path[vim.fs.joinpath(view.root, "directory-0001", "file-001")] ~= nil,
		}
	end)()]])
	eq(restored.expanded, false)
	eq(restored.child_listed, false)
end

return T
