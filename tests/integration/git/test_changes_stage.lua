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

---@param dir string
local function open_changes(dir)
	child.cmd("cd " .. vim.fn.fnameescape(dir))
	child.cmd("enew")
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		assert(catalog:get("changes.toggle"), "changes.toggle is not registered").run()
	]])
	eq(
		child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]], ASYNC_MS),
		true
	)
end

---@param root string
---@param cwd string
local function open_changes_at(root, cwd)
	child.cmd("cd " .. vim.fn.fnameescape(cwd))
	child.cmd("enew")
	child.lua(([[require("gleb.git.changes").open({ root = %q })]]):format(root))
	eq(
		child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]], ASYNC_MS),
		true
	)
end

---@param path string
local function press_space_on(path)
	eq(
		child.wait(
			([[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not view then return false end
				for index, row in ipairs(view.rows) do
					if row.path == %q then
						vim.api.nvim_win_set_cursor(view.win, { index, 0 })
						return true
					end
				end
				return false
			end)()]]):format(path),
			ASYNC_MS
		),
		true
	)
	child.type_keys(" ")
end

---@param root_name string
local function press_space_on_root(root_name)
	eq(
		child.wait(
			([[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not view then return false end
				for index, row in ipairs(view.rows) do
					if row.kind == "root" and row.root == %q then
						vim.api.nvim_win_set_cursor(view.win, { index, 0 })
						return true
					end
				end
				return false
			end)()]]):format(root_name),
			ASYNC_MS
		),
		true
	)
	child.type_keys(" ")
end

local function record_system_calls()
	child.lua([[
		SystemCalls = {}
		local original_system = vim.system
		vim.system = function(command, opts, callback)
			table.insert(SystemCalls, { command = vim.deepcopy(command), stdin = opts and opts.stdin or nil })
			return original_system(command, opts, callback)
		end
	]])
end

---@param operation string
---@return table[]
local function action_calls(operation)
	return child.lua_get(([[vim.iter(SystemCalls):filter(function(call)
		return call.command[1] == "git"
			and call.command[2] == "--literal-pathspecs"
			and call.command[3] == %q
	end):totable()]]):format(operation))
end

---@param dir string
---@return string[]
local function staged(dir)
	return vim.split(vim.trim(H.git(dir, { "diff", "--cached", "--name-only" })), "\n", { trimempty = true })
end

---@param dir string
---@param path string
---@param wanted boolean
---@return boolean
local function wait_staged(dir, path, wanted)
	return vim.wait(ASYNC_MS, function()
		return vim.list_contains(staged(dir), path) == wanted
	end, 50)
end

---@param dir string
---@param path string
---@return boolean
local function wait_worktree_clean(dir, path)
	return vim.wait(ASYNC_MS, function()
		return vim.system({ "git", "diff", "--quiet", "--", path }, { cwd = dir }):wait().code == 0
	end, 50)
end

---@param path string
---@param checkbox string
---@return boolean
local function wait_checkbox(path, checkbox)
	return child.wait(
		([[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			if not view then return false end
			for _, row in ipairs(view.rows) do
				if row.path == %q then return row.checkbox == %q end
			end
			return false
		end)()]]):format(path, checkbox),
		ASYNC_MS
	)
end

---@param root_name string
---@param checkbox string
---@return boolean
local function wait_root_checkbox(root_name, checkbox)
	return child.wait(
		([[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			if not view then return false end
			for _, row in ipairs(view.rows) do
				if row.kind == "root" and row.root == %q then return row.checkbox == %q end
			end
			return false
		end)()]]):format(root_name, checkbox),
		ASYNC_MS
	)
end

T["git: Changes panel Space stages an unstaged file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("b.txt")

	eq(wait_staged(dir, "b.txt", true), true)
	eq(wait_checkbox("b.txt", "󰄲"), true)
end

T["git: Changes panel Space unstages a staged file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("a.txt")

	eq(wait_staged(dir, "a.txt", false), true)
	eq(wait_checkbox("a.txt", "󰄱"), true)
end

T["git: Changes panel Space stages a partially staged file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("d.txt")

	eq(wait_staged(dir, "d.txt", true), true)
	eq(wait_worktree_clean(dir, "d.txt"), true)
	eq(wait_checkbox("d.txt", "󰄲"), true)
end

T["git: Changes panel Space stages an untracked file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("new.txt")

	eq(wait_staged(dir, "new.txt", true), true)
	eq(wait_checkbox("new.txt", "󰄲"), true)
	eq(
		child.wait(
			[[
			vim.iter(require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].rows)
				:all(function(row) return row.root ~= "unversioned" end)
		]],
			ASYNC_MS
		),
		true
	)
end

T["git: Changes panel Space stages a file whose name is a suffix of a staged file"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n", ["aa.lua"] = "one\n" })
	H.write_files(dir, { ["a.lua"] = "two\n", ["aa.lua"] = "two\n" })
	H.git(dir, { "add", "--", "aa.lua" })
	open_changes(dir)

	press_space_on("a.lua")

	eq(wait_staged(dir, "a.lua", true), true)
	eq(staged(dir), { "a.lua", "aa.lua" })
end

T["git: Changes panel stages when cwd is outside the repository"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n" })
	local outside = vim.fn.tempname()
	vim.fn.mkdir(outside, "p")
	H.write_files(dir, { ["a.lua"] = "two\n" })
	open_changes_at(dir, outside)

	press_space_on("a.lua")

	eq(wait_staged(dir, "a.lua", true), true)
end

T["git: Changes panel unstages when cwd is outside the repository"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n" })
	local outside = vim.fn.tempname()
	vim.fn.mkdir(outside, "p")
	H.write_files(dir, { ["a.lua"] = "two\n" })
	H.git(dir, { "add", "--", "a.lua" })
	open_changes_at(dir, outside)

	press_space_on("a.lua")

	eq(wait_staged(dir, "a.lua", false), true)
end

T["git: Changes panel stages from a subdirectory cwd"] = function()
	local dir = H.git_repo({ ["sub/x.lua"] = "one\n" })
	H.write_files(dir, { ["sub/x.lua"] = "two\n" })
	open_changes(vim.fs.joinpath(dir, "sub"))

	press_space_on("sub/x.lua")

	eq(wait_staged(dir, "sub/x.lua", true), true)
end

T["git: Changes panel unstages from a subdirectory cwd"] = function()
	local dir = H.git_repo({ ["sub/x.lua"] = "one\n" })
	H.write_files(dir, { ["sub/x.lua"] = "two\n" })
	H.git(dir, { "add", "--", "sub/x.lua" })
	open_changes(vim.fs.joinpath(dir, "sub"))

	press_space_on("sub/x.lua")

	eq(wait_staged(dir, "sub/x.lua", false), true)
end

T["git: Changes panel reports a staging failure"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n" })
	H.write_files(dir, { ["a.lua"] = "two\n" })
	open_changes(dir)
	local notifications = H.record_notify(child)
	vim.fn.writefile({}, vim.fs.joinpath(dir, ".git", "index.lock"))

	press_space_on("a.lua")

	eq(
		child.wait(
			[[vim.iter(Notifications):any(function(notification)
				return notification.level == vim.log.levels.ERROR
					and vim.startswith(notification.msg, "Stage failed:")
			end)]],
			ASYNC_MS
		),
		true
	)
	eq(vim.startswith(notifications()[1].msg, "Stage failed:"), true)
end

local stage_root = MiniTest.new_set()
T["git: Changes panel Space on the Changes root stages every tracked file"] = stage_root

stage_root["stages the dirty fixture in one add call"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)
	record_system_calls()

	press_space_on_root("changes")

	eq(
		vim.wait(ASYNC_MS, function()
			return vim.deep_equal(staged(dir), { "a.txt", "b.txt", "d.txt", "lib/c.lua" })
		end, 50),
		true
	)
	eq(staged(dir), { "a.txt", "b.txt", "d.txt", "lib/c.lua" })
	eq(wait_worktree_clean(dir, "."), true)
	eq(wait_root_checkbox("changes", "󰄲"), true)
	eq(action_calls("add"), {
		{
			command = {
				"git",
				"--literal-pathspecs",
				"add",
				"--",
				vim.fs.normalize(vim.fn.resolve(vim.fs.joinpath(dir, "a.txt"))),
				vim.fs.normalize(vim.fn.resolve(vim.fs.joinpath(dir, "b.txt"))),
				vim.fs.normalize(vim.fn.resolve(vim.fs.joinpath(dir, "d.txt"))),
				vim.fs.normalize(vim.fn.resolve(vim.fs.joinpath(dir, "lib/c.lua"))),
			},
		},
	})
end

stage_root["uses NUL pathspec input above 100 paths"] = function()
	local files = {}
	for index = 1, 101 do
		files[("file-%03d.txt"):format(index)] = "old\n"
	end
	local dir = H.git_repo(files)
	for path in pairs(files) do
		files[path] = "new\n"
	end
	H.write_files(dir, files)
	open_changes(dir)
	record_system_calls()

	press_space_on_root("changes")

	eq(wait_worktree_clean(dir, "."), true)
	local calls = action_calls("add")
	eq(#calls, 1)
	eq(calls[1].command, {
		"git",
		"--literal-pathspecs",
		"add",
		"--pathspec-from-file=-",
		"--pathspec-file-nul",
	})
	eq(select(2, calls[1].stdin:gsub("%z", "")), 101)
end

T["git: Changes panel stages literal metacharacter paths"] = function()
	local dir = H.git_repo({ ["[ab].txt"] = "old\n", ["a.txt"] = "same\n", ["b.txt"] = "same\n" })
	H.write_files(dir, { ["[ab].txt"] = "new\n" })
	open_changes(dir)
	record_system_calls()

	press_space_on("[ab].txt")

	eq(wait_staged(dir, "[ab].txt", true), true)
	eq(staged(dir), { "[ab].txt" })
	local calls = child.lua_get([[vim.iter(SystemCalls):filter(function(call)
		return call.command[1] == "git" and call.command[2] == "--literal-pathspecs"
	end):totable()]])
	eq(#calls >= 2, true)
end

T["git: Changes panel refuses to stage an unmerged file"] = function()
	local dir = H.git_repo({ ["conflict.txt"] = "base\n" })
	H.git(dir, { "checkout", "-q", "-b", "other" })
	H.write_files(dir, { ["conflict.txt"] = "other\n" })
	H.git(dir, { "commit", "-qam", "other" })
	H.git(dir, { "checkout", "-q", "main" })
	H.write_files(dir, { ["conflict.txt"] = "main\n" })
	H.git(dir, { "commit", "-qam", "main" })
	local merge = vim.system({ "git", "merge", "other" }, { cwd = dir, text = true }):wait()
	eq(merge.code ~= 0, true)
	open_changes(dir)
	H.record_notify(child)
	record_system_calls()

	press_space_on("conflict.txt")

	eq(
		child.wait(
			[[vim.iter(Notifications):any(function(notification)
				return notification.msg == "Stage failed: resolve conflicts in the merge tool"
					and notification.level == vim.log.levels.ERROR
			end)]],
			ASYNC_MS
		),
		true
	)
	eq(#action_calls("add"), 0)
	eq(#action_calls("reset"), 0)
end

T["git: Changes panel unstages a rename literally"] = function()
	local dir = H.git_repo({ ["old.txt"] = "content\n" })
	H.git(dir, { "mv", "old.txt", "new.txt" })
	open_changes(dir)
	record_system_calls()

	press_space_on("new.txt")

	eq(wait_staged(dir, "new.txt", false), true)
	eq(staged(dir), {})
	eq(action_calls("reset"), {
		{
			command = {
				"git",
				"--literal-pathspecs",
				"reset",
				"-q",
				"--",
				vim.fs.normalize(vim.fn.resolve(vim.fs.joinpath(dir, "new.txt"))),
				vim.fs.normalize(vim.fn.resolve(vim.fs.joinpath(dir, "old.txt"))),
			},
		},
	})
end

T["git: Changes panel A stages everything"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)
	record_system_calls()

	child.type_keys("A")

	eq(wait_worktree_clean(dir, "."), true)
	eq(vim.trim(H.git(dir, { "ls-files", "--others", "--exclude-standard" })), "")
	eq(
		child.wait(
			[[vim.iter(require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].rows)
				:all(function(row)
					return row.root ~= "unversioned" and (row.checkbox == nil or row.checkbox == "󰄲")
				end)]],
			ASYNC_MS
		),
		true
	)
	eq(action_calls("add"), {
		{ command = { "git", "--literal-pathspecs", "add", "-A" } },
	})
end

return T
