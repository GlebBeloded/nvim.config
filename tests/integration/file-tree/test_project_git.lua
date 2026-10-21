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
	child.cmd("cd " .. vim.fn.fnameescape(root))
end

local T = H.child_set(child, start)

local function run_toggle()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
	local opened =
		child.lua_get([[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]])
	if opened then
		assert(
			child.wait([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]])
		)
	end
end

---@param name string
local function focus_tree_row(name)
	local found = child.lua_get(
		[[(function(name)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for index, row in ipairs(view.rows) do
				if row.label == name then
					vim.api.nvim_win_set_cursor(view.win, { index, 0 })
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
---@param group string
local function expect_tree_highlight(name, group)
	local found = child.lua_get(
		[[(function(name, group)
			return vim.wait(3000, function()
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
		{ name, group }
	)
	assert(found, ("expected %s on %s"):format(group, name))
end

local function open_tree()
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "README.md")))
	run_toggle()
end

local function expand_billing()
	focus_tree_row("internal")
	child.type_keys("<CR>")
	focus_tree_path("internal/billing")
	child.type_keys("<CR>")
end

T["file-tree: Project tree folders take the strongest status below them"] = MiniTest.new_set()

T["file-tree: Project tree folders take the strongest status below them"]["colours changed files"] = function()
	open_tree()
	expand_billing()

	expect_tree_highlight("invoice.go", "FileTreeGitModified")
	expect_tree_highlight("tax.go", "FileTreeGitAdded")
	expect_tree_highlight("notes.md", "FileTreeGitUntracked")
	expect_tree_highlight("discount.go", "FileTreeFileName")
	expect_tree_highlight("go.mod", "FileTreeFileName")

	run_toggle()
	child.cmd("cd " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal")))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	run_toggle()
	expect_tree_highlight("invoice.go", "FileTreeGitModified")
end

T["file-tree: Project tree folders take the strongest status below them"]["uses the strongest descendant"] = function()
	H.write_files(root, {
		["docs/api.md"] = "# API\n",
		["scratch/todo.txt"] = "todo\n",
	})
	H.git(root, { "add", "docs/api.md" })
	open_tree()

	expect_tree_highlight("internal", "FileTreeGitModified")
	expect_tree_highlight("web", "FileTreeGitModified")
	expect_tree_highlight("docs", "FileTreeGitAdded")
	expect_tree_highlight("scratch", "FileTreeGitUntracked")
	expect_tree_highlight("cmd/server", "FileTreeFolderName")
	expect_tree_highlight("billing", "FileTreeRoot")
end

T["file-tree: Project tree colours renamed and conflicted files"] = function()
	H.git(root, { "config", "user.name", "Test" })
	H.git(root, { "config", "user.email", "test@example.com" })
	H.git(root, { "add", "-A" })
	H.git(root, { "commit", "-q", "-m", "fixture state" })
	H.git(root, { "checkout", "-q", "-b", "other" })
	H.write_files(root, { ["go.mod"] = "module example.com/other\n\ngo 1.22\n" })
	H.git(root, { "commit", "-q", "-am", "other module" })
	H.git(root, { "checkout", "-q", "main" })
	H.write_files(root, { ["go.mod"] = "module example.com/main\n\ngo 1.22\n" })
	H.git(root, { "commit", "-q", "-am", "main module" })
	local merge = vim.system({ "git", "-C", root, "merge", "-q", "other" }, { text = true }):wait()
	assert(merge.code ~= 0, "fixture merge should conflict")
	H.git(root, { "mv", "README.md", "READ.md" })
	open_tree()

	expect_tree_highlight("READ.md", "FileTreeGitRenamed")
	expect_tree_highlight("go.mod", "FileTreeGitConflict")
	H.expect_no_neo_tree(child)
end

T["file-tree: Project tree reads git status without optional locks"] = function()
	open_tree()
	local command = child.lua_get([[(function()
		vim.wait(3000, function()
			return require("gleb.file_tree.git").state.last_cmd ~= nil
		end, 20)
		return require("gleb.file_tree.git").state.last_cmd
	end)()]])

	eq(command, {
		"git",
		"--no-optional-locks",
		"-C",
		assert(vim.uv.fs_realpath(root)),
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=normal",
		"--ignored=matching",
	})
end

T["file-tree: Project tree outside a repository has no git colours"] = function()
	local outside = vim.fn.tempname()
	H.write_files(outside, { ["a.txt"] = "plain\n" })
	local notifications = H.record_notify(child)
	child.cmd("cd " .. vim.fn.fnameescape(outside))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(outside, "a.txt")))
	run_toggle()

	expect_tree_highlight("a.txt", "FileTreeFileName")
	eq(notifications(), {})
end

T["file-tree: Project tree runs git status once per burst"] = function()
	open_tree()
	local baseline = child.lua_get([[(function()
		local git = require("gleb.file_tree.git")
		assert(vim.wait(3000, function()
			return type(git.state.runs) == "number" and git.state.runs > 0
		end, 20), "initial git status did not finish")
		return git.state.runs
	end)()]])

	child.lua(
		[[(function(root)
			local script = table.concat({
				"i=1",
				'while [ "$i" -le 20 ]; do',
				"printf 'burst\\n' > \"burst-$i.txt\"",
				"i=$((i + 1))",
				"done",
			}, "\n")
			local result = vim.system({ "sh", "-c", script }, { cwd = root, text = true }):wait()
			assert(result.code == 0, result.stderr)
			for index = 1, 20 do
				local path = vim.fs.joinpath(root, ("burst-%d.txt"):format(index))
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_name(buf, path)
				vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf })
			end
		end)(...)]],
		{ root }
	)

	local result = child.lua_get(
		[[(function(baseline, timeout)
		local git = require("gleb.file_tree.git")
		local watch = require("gleb.tree.watch")
		local snapshot = {}
		local complete = vim.wait(timeout, function()
			local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
			if not view then
				snapshot = { view = false }
				return false
			end
			local found = 0
			for _, row in ipairs(view.rows) do
				if row.label:match("^burst%-%d+%.txt$") then
					found = found + 1
				end
			end
			local git_state = git.state.roots[view.root]
			local watch_state = watch.state.roots[view.root]
			local active_watch_timers = 0
			for _, timer in pairs(watch_state and watch_state.timers or {}) do
				if timer:is_active() then
					active_watch_timers = active_watch_timers + 1
				end
			end
			snapshot = {
				rows = found,
				git_timer = git_state and git_state.timer ~= nil or false,
				git_in_flight = git_state and git_state.in_flight or false,
				git_dirty = git_state and git_state.dirty or false,
				view_dirty = view.dirty,
				view_dirty_timer = view.dirty_timer ~= nil,
				view_git_pending = view.git_pending,
				active_watch_timers = active_watch_timers,
				watch_sync_scheduled = watch_state and watch_state.sync_scheduled or false,
				watch_fallback_scanning = watch_state and watch_state.fallback_scanning or false,
			}
			return found == 20
				and git_state ~= nil
				and git_state.timer == nil
				and not git_state.in_flight
				and not git_state.dirty
				and not view.dirty
				and view.dirty_timer == nil
				and not view.git_pending
				and watch_state ~= nil
				and active_watch_timers == 0
				and not watch_state.sync_scheduled
				and not watch_state.fallback_scanning
		end, 20)
		snapshot.complete = complete
		snapshot.runs = git.state.runs - baseline
		return snapshot
	end)(...)]],
		{ baseline, math.ceil(3000 * H.load_factor()) }
	)

	assert(result.complete, "project-tree burst did not settle: " .. vim.inspect(result))
	eq(result.rows, 20)
	assert(result.runs <= 2, ("expected at most 2 git runs, got %d"):format(result.runs))
end

return T
