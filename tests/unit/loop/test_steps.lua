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

T["loop: Task loop reads the change the pack saved"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [ ] 1.1 todo",
	})
	eq(run("context_pack.py", repo, { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }).code, 0)
	eq(run("tasks.py", repo, { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "" }).code, 1)
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

T["loop: Judge ignores REMOVED Requirements mentioned in prose"] = function()
	local repo = branch_repo({
		["openspec/changes/c/specs/loop/spec.md"] = "#### Scenario: s\n- **WHEN** a `## REMOVED Requirements` section lists x",
	})
	local result = run("escalation.py", repo)
	eq(vim.json.decode(result.stdout).decision, "ship")
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

T["loop: Trace counts scenarios an active change adds"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/specs/x/spec.md"] = "#### Scenario: base",
		["openspec/changes/c/specs/x/spec.md"] = "## ADDED Requirements\n#### Scenario: added\n## REMOVED Requirements\n#### Scenario: gone",
		["openspec/changes/archive/old/specs/x/spec.md"] = "#### Scenario: archived",
		["tests/unit/x/test_x.lua"] = 'local T = MiniTest.new_set()\nT["x: base"] = function() end\nT["x: added"] = function() end\nreturn T',
	})
	local nvim = { vim.v.progpath, "--clean", "--headless", "-u", vim.fs.joinpath(H.root, "tests/minimal_init.lua") }
	local result = H.system(child, vim.list_extend(nvim, { "-l", vim.fs.joinpath(H.root, "tests/trace.lua") }), repo)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq((result.stdout .. result.stderr):find("2 scenarios, 2 tested, 0 missing, 0 orphan", 1, true) ~= nil, true)
end

T["loop: Plan is skipped when the spec wrote tasks"] = function()
	local repo = H.tempdir(child)
	write(repo, { ["openspec/changes/c/tasks.md"] = "## 1. Task\n- [ ] 1.1 todo" })
	local with_tasks = run("tasks.py", repo, { INPUTS_CHANGE = "c" })
	local args = { "python3", vim.fs.joinpath(SCRIPTS, "tasks.py"), "--plan-needed" }
	local env = vim.tbl_extend("force", H.GIT_ENV, { INPUTS_CHANGE = "c" })
	eq(vim.json.decode(H.system(child, args, repo, env).stdout), { needed = false })
	env.INPUTS_CHANGE = "none"
	eq(vim.json.decode(H.system(child, args, repo, env).stdout), { needed = true })
	eq(with_tasks.code, 1)
end

T["loop: Small change packs all remaining tasks"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["openspec/changes/c/tasks.md"] = "## 1. A\n- [x] 1.1 a\n\n## 2. B\n- [ ] 2.1 b\n\n## 3. C\n- [ ] 3.1 c",
	})
	eq(run("context_pack.py", repo, { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }).code, 0)
	local pack = table.concat(vim.fn.readfile(vim.fs.joinpath(artifacts, "context.md")), "\n")
	eq({ pack:find("## 2. B", 1, true) ~= nil, pack:find("## 3. C", 1, true) ~= nil }, { true, true })
end

T["loop: Gate names a change scenario without a test"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/changes/c/specs/x/spec.md"] = "## ADDED Requirements\n#### Scenario: tested one\n#### Scenario: lonely\n## REMOVED Requirements\n#### Scenario: gone",
		["tests/unit/x/test_x.lua"] = 'T["x: tested one"] = function() end',
	})
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "scenarios.py"), "c" }, repo, H.GIT_ENV)
	eq({ result.code, vim.trim(result.stdout) }, { 1, "x: lonely" })
end

return T
