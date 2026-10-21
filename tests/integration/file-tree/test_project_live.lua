local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

local function start()
	root = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	F.disable_file_tree_nesting(child)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.lua([[require("gleb.file_tree.fs").reset()]])
end

local T = H.child_set(child, start)

local function record_fs_poll_calls()
	child.lua([[
		_G.fs_poll_calls = 0
		local new_fs_poll = vim.uv.new_fs_poll
		vim.uv.new_fs_poll = function(...)
			_G.fs_poll_calls = _G.fs_poll_calls + 1
			return new_fs_poll(...)
		end
	]])
end

---@param relative string
local function record_fallback_scans(relative)
	child.lua(
		[[
		local fs = require("gleb.file_tree.fs")
		local tree_root, target = ...
		_G.fallback_root = fs.normalize(tree_root)
		target = fs.normalize(target)
		_G.fallback_scans = 0
		local scan_stamp_async = fs.scan_stamp_async
		fs.scan_stamp_async = function(path, callback)
			scan_stamp_async(path, function(stamp)
				if path == target then
					_G.fallback_scans = _G.fallback_scans + 1
				end
				callback(stamp)
			end)
		end
	]],
		{ root, vim.fs.joinpath(root, relative) }
	)
end

local function expect_no_fs_poll_on_macos()
	local result = child.lua_get([[{ vim.uv.os_uname().sysname, _G.fs_poll_calls }]])
	if result[1] == "Darwin" then
		eq(result[2], 0)
	end
end

---@param relative string
local function edit(relative)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, relative)))
end

---@param id string
local function run_action(id)
	child.lua(
		[[(function(id)
			local catalog = require("gleb.actions").state.applicator.catalog
			local action = assert(catalog:get(id), id .. " is not registered")
			action.run(require("gleb.actions.context").capture())
		end)(...)]],
		{ id }
	)
	if id == "file_tree.toggle" or id == "file_tree.reveal" then
		local opened =
			child.lua_get([[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]])
		if opened then
			assert(
				child.wait(
					[[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]]
				)
			)
		end
	end
end

---@return integer[]
local function tree_position()
	return child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return { view.win, vim.api.nvim_win_get_cursor(view.win)[1] }
	end)()]])
end

---@return string
local function selected_tree_line()
	return child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local row = vim.api.nvim_win_get_cursor(view.win)[1]
		return vim.api.nvim_buf_get_lines(view.buf, row - 1, row, false)[1]
	end)()]])
end

---@param name string
local function focus_tree_row(name)
	local found = child.lua_get(
		[[(function(name)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for row, line in ipairs(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)) do
				if line:find(name, 1, true) then
					vim.api.nvim_win_set_cursor(view.win, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ name }
	)
	assert(found, "tree row not found: " .. name)
end

---@param relative string
local function focus_tree_path(relative)
	local found = child.lua_get(
		[[(function(path)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for index, row in ipairs(view.rows) do
				if row.path == path then
					vim.api.nvim_win_set_cursor(view.win, { index, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ vim.fs.joinpath(assert(vim.uv.fs_realpath(root)), relative) }
	)
	assert(found, "tree path not found: " .. relative)
end

---@param name string
---@return boolean
local function wait_for_tree_row(name)
	return child.lua_get(
		[[(function(name, timeout)
			return vim.wait(timeout, function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view and vim.iter(view.rows):any(function(row)
					return row.label == name
				end)
			end, 20)
		end)(...)]],
		{ name, math.ceil(1000 * H.load_factor()) }
	)
end

local function wait_for_live_stream()
	local confirmed = child.lua_get(
		[[(function(path, timeout)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local state = assert(require("gleb.file_tree.watch").state.roots[view.root])
			return vim.wait(timeout, function()
				if state.event_confirmed then
					return true
				end
				if state.discovery_complete and not state.sync_scheduled then
					vim.fn.writefile({ tostring(vim.uv.hrtime()) }, path)
				end
				return false
			end, 20)
		end)(...)]],
		{ vim.fs.joinpath(root, "watch-canary.lua"), math.ceil(3000 * H.load_factor()) }
	)
	assert(confirmed, "watch event stream was not confirmed")
	assert(wait_for_tree_row("watch-canary.lua"), "watch canary row did not appear")
	assert(
		child.wait(
			[[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				local watch_state = assert(require("gleb.file_tree.watch").state.roots[view.root])
				local git_state = assert(require("gleb.file_tree.git").state.roots[view.root])
				for _, timer in pairs(watch_state.timers) do
					if timer:is_active() then
						return false
					end
				end
				return not watch_state.fallback_scanning
					and not view.dirty
					and view.dirty_timer == nil
					and not view.git_pending
					and git_state.timer == nil
					and not git_state.in_flight
			end)()]],
			math.ceil(3000 * H.load_factor())
		),
		"watch canary work did not settle"
	)
end

---@param name string
---@param group string
---@return boolean
local function wait_for_tree_highlight(name, group)
	return child.lua_get(
		[[(function(name, group, timeout)
			return vim.wait(timeout, function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not view then
					return false
				end
				for index, row in ipairs(view.rows) do
					if row.label == name then
						local marks = vim.api.nvim_buf_get_extmarks(
							view.buf,
							require("gleb.file_tree.render").namespace,
							{ index - 1, 0 },
							{ index - 1, -1 },
							{ details = true }
						)
						return vim.iter(marks):any(function(mark)
							return mark[4].hl_group == group
						end)
					end
				end
				return false
			end, 20)
		end)(...)]],
		{ name, group, math.ceil(1000 * H.load_factor()) }
	)
end

local function open_billing_folder()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")
	focus_tree_path("internal/billing")
	child.type_keys("<CR>")
end

T["file-tree: Project tree follows the current file"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("wincmd l")
	local editor = child.api.nvim_get_current_win()

	edit("internal/money/money.go")

	eq(child.api.nvim_get_current_win(), editor)
	assert(
		child.wait(
			[=[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				return view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].label == "money.go"
			end)()]=],
			math.ceil(1000 * H.load_factor())
		),
		"project tree did not follow the current file"
	)
	eq(selected_tree_line():match("[^ ]+$"), "money.go")
	local money_line = child.lua_get([[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.iter(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)):find(function(line)
			return line:find("money", 1, true) ~= nil and line:find("money.go", 1, true) == nil
		end)
	end)()]])
	assert(money_line:find("", 1, true), "money row is not expanded")
end

T["file-tree: Project tree ignores files outside the root"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("wincmd l")
	focus_tree_row("go.mod")
	local outside = vim.fn.tempname()
	vim.fn.writefile({ "outside" }, outside)

	child.cmd("edit " .. vim.fn.fnameescape(outside))

	eq(selected_tree_line():match("[^ ]+$"), "go.mod")
	child.cmd("edit " .. vim.fn.fnameescape(outside .. "-missing"))
	eq(selected_tree_line():match("[^ ]+$"), "go.mod")
end

T["file-tree: Project tree reveal focuses the current file"] = function()
	edit("internal/money/money.go")

	run_action("file_tree.reveal")

	local position = tree_position()
	eq(child.api.nvim_get_current_win(), position[1])
	eq(selected_tree_line():match("[^ ]+$"), "money.go")
end

T["file-tree: Project tree reveal tolerates a deleted file"] = function()
	edit("internal/money/money.go")
	child.fn.delete(vim.fs.joinpath(root, "internal/money/money.go"))
	local notifications = H.record_notify(child)

	run_action("file_tree.reveal")

	local position = tree_position()
	eq(child.api.nvim_get_current_win(), position[1])
	eq(position[2], 1)
	eq(notifications(), {})
end

T["file-tree: Project tree follow tolerates a deleted file"] = function()
	edit("internal/money/money.go")
	local deleted_buf = child.api.nvim_get_current_buf()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("go.mod")
	child.cmd("wincmd l")
	child.fn.delete(vim.fs.joinpath(root, "internal/money/money.go"))
	local notifications = H.record_notify(child)

	child.api.nvim_set_current_buf(deleted_buf)

	local position = tree_position()
	eq(position[2], 1)
	eq(notifications(), {})
end

T["file-tree: Project tree toggle tolerates a deleted file"] = function()
	edit("internal/money/money.go")
	child.fn.delete(vim.fs.joinpath(root, "internal/money/money.go"))
	local notifications = H.record_notify(child)

	run_action("file_tree.toggle")

	local position = tree_position()
	eq(position[2], 1)
	eq(notifications(), {})
end

T["file-tree: Project tree does not follow a directory buffer"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("wincmd l")
	focus_tree_row("go.mod")
	local before = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return { view.root, vim.api.nvim_win_get_cursor(view.win) }
	end)()]])
	local notifications = H.record_notify(child)

	child.lua(
		[[(function(path)
			local buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(buf, path)
			vim.api.nvim_set_current_buf(buf)
		end)(...)]],
		{ vim.fs.joinpath(root, "internal") }
	)

	local after = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return { view.root, vim.api.nvim_win_get_cursor(view.win) }
	end)()]])
	eq(after, before)
	eq(selected_tree_line():match("[^ ]+$"), "go.mod")
	eq(notifications(), {})
end

T["file-tree: Project tree normalizes a symlinked root"] = function()
	local linked_home = vim.fn.tempname()
	child.lua([[assert(vim.uv.fs_symlink(...))]], { vim.fs.dirname(root), linked_home })
	child.lua([[vim.env.HOME = ...]], { linked_home })
	local linked_root = vim.fs.joinpath(linked_home, vim.fs.basename(root))
	child.cmd("cd " .. vim.fn.fnameescape(linked_root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(linked_root, "internal/money/money.go")))
	local notifications = H.record_notify(child)

	run_action("file_tree.toggle")

	local actual = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return {
			root = view.root,
			root_line = vim.api.nvim_buf_get_lines(view.buf, 0, 1, false)[1],
		}
	end)()]])
	eq(actual.root, assert(vim.uv.fs_realpath(root)))
	eq(actual.root_line:sub(-#("~/" .. vim.fs.basename(root))), "~/" .. vim.fs.basename(root))
	eq(selected_tree_line():match("[^ ]+$"), "money.go")
	eq(notifications(), {})
end

T["file-tree: Project tree cuts a symlink loop"] = function()
	child.lua([[assert(vim.uv.fs_symlink(".", ...))]], { vim.fs.joinpath(root, "loop") })
	child.lua([[require("gleb.file_tree.fs").reset()]])
	local notifications = H.record_notify(child)
	edit("README.md")
	run_action("file_tree.toggle")

	child.type_keys("zR")

	local loop_rows = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return vim.iter(view.rows):filter(function(row)
			return row.label == "loop"
		end):totable()
	end)()]])
	eq(#loop_rows, 1)
	eq(loop_rows[1].kind, "directory")
	eq(loop_rows[1].empty, true)
	eq(notifications(), {})
end

T["file-tree: Project tree tolerates an unreadable folder"] = function()
	local locked = vim.fs.joinpath(root, "locked")
	vim.fn.mkdir(locked, "p")
	vim.fn.writefile({ "secret" }, vim.fs.joinpath(locked, "secret.txt"))
	assert(vim.uv.fs_chmod(locked, 0))
	child.lua([[require("gleb.file_tree.fs").reset()]])
	local notifications = H.record_notify(child)
	edit("README.md")
	run_action("file_tree.toggle")

	focus_tree_row("locked")
	child.type_keys("<CR>")

	local locked_rows = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return vim.iter(view.rows):filter(function(row)
			return row.path:find("/locked", 1, true) ~= nil
		end):totable()
	end)()]])
	eq(#locked_rows, 1)
	eq(locked_rows[1].kind, "directory")
	eq(locked_rows[1].empty, true)
	eq(notifications(), {})
	assert(vim.uv.fs_chmod(locked, 448))
end

T["file-tree: A compact chain splits when a folder gains an entry"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	eq(wait_for_tree_row("cmd/server"), true)
	wait_for_live_stream()

	local result = H.system(child, { "mkdir", vim.fs.joinpath(root, "cmd/worker") }, root)
	eq(result.code, 0)

	eq(wait_for_tree_row("cmd"), true)
	eq(wait_for_tree_row("server"), true)
	eq(wait_for_tree_row("worker"), true)
	eq(wait_for_tree_row("cmd/server"), false)
end

T["file-tree: Every compact chain member is watched"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	eq(wait_for_tree_row("cmd/server"), true)

	local watched = child.lua_get(
		[[(function(root, timeout)
			root = require("gleb.file_tree.fs").normalize(root)
			local ready = vim.wait(timeout, function()
				local handles = assert(require("gleb.file_tree.watch").state.roots[root]).handles
				return handles[root .. "/cmd"] ~= nil and handles[root .. "/cmd/server"] ~= nil
			end, 20)
			return { ready, ready }
		end)(...)]],
		{ root, math.ceil(3000 * H.load_factor()) }
	)
	eq(watched, { true, true })
	wait_for_live_stream()

	local result = H.system(child, { "mkdir", vim.fs.joinpath(root, "cmd/worker") }, root)
	eq(result.code, 0)
	eq(wait_for_tree_row("cmd"), true)
	eq(wait_for_tree_row("server"), true)
	eq(wait_for_tree_row("worker"), true)
end

T["file-tree: Project tree shows files created outside Neovim"] = function()
	record_fs_poll_calls()
	record_fallback_scans("internal/billing")
	open_billing_folder()
	assert(
		child.wait(
			[[
			_G.fallback_scans >= 2
				and not require("gleb.file_tree.watch").state.roots[_G.fallback_root].fallback_scanning
		]],
			math.ceil(3000 * H.load_factor())
		),
		"two fallback scans did not complete"
	)
	eq(child.lua_get([[require("gleb.file_tree.watch").state.roots[_G.fallback_root].fallback_timer ~= nil]]), true)

	wait_for_live_stream()

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "internal/billing/fee.go") }, root)
	eq(result.code, 0)

	eq(wait_for_tree_highlight("fee.go", "FileTreeGitUntracked"), true)
	expect_no_fs_poll_on_macos()
end

T["file-tree: Project tree recolours a written file"] = function()
	open_billing_folder()
	child.cmd("wincmd l")
	edit("internal/billing/discount.go")
	child.api.nvim_buf_set_lines(0, -1, -1, false, { "// changed" })

	child.cmd("write")

	eq(wait_for_tree_highlight("discount.go", "FileTreeGitModified"), true)
end

T["file-tree: Project tree refresh survives initial git completion"] = function()
	local status = vim.system({
		"git",
		"--no-optional-locks",
		"-C",
		root,
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=normal",
		"--ignored=matching",
	}, { text = true }):wait()
	eq(status.code, 0)
	child.lua(
		[=[
		local status_output = ...
		local original_system = vim.system
		_G.file_tree_original_system = original_system
		_G.file_tree_status_callbacks = {}
		vim.system = function(command, options, callback)
			if callback and command[5] == "status" then
				_G.file_tree_status_callbacks[#_G.file_tree_status_callbacks + 1] = callback
				_G.file_tree_status_output = status_output
				return {}
			end
			return original_system(command, options, callback)
		end
	]=],
		{ status.stdout }
	)
	edit("README.md")
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	assert(
		child.wait(
			[[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				return require("gleb.file_tree.watch").toplevel(view.root) ~= nil
					and #_G.file_tree_status_callbacks == 1
			end)()]],
			math.ceil(1000 * H.load_factor())
		),
		"repository discovery did not start git status"
	)
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local editor = assert(require("gleb.file_tree.view").state.last_editor_by_tab[view.tab])
		vim.api.nvim_win_call(editor, function()
			vim.api.nvim_buf_set_lines(0, 0, 1, false, { "changed before first git result" })
			vim.cmd.write()
		end)
		local callback = table.remove(_G.file_tree_status_callbacks, 1)
		callback({ code = 0, stdout = _G.file_tree_status_output, stderr = "" })
	]])
	assert(
		child.wait([[#_G.file_tree_status_callbacks == 1]], math.ceil(1000 * H.load_factor())),
		"write did not queue a second git status"
	)
	child.lua([[
		local callback = table.remove(_G.file_tree_status_callbacks, 1)
		callback({ code = 0, stdout = _G.file_tree_status_output, stderr = "" })
		vim.system = _G.file_tree_original_system
	]])
	assert(
		child.wait(
			[[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]],
			math.ceil(1000 * H.load_factor())
		)
	)

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "after-initial-git.txt") }, root)
	eq(result.code, 0)
	eq(wait_for_tree_row("after-initial-git.txt"), true)
end

T["file-tree: Project tree refresh survives failed git status"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	assert(
		child.wait(
			[[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				local state = assert(require("gleb.file_tree.git").state.roots[view.root])
				return state.timer == nil and not state.in_flight and not view.git_pending
			end)()]],
			math.ceil(1000 * H.load_factor())
		),
		"initial git status did not settle"
	)
	eq(vim.fn.rename(vim.fs.joinpath(root, ".git"), vim.fs.joinpath(root, ".git-removed")), 0)
	local baseline_runs = child.lua_get([[require("gleb.file_tree.git").state.runs]])
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local editor = assert(require("gleb.file_tree.view").state.last_editor_by_tab[view.tab])
		vim.api.nvim_win_call(editor, function()
			vim.api.nvim_buf_set_lines(0, 0, 1, false, { "changed after git removal" })
			vim.cmd.write()
		end)
	]])
	assert(
		child.wait(
			([[(function()
				local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
				local git = require("gleb.file_tree.git")
				local state = assert(git.state.roots[view.root])
				return git.state.runs > %d and state.timer == nil and not state.in_flight
			end)()]]):format(baseline_runs),
			math.ceil(1000 * H.load_factor())
		),
		"failed git status did not complete"
	)

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "after-failed-git.txt") }, root)
	eq(result.code, 0)
	eq(wait_for_tree_row("after-failed-git.txt"), true)
end

T["file-tree: Project tree recolours after staging outside Neovim"] = function()
	record_fs_poll_calls()
	edit("README.md")
	run_action("file_tree.toggle")
	eq(wait_for_tree_highlight("notes.md", "FileTreeGitUntracked"), true)

	local result = H.system(child, { "git", "add", "notes.md" }, root)
	eq(result.code, 0)

	eq(wait_for_tree_highlight("notes.md", "FileTreeGitAdded"), true)
	expect_no_fs_poll_on_macos()
end

T["file-tree: Project tree recolours staging during watch startup"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	eq(wait_for_tree_highlight("notes.md", "FileTreeGitUntracked"), true)
	-- Stopping the git dir handle drops the staging event the way a rebuilding macOS FSEvents stream does.
	local unconfirmed = child.lua_get(
		[[(function(tree_root)
			local state = assert(require("gleb.file_tree.watch").state.roots[require("gleb.file_tree.fs").normalize(tree_root)])
			assert(state.git_handle):stop()
			return not state.event_confirmed
		end)(...)]],
		{ root }
	)
	eq(unconfirmed, true)

	local result = H.system(child, { "git", "add", "notes.md" }, root)
	eq(result.code, 0)

	eq(wait_for_tree_highlight("notes.md", "FileTreeGitAdded"), true)
end

T["file-tree: Project tree watchers stop when the tree closes"] = function()
	edit("README.md")
	run_action("file_tree.toggle")

	local handle_count = child.lua_get(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		local state = assert(require("gleb.file_tree.watch").state.roots[root])
		_G.file_tree_closed_handles = vim.tbl_values(state.handles)
		return #_G.file_tree_closed_handles
	end)(...)]],
		{ root }
	)
	assert(handle_count > 0, "expected the open tree to own folder watchers")

	child.type_keys("q")
	local stopped = child.lua_get(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		return vim.wait(1000, function()
			local watch = require("gleb.file_tree.watch")
			return watch.state.roots[root] == nil
				and vim.iter(_G.file_tree_closed_handles):all(function(handle)
					return handle:is_closing()
				end)
		end, 20)
	end)(...)]],
		{ root }
	)
	eq(stopped, true)

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "żółć.lua") }, root)
	eq(result.code, 0)
	run_action("file_tree.toggle")
	eq(wait_for_tree_row("żółć.lua"), true)
end

T["file-tree: Project tree prunes a deleted expanded folder"] = function()
	open_billing_folder()
	focus_tree_path("internal/billing/invoice_test.go")
	child.lua(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		_G.file_tree_deleted_handle = assert(
			require("gleb.file_tree.watch").state.roots[root].handles[root .. "/internal/billing"]
		)
	end)(...)]],
		{ root }
	)

	local result = H.system(child, { "rm", "-r", vim.fs.joinpath(root, "internal/billing") }, root)
	eq(result.code, 0)

	local pruned = child.lua_get(
		[[(function(timeout)
		return vim.wait(timeout, function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local cursor = vim.api.nvim_win_get_cursor(view.win)[1]
			return view.expanded["internal/billing"] == nil
				and vim.iter(view.rows):all(function(row)
					return not row.path:find("/internal/billing", 1, true)
				end)
				and cursor <= #view.rows
				and _G.file_tree_deleted_handle:is_closing()
		end, 20)
		end)(...)]],
		{ math.ceil(1000 * H.load_factor()) }
	)
	eq(pruned, true)
end

T["file-tree: Project tree caps watched folders"] = function()
	child.lua([[require("gleb.file_tree.watch").MAX_WATCH_HANDLES = 2]])
	edit("README.md")
	run_action("file_tree.toggle")

	local watched = child.lua_get(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local handles = assert(require("gleb.file_tree.watch").state.roots[root]).handles
		return {
			handle_count = vim.tbl_count(handles),
			has_compact_row = vim.iter(view.rows):any(function(row)
				return row.label == "cmd/server"
			end),
			has_unwatched_row = vim.iter(view.rows):any(function(row)
				return row.label == "internal"
			end),
		}
	end)(...)]],
		{ root }
	)
	eq(watched, { handle_count = 2, has_compact_row = true, has_unwatched_row = true })
end

T["file-tree: Project tree updates the last folder beyond the legacy watch limit"] = function()
	local expanded = {}
	for index = 1, 257 do
		local relative = ("z-folder-%03d"):format(index)
		local directory = vim.fs.joinpath(root, relative)
		vim.fn.mkdir(directory, "p")
		vim.fn.writefile({ "seed" }, vim.fs.joinpath(directory, "seed.txt"))
		expanded[relative] = true
	end
	child.lua(
		[[(function(root, paths)
			require("gleb.file_tree.expanded").save(require("gleb.file_tree.fs").normalize(root), paths)
		end)(...)]],
		{ root, expanded }
	)

	edit("z-folder-001/seed.txt")
	run_action("file_tree.toggle")
	local target = vim.fs.joinpath(root, "z-folder-257")
	local unwatched = child.lua_get(
		[[(function(root, path, timeout)
			root = require("gleb.file_tree.fs").normalize(root)
			path = require("gleb.file_tree.fs").normalize(path)
			return vim.wait(timeout, function()
				local handles = assert(require("gleb.file_tree.watch").state.roots[root]).handles
				return vim.tbl_count(handles) == 256 and handles[path] == nil
			end, 20)
		end)(...)]],
		{ root, target, math.ceil(3000 * H.load_factor()) }
	)
	eq(unwatched, true)

	local result = H.system(child, { "touch", vim.fs.joinpath(target, "last.txt") }, root)
	eq(result.code, 0)
	eq(wait_for_tree_row("last.txt"), true)
end

T["file-tree: Project tree shares root work across tabs"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("tabnew " .. vim.fn.fnameescape(vim.fs.joinpath(root, "go.mod")))
	run_action("file_tree.toggle")

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "shared.lua") }, root)
	eq(result.code, 0)
	local shared = child.lua_get(
		[[(function(root, timeout)
		root = require("gleb.file_tree.fs").normalize(root)
		return vim.wait(timeout, function()
			local views = vim.tbl_values(require("gleb.file_tree.view").state.by_tab)
			return #views == 2 and vim.iter(views):all(function(view)
				return vim.iter(view.rows):any(function(row)
					return row.label == "shared.lua"
				end)
			end)
		end, 20) and {
			git_refs = require("gleb.file_tree.git").state.roots[root].refs,
			watch_refs = require("gleb.file_tree.watch").state.roots[root].refs,
		}
	end)(...)]],
		{ root, math.ceil(1000 * H.load_factor()) }
	)
	eq(shared, { git_refs = 2, watch_refs = 2 })
end

T["file-tree: Project tree isolates tabpage state"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	local first_tab = child.api.nvim_get_current_tabpage()
	focus_tree_row("internal")

	child.cmd("tabnew " .. vim.fn.fnameescape(vim.fs.joinpath(root, "go.mod")))
	run_action("file_tree.toggle")
	local second_tab = child.api.nvim_get_current_tabpage()
	focus_tree_row("go.mod")
	local second = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return { buf = view.buf, cursor = vim.api.nvim_win_get_cursor(view.win), autocmds = vim.deepcopy(view.autocmds) }
	end)()]])

	child.cmd("tabprevious")
	child.type_keys("<CR>")
	child.cmd("tabclose")
	eq(child.api.nvim_get_current_tabpage(), second_tab)
	wait_for_live_stream()

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "isolated.lua") }, root)
	eq(result.code, 0)
	local isolated = child.lua_get(
		[[(function(first_tab, expected, root, timeout)
		root = require("gleb.file_tree.fs").normalize(root)
		local ready = vim.wait(timeout, function()
			local state = require("gleb.file_tree.view").state
			local view = state.by_tab[vim.api.nvim_get_current_tabpage()]
			return state.by_tab[first_tab] == nil
				and view ~= nil
				and view.buf == expected.buf
				and vim.deep_equal(vim.api.nvim_win_get_cursor(view.win), expected.cursor)
				and vim.deep_equal(view.autocmds, expected.autocmds)
				and vim.iter(view.rows):any(function(row)
					return row.label == "isolated.lua"
				end)
		end, 20)
		return ready and {
			git_refs = require("gleb.file_tree.git").state.roots[root].refs,
			watch_refs = require("gleb.file_tree.watch").state.roots[root].refs,
		} or false
	end)(...)]],
		{ first_tab, second, root, math.ceil(1000 * H.load_factor()) }
	)
	eq(isolated, { git_refs = 1, watch_refs = 1 })
end

T["file-tree: Project tree re-roots on a cwd change"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	local other = F.copy("treeproj", vim.fn.tempname() .. "/other")
	H.write_files(other, { ["other-root.txt"] = "other\n" })

	child.cmd("cd " .. vim.fn.fnameescape(other))
	local actual = child.lua_get(
		[[(function(old_root)
		return vim.wait(1000, function()
			local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view
				and view.root == require("gleb.file_tree.fs").normalize(vim.fn.getcwd())
				and vim.iter(view.rows):any(function(row)
					return row.label == "other-root.txt"
				end)
		end, 20) and {
			root = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].root,
			old_watch = require("gleb.file_tree.watch").state.roots[require("gleb.file_tree.fs").normalize(old_root)] ~= nil,
		}
	end)(...)]],
		{ root }
	)
	eq(actual, { root = assert(vim.uv.fs_realpath(other)), old_watch = false })
end

T["file-tree: Project tree expanded folders persist per root"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")
	run_action("file_tree.close")

	local other = F.copy("treeproj", vim.fn.tempname() .. "/other")
	child.cmd("cd " .. vim.fn.fnameescape(other))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(other, "README.md")))
	run_action("file_tree.toggle")
	focus_tree_row("web")
	child.type_keys("<CR>")
	run_action("file_tree.close")

	child.cmd("cd " .. vim.fn.fnameescape(root))
	run_action("file_tree.toggle")
	local first = child.lua_get(
		[[vim.deepcopy(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded)]]
	)
	run_action("file_tree.close")
	child.cmd("cd " .. vim.fn.fnameescape(other))
	run_action("file_tree.toggle")
	local second = child.lua_get(
		[[vim.deepcopy(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded)]]
	)
	eq(first, { internal = true })
	eq(second, { web = true })
end

T["file-tree: Project tree drops a stored folder that is gone"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")
	run_action("file_tree.close")
	eq(H.system(child, { "rm", "-r", vim.fs.joinpath(root, "internal") }, root).code, 0)

	run_action("file_tree.toggle")
	local expanded = child.lua_get(
		[[vim.deepcopy(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded)]]
	)
	run_action("file_tree.close")
	local stored = child.lua_get(
		[[(function(root, timeout)
			local expanded = require("gleb.file_tree.expanded")
			assert(vim.wait(timeout, function()
				return not expanded.state.writing and next(expanded.state.pending) == nil
			end, 20), "expanded state did not settle")
			local path = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "expanded.json")
			return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))[root]
		end)(...)]],
		{ assert(vim.uv.fs_realpath(root)), math.ceil(1000 * H.load_factor()) }
	)
	eq(expanded, {})
	eq(stored, {})
end

T["file-tree: Project tree atomically merges expansion state"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")

	local other = F.copy("treeproj", vim.fn.tempname() .. "/other")
	child.cmd("tabnew " .. vim.fn.fnameescape(vim.fs.joinpath(other, "README.md")))
	child.cmd("cd " .. vim.fn.fnameescape(other))
	run_action("file_tree.toggle")
	focus_tree_row("web")
	child.type_keys("<CR>")
	child.cmd("tabclose")
	run_action("file_tree.close")

	local stored = child.lua_get(
		[[(function(timeout)
		local expanded = require("gleb.file_tree.expanded")
		assert(vim.wait(timeout, function()
			return not expanded.state.writing and next(expanded.state.pending) == nil
		end, 20), "expanded state did not settle")
		local directory = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree")
		local path = vim.fs.joinpath(directory, "expanded.json")
		return {
			value = vim.json.decode(table.concat(vim.fn.readfile(path), "\n")),
			temporary = vim.fn.globpath(directory, "expanded.json.*", false, true),
		}
	end)(...)]],
		{ math.ceil(1000 * H.load_factor()) }
	)
	eq(stored, {
		value = {
			[assert(vim.uv.fs_realpath(root))] = { "internal" },
			[assert(vim.uv.fs_realpath(other))] = { "web" },
		},
		temporary = {},
	})
end

T["file-tree: Project tree re-roots across git worktrees"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	local linked = vim.fn.tempname() .. "/linked"
	eq(H.system(child, { "git", "worktree", "add", "-q", "-b", "linked-test", linked }, root).code, 0)
	local expected_top = vim.trim(H.system(child, { "git", "-C", linked, "rev-parse", "--show-toplevel" }, root).stdout)
	local expected_git =
		vim.trim(H.system(child, { "git", "-C", linked, "rev-parse", "--absolute-git-dir" }, root).stdout)

	child.cmd("cd " .. vim.fn.fnameescape(linked))
	local actual = child.lua_get([[(function()
		return vim.wait(1000, function()
			local root = require("gleb.file_tree.fs").normalize(vim.fn.getcwd())
			local state = require("gleb.file_tree.watch").state.roots[root]
			return state and state.toplevel and state.git_dir
		end, 20) and (function()
			local root = require("gleb.file_tree.fs").normalize(vim.fn.getcwd())
			local state = require("gleb.file_tree.watch").state.roots[root]
			return { root = root, toplevel = state.toplevel, git_dir = state.git_dir }
		end)()
	end)()]])
	eq(actual, { root = assert(vim.uv.fs_realpath(linked)), toplevel = expected_top, git_dir = expected_git })
end

return T
