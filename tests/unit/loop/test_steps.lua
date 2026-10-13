local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPTS = vim.fs.joinpath(H.root, ".archon/scripts")
local PLAN_HEADER = "> REQUIRED SUB-SKILL: Use superpowers:x. Steps use checkbox (`- [ ]`) syntax for tracking."

---@param root string
---@param files table<string, string>
local function write(root, files)
	for path, content in pairs(files) do
		local target = vim.fs.joinpath(root, path)
		vim.fn.mkdir(vim.fs.dirname(target), "p")
		vim.fn.writefile(vim.split(content, "\n", { plain = true }), target)
	end
end

---@param args string[]
---@param cwd string
local function git_ok(args, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, args), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

--- Repo on `auto` with one commit, then on branch `run` with `files` written (uncommitted).
---@param files table<string, string>
---@return string
local function branch_repo(files)
	local repo = H.tempdir(child)
	write(repo, { ["README.md"] = "x", ["tests/unit/a/test_a.lua"] = 'T["a: one"] = function() end' })
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "initial" }, repo)
	git_ok({ "checkout", "-q", "-b", "run" }, repo)
	write(repo, files)
	return repo
end

---@param script string
---@param cwd string
---@param env? table<string, string>
---@return test.SystemResult
local function run(script, cwd, env)
	local full =
		vim.tbl_extend("force", H.GIT_ENV, { ARTIFACTS_DIR = H.tempdir(child), BASE_BRANCH = "auto" }, env or {})
	return H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, script) }, cwd, full)
end

T["loop: Plan header prose is not an unchecked task"] = function()
	local repo = H.tempdir(child)
	write(repo, { ["openspec/changes/c/tasks.md"] = PLAN_HEADER .. "\n\n## 1. Task\n- [x] 1.1 done" })
	eq(run("tasks.py", repo, { INPUTS_CHANGE = "c" }).code, 0)
end

T["loop: Task loop continues while a task is unchecked"] = function()
	local repo = H.tempdir(child)
	write(repo, { ["openspec/changes/c/tasks.md"] = "## 1. Task\n- [x] 1.1 done\n- [ ] 1.2 todo" })
	eq(run("tasks.py", repo, { INPUTS_CHANGE = "c" }).code, 1)
end

T["loop: Context pack names the next task"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n- lesson one\n\n## The loop\n",
		["openspec/changes/c/proposal.md"] = "## Why\nbecause",
		["openspec/changes/c/tasks.md"] = "## 1. First\n- [x] 1.1 a\n\n## 2. Second\n- [ ] 2.1 b",
	})
	local result = run("context_pack.py", repo, { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts })
	eq(result.code, 0, { fail_reason = result.stderr })
	local pack = table.concat(vim.fn.readfile(vim.fs.joinpath(artifacts, "context.md")), "\n")
	eq(pack:find("## Next task\n\n## 2. Second", 1, true) ~= nil, true)
	eq(pack:find("lesson one", 1, true) ~= nil, true)
end

T["loop: Judge rejects an xfail without a queued change"] = function()
	local repo =
		branch_repo({ ["tests/unit/a/test_b.lua"] = 'T["a: two"] = H.xfail("no-such-change", function() end)' })
	local result = run("escalation.py", repo)
	eq(result.code, 0, { fail_reason = result.stderr })
	eq(vim.json.decode(result.stdout).decision, "reject")
end

T["loop: Judge asks only for a breaking change"] = function()
	local repo = branch_repo({ ["lua/gleb/keymaps.lua"] = 'vim.keymap.set("n", "x", "y")' })
	local result = run("escalation.py", repo)
	eq(result.code, 0, { fail_reason = result.stderr })
	eq(vim.json.decode(result.stdout).decision, "ask")
end

T["loop: Judge ships an internal change without asking"] = function()
	local repo = branch_repo({ ["lua/gleb/util.lua"] = "return {}" })
	local result = run("escalation.py", repo)
	eq(result.code, 0, { fail_reason = result.stderr })
	eq(vim.json.decode(result.stdout), { decision = "ship", escalate = false, reasons = "- none" })
end

T["loop: Verdict sends hard-rule violations back to fix"] = function()
	local repo = branch_repo({ ["tests/unit/a/test_a.lua"] = "-- emptied" })
	local result = run("verdict.py", repo, {
		INPUTS_GREEN = "true",
		INPUTS_SPEC_OK = "true",
		INPUTS_TASKS_DONE = "true",
		INPUTS_CRITICAL = "0",
		INPUTS_APPROVE = "true",
		INPUTS_ATTEMPT = "1",
	})
	local out = vim.json.decode(result.stdout)
	eq({ out.passed, out.done, out.failed_gates }, { false, false, "rules" })
	eq(out.feedback:find("test case(s) removed", 1, true) ~= nil, true)
end

T["loop: A rejected judge never ships"] = function()
	local result = run("decide.py", H.tempdir(child), { INPUTS_VERDICT = "reject", INPUTS_DECISION = "auto" })
	eq(vim.json.decode(result.stdout).go, false)
end

return T
