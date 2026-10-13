local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

---@param cmd string[]
---@param cwd string
---@return test.SystemResult
local function git_ok(cmd, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, cmd), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = table.concat(cmd, " ") .. "\n" .. result.stderr })
	return result
end

---@param path string
---@return boolean
local function exists(path)
	return child.lua_get("vim.uv.fs_stat(...) ~= nil", { path })
end

---@param repo string
---@param branch string
---@return boolean
local function has_branch(repo, branch)
	return H.system(child, { "git", "rev-parse", "--verify", "--quiet", "refs/heads/" .. branch }, repo).code == 0
end

--- Branch `loop/<name>` with one commit, in its own worktree (returned) when `worktree`.
---@param repo string
---@param name string
---@param worktree boolean
---@return string? worktree
local function add_branch(repo, name, worktree)
	local branch = "loop/" .. name
	if not worktree then
		git_ok({ "branch", branch }, repo)
		local dir = H.tempdir(child)
		git_ok({ "worktree", "add", "-q", dir, branch }, repo)
		git_ok({ "commit", "-q", "--allow-empty", "-m", name }, dir)
		git_ok({ "worktree", "remove", dir }, repo)
		return nil
	end
	local dir = vim.fs.joinpath(H.tempdir(child), name)
	git_ok({ "worktree", "add", "-q", "-b", branch, dir, "auto" }, repo)
	git_ok({ "commit", "-q", "--allow-empty", "-m", name }, dir)
	return dir
end

---@class test.CleanRepo
---@field repo string
---@field trees table<string, string> worktree by change name
---@field db string Archon DB with a running run in the t-e worktree

--- Shipped t-a (worktree), superseded t-b (fast-forwarded into auto), unmerged t-c, shipped t-d with
--- an uncommitted edit, shipped t-e held by a running Archon run.
---@return test.CleanRepo
local function make_repo()
	local repo = H.tempdir(child)
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "commit", "-q", "--allow-empty", "-m", "init" }, repo)
	child.lua("vim.uv.fs_symlink(...)", { vim.fs.joinpath(H.root, "Makefile"), vim.fs.joinpath(repo, "Makefile") })
	child.fn.mkdir(vim.fs.joinpath(repo, ".archon/scripts"), "p")
	child.lua("vim.uv.fs_copyfile(...)", {
		vim.fs.joinpath(H.root, ".archon/scripts/loop_clean.py"),
		vim.fs.joinpath(repo, ".archon/scripts/loop_clean.py"),
	})
	child.fn.writefile({ ".archon/", "Makefile" }, vim.fs.joinpath(repo, ".git/info/exclude"))
	add_branch(repo, "t-b", false)
	git_ok({ "merge", "-q", "--ff-only", "loop/t-b" }, repo)
	local trees = {}
	for _, name in ipairs({ "t-a", "t-d", "t-e" }) do
		trees[name] = add_branch(repo, name, true) --[[@as string]]
		git_ok({ "merge", "-q", "--no-ff", "-m", "ship " .. name, "loop/" .. name }, repo)
	end
	add_branch(repo, "t-c", false)
	child.fn.writefile({ "edit" }, vim.fs.joinpath(trees["t-d"], "wip.txt"))
	local db = vim.fs.joinpath(H.tempdir(child), "archon.db")
	local sql = (
		"create table remote_agent_workflow_runs (status text, working_path text);"
		.. "insert into remote_agent_workflow_runs values ('running', '%s');"
	):format(trees["t-e"])
	eq(H.system(child, { "sqlite3", db, sql }, repo).code, 0)
	return { repo = repo, trees = trees, db = db }
end

---@param fixture test.CleanRepo
---@param cmd string[]
---@return string output
local function run(fixture, cmd)
	local env = vim.tbl_extend("force", H.GIT_ENV, { ARCHON_DB = fixture.db, APPLY = "", MAKEFLAGS = "" })
	local result = H.system(child, cmd, fixture.repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return result.stdout .. result.stderr
end

---@param out string
---@param needles string[]
local function expect_lines(out, needles)
	for _, needle in ipairs(needles) do
		eq({ needle, out:find(needle, 1, true) ~= nil }, { needle, true }, { fail_reason = out })
	end
end

T["loop: Loop clean dry run lists and removes nothing"] = function()
	local fixture = make_repo()
	local out = run(fixture, { "make", "loop-clean" })
	expect_lines(out, {
		"remove  loop/t-a  shipped",
		"remove  loop/t-b  superseded",
		"keep    loop/t-c  unmerged: 1 commit(s) not on auto",
		"keep    loop/t-d  uncommitted changes in " .. fixture.trees["t-d"],
		"keep    loop/t-e  live run (running)",
		"2 would remove (dry run",
	})
	for _, name in ipairs({ "t-a", "t-b", "t-c", "t-d", "t-e" }) do
		eq({ name, has_branch(fixture.repo, "loop/" .. name) }, { name, true })
	end
	eq(exists(fixture.trees["t-a"]), true)
end

T["loop: Loop clean apply removes only done runs"] = function()
	local fixture = make_repo()
	local out = run(fixture, { "make", "loop-clean", "APPLY=1" })
	expect_lines(out, { "removed loop/t-a  shipped", "removed loop/t-b  superseded" })
	eq({ has_branch(fixture.repo, "loop/t-a"), exists(fixture.trees["t-a"]) }, { false, false })
	eq(has_branch(fixture.repo, "loop/t-b"), false)
	for _, name in ipairs({ "t-c", "t-d", "t-e" }) do
		eq({ name, has_branch(fixture.repo, "loop/" .. name) }, { name, true })
	end
	eq(exists(vim.fs.joinpath(fixture.trees["t-d"], "wip.txt")), true)
	eq(exists(fixture.trees["t-e"]), true)
	out = run(fixture, { "python3", ".archon/scripts/loop_clean.py", "--branch", "auto", "--apply" })
	expect_lines(out, { "keep    auto  never cleaned" })
	eq(has_branch(fixture.repo, "auto"), true)
end

return T
