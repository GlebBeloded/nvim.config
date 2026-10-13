local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SHIP = vim.fs.joinpath(H.root, ".archon/scripts/ship.py")

--- Files per branch in the concurrent case: enough that the merges overlap.
local CONCURRENT_FILES = 200

---@param cmd string[]
---@param cwd string
---@return test.SystemResult
local function git_ok(cmd, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, cmd), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = table.concat(cmd, " ") .. "\n" .. result.stderr })
	return result
end

---@param repo string
---@param ref string
---@return string
local function rev(repo, ref)
	return vim.trim(git_ok({ "rev-parse", ref }, repo).stdout)
end

--- Writes `files` (relative path -> content) under `dir`.
---@param dir string
---@param files table<string, string>
local function write_files(dir, files)
	child.lua(
		[[local dir, files = ...
		for path, content in pairs(files) do
			local full = vim.fs.joinpath(dir, path)
			vim.fn.mkdir(vim.fs.dirname(full), "p")
			vim.fn.writefile(vim.split(content, "\n"), full)
		end]],
		{ dir, files }
	)
end

---@param path string
---@param content string
local function write_executable(path, content)
	write_files(vim.fs.dirname(path), { [vim.fs.basename(path)] = content })
	child.lua("vim.uv.fs_chmod(..., 493)", { path })
end

--- Repo on branch `auto` with one commit holding `f.txt`.
---@return string
local function make_repo()
	local repo = H.tempdir(child)
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	write_files(repo, { ["f.txt"] = "base" })
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "init" }, repo)
	return repo
end

--- Worktree of `repo` on a new branch `loop/<name>` with one commit writing `files`.
---@param repo string
---@param name string
---@param files table<string, string>
---@return string worktree
local function add_run(repo, name, files)
	local worktree = vim.fs.joinpath(H.tempdir(child), name)
	git_ok({ "worktree", "add", "-q", "-b", "loop/" .. name, worktree, "auto" }, repo)
	write_files(worktree, files)
	git_ok({ "add", "-A" }, worktree)
	git_ok({ "commit", "-q", "-m", name }, worktree)
	return worktree
end

---@param name string
---@return table<string, string>
local function many_files(name)
	local files = {}
	for i = 1, CONCURRENT_FILES do
		files[("%s/%d.txt"):format(name, i)] = name .. i
	end
	return files
end

---@param extra? table<string, string>
---@return table<string, string>
local function ship_env(extra)
	-- no Archon DB: ship's detached cleanup waits for this child to exit, not for a real run
	local env = { BASE_BRANCH = "auto", INPUTS_CHANGE = "", ARCHON_DB = "/nonexistent/archon.db" }
	return vim.tbl_extend("force", H.GIT_ENV, env, extra or {})
end

--- Runs ship.py in `worktree`.
---@param worktree string
---@param env? table<string, string>
---@return test.SystemResult
local function ship(worktree, env)
	return H.system(child, { "python3", SHIP }, worktree, ship_env(env))
end

--- Starts ship.py in every worktree at once and waits for all of them.
---@param worktrees string[]
---@return test.SystemResult[]
local function ship_all(worktrees)
	return child.lua(
		[[local cmd, worktrees, env = ...
		local jobs = vim.tbl_map(function(dir)
			return vim.system(cmd, { cwd = dir, env = env, text = true })
		end, worktrees)
		return vim.tbl_map(function(job) return job:wait(120000) end, jobs)]],
		{ { "python3", SHIP }, worktrees, ship_env() }
	)
end

---@param repo string
---@param name string
---@return boolean
local function exists(repo, name)
	return child.lua_get("vim.uv.fs_stat(...) ~= nil", { vim.fs.joinpath(repo, name) })
end

--- Asserts the `auto` checkout is not mid-merge, has no tracked edits and no ship lock.
---@param repo string
local function expect_auto_clean(repo)
	eq(exists(repo, ".git/MERGE_HEAD"), false)
	eq(git_ok({ "status", "--porcelain", "--untracked-files=no" }, repo).stdout, "")
	eq(exists(repo, ".git/nvim-ship.lock"), false)
end

---@param result test.SystemResult
local function expect_shipped(result)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(vim.json.decode(result.stdout).merged, true)
end

T["loop: Concurrent ships merge one at a time"] = function()
	local repo = make_repo()
	local worktrees = vim.tbl_map(function(name)
		return add_run(repo, name, many_files(name))
	end, { "a", "b", "c", "d" })
	vim.iter(ship_all(worktrees)):each(expect_shipped)
	eq(vim.trim(git_ok({ "rev-list", "--first-parent", "--merges", "--count", "auto" }, repo).stdout), "4")
	expect_auto_clean(repo)
end

T["loop: Ship waits for a dirty auto checkout"] = function()
	local repo = make_repo()
	local run = add_run(repo, "w", { ["w.txt"] = "w" })
	write_files(repo, { ["f.txt"] = "edited" })
	child.lua(
		[[local cmd, cwd, env = ...
		_G.ship_err = ""
		local function collect(_, data)
			_G.ship_err = _G.ship_err .. (data or "")
		end
		_G.ship_run = vim.system(cmd, { cwd = cwd, env = env, text = true, stderr = collect })]],
		{ { "python3", SHIP }, run, ship_env() }
	)
	-- clean the checkout only once ship has seen it dirty, however late ship starts under load
	local saw_dirty = [[vim.wait(..., function()
		return _G.ship_err:find("uncommitted changes, waiting", 1, true) ~= nil
	end, 20)]]
	eq(child.lua_get(saw_dirty, { math.ceil(30000 * H.load_factor()) }), true, { fail_reason = "ship never waited" })
	git_ok({ "checkout", "--", "f.txt" }, repo)
	local result = child.lua_get("_G.ship_run:wait(30000)")
	result.stderr = child.lua_get("_G.ship_err")
	expect_shipped(result)
	eq(result.stderr:find("uncommitted changes, waiting", 1, true) ~= nil, true)
end

T["loop: Ship gives up on an auto checkout that stays dirty"] = function()
	local repo = make_repo()
	local run = add_run(repo, "d", { ["d.txt"] = "d" })
	write_files(repo, { ["f.txt"] = "edited" })
	local result = ship(run, { SHIP_DIRTY_WAIT = "1" })
	eq(result.code ~= 0, true)
	eq(result.stderr:find("merge loop/d by hand", 1, true) ~= nil, true)
end

T["loop: Stale ship lock is taken over"] = function()
	local repo = make_repo()
	local worktree = add_run(repo, "stale", { ["s.txt"] = "s" })
	local dead = child.lua_get("(function() local job = vim.system({ 'true' }); job:wait(); return job.pid end)()")
	write_files(repo, { [".git/nvim-ship.lock"] = tostring(dead) })
	expect_shipped(ship(worktree, { SHIP_LOCK_TIMEOUT = "10" }))
	git_ok({ "merge-base", "--is-ancestor", "loop/stale", "auto" }, repo)
	expect_auto_clean(repo)
end

--- `git` that fails `git merge --abort` and passes everything else to the real git.
---@return string bin directory holding the shim
local function failing_abort_git()
	local bin = H.tempdir(child)
	local shim = ([[#!/bin/sh
[ "$1 $2" = "merge --abort" ] && exit 1
exec %s "$@"]]):format(vim.fn.exepath("git"))
	write_executable(vim.fs.joinpath(bin, "git"), shim)
	return bin
end

---@param abort "works"|"fails"
---@return table<string, string>?
local function abort_env(abort)
	if abort == "fails" then
		return { PATH = failing_abort_git() .. ":" .. child.lua_get("vim.env.PATH") }
	end
end

T["failed merge"] = MiniTest.new_set({ parametrize = { { "works" }, { "fails" } } })

T["failed merge"]["loop: Failed merge leaves auto clean"] = function(abort)
	local repo = make_repo()
	local worktree = add_run(repo, "hook", { ["h.txt"] = "h" })
	write_executable(vim.fs.joinpath(repo, ".git/hooks/pre-merge-commit"), "#!/bin/sh\nexit 1")
	local before = rev(repo, "auto")
	local result = ship(worktree, abort_env(abort))
	eq(result.code ~= 0, true, { fail_reason = result.stdout })
	eq(rev(repo, "auto"), before)
	git_ok({ "rev-parse", "--verify", "loop/hook" }, repo)
	expect_auto_clean(repo)
end

T["loop: Conflicting ship is reported for reconcile"] = function()
	local repo = make_repo()
	local worktree = add_run(repo, "conflict", { ["f.txt"] = "branch" })
	write_files(repo, { ["f.txt"] = "auto" })
	git_ok({ "commit", "-q", "-am", "auto edit" }, repo)
	local before = rev(repo, "auto")
	local result = ship(worktree, { INPUTS_ON_CONFLICT = "report" })
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local report = vim.json.decode(result.stdout)
	eq({ report.merged, report.conflict }, { false, true })
	eq(vim.list_contains(report.files, "f.txt"), true)
	eq(rev(repo, "auto"), before)
	expect_auto_clean(repo)
end

--- Makefile whose `trace` fails on a case line in two files under tests/.
local GATE_MAKEFILE =
	"lint specs:\n\t@true\ntrace:\n\t@! cat tests/*.txt | sort | uniq -d | sed 's/^/duplicate case: /' | grep ."

T["loop: Ship does not merge a result that fails the static gates"] = function()
	local repo = make_repo()
	write_files(repo, { Makefile = GATE_MAKEFILE, ["tests/base.txt"] = "base" })
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "gates" }, repo)
	local dup = add_run(repo, "dup", { ["tests/b.txt"] = "dup" })
	local fresh = add_run(repo, "fresh", { ["tests/c.txt"] = "fresh" })
	write_files(repo, { ["tests/a.txt"] = "dup" })
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "auto adds dup" }, repo)
	local before = rev(repo, "auto")
	local result = ship(dup, { INPUTS_ON_CONFLICT = "report" })
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local report = vim.json.decode(result.stdout)
	eq({ report.merged, report.conflict, report.gate_failed }, { false, true, true })
	eq(report.log:find("duplicate case: dup", 1, true) ~= nil, true, { fail_reason = report.log })
	eq(rev(repo, "auto"), before)
	expect_auto_clean(repo)
	expect_shipped(ship(fresh, { INPUTS_ON_CONFLICT = "report" }))
end

--- Archon DB with a running run whose working path is `worktree`.
---@param worktree string
---@return string path
local function live_run_db(worktree)
	local db = vim.fs.joinpath(H.tempdir(child), "archon.db")
	local sql = (
		"create table remote_agent_workflow_runs (status text, working_path text);"
		.. "insert into remote_agent_workflow_runs values ('running', '%s');"
	):format(worktree)
	eq(H.system(child, { "sqlite3", db, sql }, worktree).code, 0)
	return db
end

--- Runs ship.py under a shell that outlives it only briefly (the cleanup's parent pid).
---@param worktree string
---@param env? table<string, string>
---@return test.SystemResult
local function ship_in_shell(worktree, env)
	return H.system(child, { "sh", "-c", 'python3 "$0"; status=$?; exit $status', SHIP }, worktree, ship_env(env))
end

T["loop: Ship cleans up its run after the run ends"] = function()
	local repo = make_repo()
	local done = add_run(repo, "done", { ["done.txt"] = "d" })
	expect_shipped(ship_in_shell(done))
	local timeout = math.ceil(20000 * H.load_factor())
	-- the cleanup removes the worktree first and the branch after it: wait for both
	local gone = child.lua_get(
		[[(function(dir, repo, timeout)
			local function branch_gone()
				local ref = { "git", "rev-parse", "--verify", "--quiet", "refs/heads/loop/done" }
				return vim.system(ref, { cwd = repo }):wait().code ~= 0
			end
			local dir_gone = vim.wait(timeout, function() return vim.uv.fs_stat(dir) == nil end, 100)
			return { dir_gone, vim.wait(timeout, branch_gone, 100) }
		end)(...)]],
		{ done, repo, timeout }
	)
	eq(gone, { true, true }, { fail_reason = "worktree or branch not removed" })

	local live = add_run(repo, "live", { ["live.txt"] = "l" })
	expect_shipped(ship_in_shell(live, { ARCHON_DB = live_run_db(live), LOOP_CLEAN_WAIT = "2" }))
	local log = vim.fs.joinpath(repo, ".git/nvim-loop-clean.log")
	local reported = child.lua_get(
		[[(function(log, timeout)
			return vim.wait(timeout, function()
				return vim.fn.filereadable(log) == 1 and table.concat(vim.fn.readfile(log), "\n"):find("loop/live  run still live") ~= nil
			end, 100)
		end)(...)]],
		{ log, timeout }
	)
	eq(reported, true, { fail_reason = "no still-live report" })
	eq(exists(live, "live.txt"), true)
	git_ok({ "rev-parse", "--verify", "loop/live" }, repo)
end

return T
