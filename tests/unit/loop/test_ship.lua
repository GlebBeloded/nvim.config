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
	return vim.tbl_extend("force", H.GIT_ENV, { BASE_BRANCH = "auto", INPUTS_CHANGE = "" }, extra or {})
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

return T
