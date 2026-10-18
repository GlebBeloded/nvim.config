local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 10000

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

---@param dir string
local function open_changes(dir)
	child.cmd("cd " .. vim.fn.fnameescape(dir))
	child.cmd("enew")
	child.lua([[require("gleb.git.changes").open({ root = ... })]], { dir })
	eq(
		child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]], ASYNC_MS),
		true
	)
end

---@param path string
local function select_path(path)
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
end

---@param answer "y"|"n"
local function revert_with_answer(answer)
	child.lua([[
		InputAnswer = nil
		local input = vim.ui.input
		vim.ui.input = function(opts, callback)
			input(opts, function(value)
				InputAnswer = value
				callback(value)
			end)
		end
	]])
	child.type_keys("X")
	eq(child.wait([[vim.fn.mode() == "c"]], ASYNC_MS), true)
	child.type_keys(answer, "<CR>")
	eq(child.wait(("InputAnswer == %q"):format(answer), ASYNC_MS), true)
end

local function record_system_calls()
	child.lua([[
		SystemCalls = {}
		local original_system = vim.system
		vim.system = function(command, opts, callback)
			table.insert(SystemCalls, vim.deepcopy(command))
			return original_system(command, opts, callback)
		end
	]])
end

--- Give `dir` a bare `origin` remote that tracks its current branch.
---@param dir string
local function add_upstream(dir)
	local remote = vim.fn.tempname()
	vim.system({ "git", "init", "-q", "--bare", remote }):wait()
	H.git(dir, { "remote", "add", "origin", remote })
	H.git(dir, { "push", "-q", "-u", "origin", "HEAD" })
end

--- Dir with an executable `ollama` stub.
---@param input_path? string
---@return string dir
local function fake_ollama(input_path)
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local script = vim.fs.joinpath(dir, "ollama")
	local input = input_path and ("cat >" .. vim.fn.shellescape(input_path)) or "cat >/dev/null"
	vim.fn.writefile({ "#!/bin/sh", input, "printf 'generated\\n'" }, script)
	vim.fn.setfperm(script, "rwxr-xr-x")
	return dir
end

---@return boolean
local function wait_for_commit_popup()
	return child.wait(
		[[vim.iter(vim.api.nvim_list_wins())
			:filter(function(win) return win ~= vim.api.nvim_get_current_win() and vim.api.nvim_win_get_config(win).relative ~= "" end)
			:map(function(win) return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, 1, false)[1] end)
			:any(function(line) return line:find(" Commit Message ", 1, true) ~= nil end)]],
		ASYNC_MS * H.load_factor()
	)
end

--- Stage a change, open the real AI popup, and confirm `message`.
---@param dir string
---@param message string
local function commit_from_changes(dir, message)
	H.git(dir, { "config", "user.name", "t" })
	H.git(dir, { "config", "user.email", "t@t" })
	H.git(dir, { "add", "a.txt" })
	open_changes(dir)
	H.record_notify(child)
	child.lua([[vim.env.PATH = ... .. ":" .. vim.env.PATH]], { fake_ollama() })
	child.cmd("cd " .. vim.fn.fnameescape(vim.fs.dirname(dir)))
	child.type_keys("gc")
	eq(wait_for_commit_popup(), true)
	local win = child.api.nvim_get_current_win()
	child.api.nvim_buf_set_lines(child.api.nvim_win_get_buf(win), 0, -1, false, { message })
	child.type_keys("<CR>")
end

---@param dir string
---@return string
local function last_subject(dir)
	return vim.trim(H.git(dir, { "log", "-1", "--format=%s" }))
end

---@param prefix string
---@return boolean
local function wait_notification(prefix)
	return child.wait(
		string.format("vim.iter(Notifications):any(function(n) return vim.startswith(n.msg, %q) end)", prefix),
		ASYNC_MS
	)
end

---@param prefix string
---@return table[]
local function notifications_with(prefix)
	return child.lua_get(
		string.format(
			"vim.iter(Notifications):filter(function(n) return vim.startswith(n.msg, %q) end):totable()",
			prefix
		)
	)
end

--- Open Changes on `dir`, press the real push mapping, and wait for its result.
---@param dir string
---@param result_prefix string
local function push_from_changes(dir, result_prefix)
	open_changes(dir)
	H.record_notify(child)
	child.cmd("cd " .. vim.fn.fnameescape(vim.fs.dirname(dir)))
	child.type_keys("P")
	eq(wait_notification(result_prefix), true)
end

---@return table[]
local function revert_calls()
	return child.lua_get([[vim.iter(SystemCalls):filter(function(command)
		return command[1] == "git"
			and command[2] == "--literal-pathspecs"
			and (command[3] == "checkout" or command[3] == "rm")
	end):totable()]])
end

T["git: Changes panel X reverts a file after confirmation"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	local head = vim.split(H.git(dir, { "show", "HEAD:b.txt" }), "\n", { trimempty = true })
	open_changes(dir)
	select_path("b.txt")

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return H.git(dir, { "--no-optional-locks", "status", "--porcelain", "--", "b.txt" }) == ""
		end, 50),
		true
	)
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "b.txt")), head)
end

T["git: Changes panel X keeps a file when revert is declined"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	local path = vim.fs.joinpath(dir, "b.txt")
	local before = vim.fn.readfile(path)
	open_changes(dir)
	select_path("b.txt")

	revert_with_answer("n")

	eq(vim.fn.readfile(path), before)
	eq(H.git(dir, { "status", "--porcelain", "--", "b.txt" }) ~= "", true)
end

T["git: Changes panel X unstages a new file and keeps it"] = function()
	local dir = F.copy("billing", vim.fn.tempname() .. "/billing")
	local path = vim.fs.joinpath(dir, "internal/billing/tax.go")
	open_changes(dir)
	select_path("internal/billing/tax.go")

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return vim.trim(
				H.git(dir, { "ls-files", "--others", "--exclude-standard", "--", "internal/billing/tax.go" })
			) == "internal/billing/tax.go"
		end, 50),
		true
	)
	eq(vim.fn.filereadable(path), 1)
	eq(#vim.fn.readfile(path), 41)
end

T["git: Changes panel X ignores an unversioned file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	local path = vim.fs.joinpath(dir, "new.txt")
	open_changes(dir)
	select_path("new.txt")
	record_system_calls()

	child.type_keys("X")

	eq(vim.fn.filereadable(path), 1)
	eq(revert_calls(), {})
	eq(child.lua_get([[vim.fn.mode() ~= "c"]]), true)
end

T["git: Changes panel X reverts a rename"] = function()
	local dir = H.git_repo({ ["old.txt"] = "content\n" })
	H.git(dir, { "mv", "old.txt", "new.txt" })
	open_changes(dir)
	select_path("new.txt")
	record_system_calls()

	revert_with_answer("y")

	local expected_status = "?? new.txt\n"
	-- A plain status holds index.lock while it runs, which fails the child's concurrent checkout.
	local status = { "--no-optional-locks", "status", "--porcelain", "--", "old.txt", "new.txt" }
	local reverted = vim.wait(ASYNC_MS, function()
		return H.git(dir, status) == expected_status
	end, 50)
	if not reverted then
		eq(H.git(dir, status), expected_status)
	end
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "old.txt")), { "content" })
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "new.txt")), { "content" })
	eq(revert_calls(), {
		{ "git", "--literal-pathspecs", "checkout", "HEAD", "--", vim.fs.joinpath(dir, "old.txt") },
		{ "git", "--literal-pathspecs", "rm", "--cached", "--", vim.fs.joinpath(dir, "new.txt") },
	})
end

T["git: Changes panel X on unborn HEAD keeps the file"] = function()
	local dir = vim.fs.normalize(vim.fn.tempname())
	vim.fn.mkdir(dir, "p")
	H.git(dir, { "init", "-q", "-b", "main" })
	H.write_files(dir, { ["a.txt"] = "content\n" })
	H.git(dir, { "add", "a.txt" })
	local path = vim.fs.joinpath(vim.fn.resolve(dir), "a.txt")
	open_changes(dir)
	select_path("a.txt")
	record_system_calls()

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return vim.trim(H.git(dir, { "ls-files", "--others", "--exclude-standard", "--", "a.txt" })) == "a.txt"
		end, 50),
		true
	)
	eq(vim.fn.readfile(path), { "content" })
	eq(revert_calls(), {
		{ "git", "--literal-pathspecs", "rm", "--cached", "--", path },
	})
end

T["git: Changes panel gc commits confirmed message"] = function()
	local dir = H.git_repo({ ["a.txt"] = "one\n" })
	vim.fn.writefile({ "two" }, vim.fs.joinpath(dir, "a.txt"))
	commit_from_changes(dir, "feat: x")

	eq(wait_notification("Committed:"), true)
	eq(notifications_with("Committed:"), { { msg = "Committed: feat: x", level = vim.log.levels.INFO } })
	eq(last_subject(dir), "feat: x")

	vim.fn.writefile({ "three" }, vim.fs.joinpath(dir, "a.txt"))
	H.git(dir, { "add", "a.txt" })
	child.lua([[Notifications = {}]])
	child.type_keys("gc")
	eq(wait_for_commit_popup(), true)
	local win = child.api.nvim_get_current_win()
	child.api.nvim_buf_set_lines(child.api.nvim_win_get_buf(win), 0, -1, false, { "fix: it's $HOME" })
	child.type_keys("<CR>")
	eq(wait_notification("Committed:"), true)
	eq(last_subject(dir), "fix: it's $HOME")
end

T["git: Changes panel gc reports commit failure"] = function()
	local dir = H.git_repo({ ["a.txt"] = "one\n" })
	vim.fn.writefile({ "two" }, vim.fs.joinpath(dir, "a.txt"))
	local hook = vim.fs.joinpath(dir, ".git/hooks/pre-commit")
	vim.fn.writefile({ "#!/bin/sh", 'echo "hook says no" >&2', "exit 1" }, hook)
	vim.fn.setfperm(hook, "rwxr-xr-x")
	commit_from_changes(dir, "feat: x")

	eq(wait_notification("Commit failed:"), true)
	eq(notifications_with("Commit failed:"), { { msg = "Commit failed: hook says no", level = vim.log.levels.ERROR } })
	eq(notifications_with("Committed:"), {})
	eq(last_subject(dir), "initial")
end

T["git: Changes panel gc opens without mapping delay"] = function()
	local dir = H.git_repo({ ["a.txt"] = "one\n" })
	vim.fn.writefile({ "two" }, vim.fs.joinpath(dir, "a.txt"))
	H.git(dir, { "add", "a.txt" })
	open_changes(dir)
	child.lua([[vim.env.PATH = ... .. ":" .. vim.env.PATH]], { fake_ollama() })

	child.type_keys("gc")

	eq(
		child.wait(
			[[vim.iter(vim.api.nvim_list_wins()):any(function(win)
		return vim.api.nvim_win_get_config(win).relative ~= ""
	end)]],
			200
		),
		true
	)
end

T["git: Changes panel gc generates from the panel repository"] = function()
	local dir = H.git_repo({ ["a.txt"] = "one\n" })
	local input_path = vim.fn.tempname()
	vim.fn.writefile({ "two" }, vim.fs.joinpath(dir, "a.txt"))
	H.git(dir, { "add", "a.txt" })
	open_changes(dir)
	child.lua([[vim.env.PATH = ... .. ":" .. vim.env.PATH]], { fake_ollama(input_path) })
	child.cmd("cd " .. vim.fn.fnameescape(vim.fs.dirname(dir)))

	child.type_keys("gc")

	local prompt = ""
	eq(
		vim.wait(ASYNC_MS, function()
			if vim.fn.filereadable(input_path) == 0 then
				return false
			end
			prompt = table.concat(vim.fn.readfile(input_path), "\n")
			return prompt:find("-one", 1, true) ~= nil and prompt:find("+two", 1, true) ~= nil
		end, 20),
		true
	)
	eq(prompt:find("-one", 1, true) ~= nil, true)
	eq(prompt:find("+two", 1, true) ~= nil, true)
end

T["git: Changes panel P pushes successfully"] = function()
	local dir = H.git_repo({ ["a.txt"] = "one\n" })
	add_upstream(dir)
	vim.fn.writefile({ "two" }, vim.fs.joinpath(dir, "a.txt"))

	push_from_changes(dir, "Pushed successfully")

	eq(notifications_with("Push"), {
		{ msg = "Pushing...", level = vim.log.levels.INFO },
		{ msg = "Pushed successfully", level = vim.log.levels.INFO },
	})
end

T["git: Changes panel P reports push failure"] = function()
	local dir = H.git_repo({ ["a.txt"] = "one\n" })
	vim.fn.writefile({ "two" }, vim.fs.joinpath(dir, "a.txt"))

	push_from_changes(dir, "Push failed")

	eq(notifications_with("Push"), {
		{ msg = "Pushing...", level = vim.log.levels.INFO },
		{ msg = "Push failed", level = vim.log.levels.ERROR },
	})
end

return T
