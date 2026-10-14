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
		-- split so integrity.py does not read this fixture string as an xfail of this file
		branch_repo({ ["tests/unit/a/test_b.lua"] = 'T["a: two"] = H.x' .. 'fail("no-such-change", function() end)' })
	local result = run("escalation.py", repo)
	eq(result.code, 0, { fail_reason = result.stderr })
	eq(vim.json.decode(result.stdout).decision, "reject")
end

T["loop: Judge resolves an xfail reason held in a local"] = function()
	local test = 'local WHY = "queued-x: reason"\nT["a: two"] = H.xfail(\n\tWHY,\n\tfunction() end\n)'
	local queued = { ["tests/unit/a/test_b.lua"] = test, ["openspec/changes/queued-x/proposal.md"] = "## Why\nx" }
	local ok = run("escalation.py", branch_repo(queued))
	eq(ok.code, 0, { fail_reason = ok.stderr })
	eq(vim.json.decode(ok.stdout).decision ~= "reject", true)
	local missing = run("escalation.py", branch_repo({ ["tests/unit/a/test_b.lua"] = test }))
	eq(vim.json.decode(missing.stdout).decision, "reject")
end

T["loop: Judge ships a breaking change with a note"] = function()
	local repo = branch_repo({ ["lua/gleb/keymaps.lua"] = 'vim.keymap.set("n", "x", "y")' })
	local result = run("escalation.py", repo)
	eq(result.code, 0, { fail_reason = result.stderr })
	local out = vim.json.decode(result.stdout)
	eq({ out.decision, out.escalate }, { "ship", false })
	eq(out.reasons:find("- note: breaking: changes core keymaps", 1, true) ~= nil, true, { fail_reason = out.reasons })
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
	eq(
		(result.stdout .. result.stderr):find("2 scenarios, 2 tested, 0 missing, 0 orphan, 0 duplicate", 1, true) ~= nil,
		true
	)
end

T["loop: Trace orphan message names the remedy"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/specs/x/spec.md"] = "#### Scenario: base",
		["tests/unit/x/test_x.lua"] = 'local T = MiniTest.new_set()\nT["x: base"] = function() end\nT["x: invented"] = function() end\nreturn T',
	})
	local nvim = { vim.v.progpath, "--clean", "--headless", "-u", vim.fs.joinpath(H.root, "tests/minimal_init.lua") }
	local result = H.system(child, vim.list_extend(nvim, { "-l", vim.fs.joinpath(H.root, "tests/trace.lua") }), repo)
	local output = result.stdout .. result.stderr
	eq(result.code, 1, { fail_reason = output })
	local remedy = "name it after a scenario, or add that scenario to openspec/changes/<change>/specs; never delete it"
	eq(
		{ output:find(remedy, 1, true) ~= nil, output:find("x: invented  (tests/unit/x/test_x.lua)", 1, true) ~= nil },
		{ true, true }
	)
end

T["loop: Context pack keeps only what the next task needs"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local preamble = "# Guide\n" .. string.rep("intro line\n", 8)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["docs/guide.md"] = preamble .. "\n## Module map\n\nmap body\n\n## Startup\n\nstartup body\n",
		["lua/big.lua"] = "return 'big body'",
		["tests/unit/x/test_x.lua"] = 'local H = "header"\nT["x: one"] = function()\n\tone_body()\nend\n\nT["x: two"] = function()\n\ttwo_body()\nend\n\nreturn T',
		["openspec/changes/c/proposal.md"] = "## Why\nw\n\n## Unblocked\nthe answer\n\n## Rejected run\n- blocked: tasks.md: ## Blocked\n- old attempt\n\n## Impact\n- i",
		["openspec/changes/c/design.md"] = "## Context\nsee `lua/big.lua`",
		["openspec/changes/c/specs/x/spec.md"] = "## ADDED Requirements\n### Requirement: R1\nr1 text\n#### Scenario: one\n### Requirement: R2\nr2 text\n#### Scenario: other",
		["openspec/changes/c/tasks.md"] = "## 1. A\nScenarios: `x: one`\n- [ ] 1.1 test in tests/unit/x/test_x.lua, update the `docs/guide.md` module map",
	})
	eq(run("context_pack.py", repo, { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }).code, 0)
	local pack = table.concat(vim.fn.readfile(vim.fs.joinpath(artifacts, "context.md")), "\n")
	local found = function(text)
		return pack:find(text, 1, true) ~= nil
	end
	eq({ found('local H = "header"'), found("one_body()"), found("two_body()") }, { true, true, false })
	eq({ found("map body"), found("startup body"), found("## Startup  (line ") }, { true, false, true })
	eq(found("more lines: docs/guide.md)"), true, { fail_reason = pack })
	eq({ found("- `lua/big.lua`"), found("big body") }, { true, false })
	eq({ found("r1 text"), found("r2 text"), found("- Requirement: R2") }, { true, false, true })
	eq({ found("## Unblocked\nthe answer"), found("## Rejected run"), found("## Impact") }, { true, false, true })
end

T["loop: Implement continues past a stuck task"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local tasks = { "## 1. A\n- [x] 1.1 a" }
	for i, name in ipairs({ "B", "C", "D", "E" }) do
		table.insert(tasks, ("## %d. %s\n- [ ] %d.1 %s"):format(i + 1, name, i + 1, name:lower()))
	end
	local stuck = "\n\n## Stuck\n- Probe: red\n- Attempt 2: still red"
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["openspec/changes/c/tasks.md"] = table.concat(tasks, "\n\n") .. stuck,
	})
	local env = { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }
	eq(run("tasks.py", repo, env).code, 1)
	eq(run("context_pack.py", repo, env).code, 0)
	local pack = table.concat(vim.fn.readfile(vim.fs.joinpath(artifacts, "context.md")), "\n")
	eq(pack:find("## Next task\n\n## 3. C\n- [ ] 3.1 c\n", 1, true) ~= nil, true, { fail_reason = pack })
	local rest = table.concat(tasks, "\n\n"):gsub("%[ %] ([345])", "[x] %1")
	write(repo, { ["openspec/changes/c/tasks.md"] = rest .. stuck })
	eq(run("tasks.py", repo, env).code, 0)
end

T["loop: Trace fails on a case name in two test files"] = function()
	local repo = H.tempdir(child)
	local case = 'local T = MiniTest.new_set()\nT["x: base"] = function() end\nreturn T'
	write(repo, {
		["openspec/specs/x/spec.md"] = "#### Scenario: base",
		["tests/unit/x/test_x.lua"] = case,
		["tests/integration/x/test_x.lua"] = case,
	})
	local nvim = { vim.v.progpath, "--clean", "--headless", "-u", vim.fs.joinpath(H.root, "tests/minimal_init.lua") }
	local result = H.system(child, vim.list_extend(nvim, { "-l", vim.fs.joinpath(H.root, "tests/trace.lua") }), repo)
	local output = result.stdout .. result.stderr
	eq(result.code, 1, { fail_reason = output })
	local listed = "x: base  (tests/integration/x/test_x.lua, tests/unit/x/test_x.lua)"
	eq({ output:find(listed, 1, true) ~= nil, output:find("0 orphan, 1 duplicate", 1, true) ~= nil }, { true, true })
end

T["loop: Plan is skipped when the spec wrote tasks"] = function()
	local repo = H.tempdir(child)
	write(repo, { ["openspec/changes/c/tasks.md"] = "## 1. Task\n- [ ] 1.1 todo" })
	local with_tasks = run("tasks.py", repo, { INPUTS_CHANGE = "c" })
	local args = { "python3", vim.fs.joinpath(SCRIPTS, "tasks.py"), "--plan-needed" }
	local env = vim.tbl_extend("force", H.GIT_ENV, { INPUTS_CHANGE = "c" })
	eq(vim.json.decode(H.system(child, args, repo, env).stdout), { needed = false, has_change = true })
	env.INPUTS_CHANGE = "none"
	eq(vim.json.decode(H.system(child, args, repo, env).stdout), { needed = false, has_change = false })
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

T["loop: Gate ignores unchanged scenarios a modified requirement repeats"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/specs/x/spec.md"] = "### Requirement: r\n#### Scenario: old\n- **THEN** same\n#### Scenario: edited\n- **THEN** before",
		["openspec/changes/c/specs/x/spec.md"] = "## MODIFIED Requirements\n### Requirement: r\n#### Scenario: old\n- **THEN** same\n#### Scenario: edited\n- **THEN** after",
	})
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "scenarios.py"), "c" }, repo, H.GIT_ENV)
	eq({ result.code, vim.trim(result.stdout) }, { 1, "x: edited" })
end

T["loop: A make check item does not hold the task loop"] = function()
	local repo = H.tempdir(child)
	write(
		repo,
		{ ["openspec/changes/c/tasks.md"] = "## 1. Task\n- [x] 1.1 code\n- [ ] 1.2 Run `make check`; expect green" }
	)
	eq(run("tasks.py", repo, { INPUTS_CHANGE = "c" }).code, 0)
end

T["loop: Context pack names installed plugin sources"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["lazy-lock.json"] = '{ "gitlinker.nvim": { "commit": "x" }, "other.nvim": { "commit": "y" } }',
		["openspec/changes/c/proposal.md"] = "gitlinker reads getpos",
		["openspec/changes/c/tasks.md"] = "## 1. A\n- [ ] 1.1 a",
	})
	local env = { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts, NVIM_TEST_DATA_DIR = "/data" }
	eq(run("context_pack.py", repo, env).code, 0)
	local pack = table.concat(vim.fn.readfile(vim.fs.joinpath(artifacts, "context.md")), "\n")
	eq(
		{ pack:find("gitlinker.nvim: /data/lazy/gitlinker.nvim", 1, true) ~= nil, pack:find("other.nvim", 1, true) },
		{ true, nil }
	)
end

T["loop: Gate checks scenarios named by tasks when the spec has no delta"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/changes/c/tasks.md"] = "## 1. Fix\n**Scenarios:** `x: lonely`\n- [ ] 1.1 run it",
		["tests/unit/x/test_x.lua"] = 'T["x: other"] = function() end',
	})
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "scenarios.py"), "c" }, repo, H.GIT_ENV)
	eq({ result.code, vim.trim(result.stdout) }, { 1, "x: lonely" })
end

T["loop: An abandoned run's branch does not take its change"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/changes/c/proposal.md"] = "## Why\nx\n\nKind: bug",
		["openspec/changes/c/.openspec.yaml"] = "schema: spec-driven",
	})
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "init" }, repo)
	git_ok({ "branch", "loop/c" }, repo)
	local env = vim.tbl_extend("force", H.GIT_ENV, { HOME = H.tempdir(child), INPUTS_CHANGE = "" })
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "queue_pick.py") }, repo, env)
	eq(vim.json.decode(vim.trim(result.stdout):match("[^\n]*$")).change, "c")
end

T["loop: Spec gate catches main specs a change would break"] = function()
	local repo = H.tempdir(child)
	local long = "The thing SHALL " .. string.rep("work very well ", 40) .. "."
	local scenario = "\n\n#### Scenario: s\n- **WHEN** a\n- **THEN** b\n"
	write(repo, {
		["openspec/specs/x/spec.md"] = "# x\n\n## Purpose\nA purpose that is long enough for the validator to accept.\n\n## Requirements\n\n### Requirement: R\nThe thing SHALL work."
			.. scenario,
		["openspec/changes/c/specs/x/spec.md"] = "## MODIFIED Requirements\n\n### Requirement: R\n" .. long .. scenario,
		["openspec/changes/c/proposal.md"] = "## Why\nBecause it matters a lot here.\n\n## What Changes\n- x\n",
		["openspec/changes/c/.openspec.yaml"] = "schema: spec-driven",
	})
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "spec_trial.py"), "c" }, repo, H.GIT_ENV)
	eq({ result.code, result.stdout:find("very long", 1, true) ~= nil }, { 1, true })
end

T["loop: Spec gate rejects a task naming an unknown scenario"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/specs/x/spec.md"] = "### Requirement: r\n#### Scenario: real\n- **THEN** ok",
		["openspec/changes/c/tasks.md"] = "## 1. A\nScenarios: `x: real`, `x: invented`\n- [ ] 1.1 a",
	})
	local result =
		H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "scenarios.py"), "--unknown", "c" }, repo, H.GIT_ENV)
	eq({ result.code, vim.trim(result.stdout):match("[^\n]*$") }, { 1, "- x: invented" })
end

T["loop: Judge ignores a plugin spec moved into dependencies"] = function()
	local repo = H.tempdir(child)
	write(repo, { ["lua/gleb/plugins/plugins.lua"] = '{ "a/dap" },\n{ "a/dap-ui" },' })
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "init" }, repo)
	git_ok({ "checkout", "-q", "-b", "run" }, repo)
	write(repo, { ["lua/gleb/plugins/plugins.lua"] = '{ "a/dap", dependencies = { "a/dap-ui" } },' })
	local result = run("escalation.py", repo)
	eq(vim.json.decode(result.stdout).decision, "ship")
end

---@param files table<string, string>
---@return table adopted-state JSON of change `c` in a repo holding `files`
local function adopted_state(files)
	local repo = H.tempdir(child)
	write(repo, files)
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "tasks.py"), "--adopted-state" }, repo, {
		INPUTS_CHANGE = "c",
		LOOP_CHANGES_DIR = "",
	})
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout)
end

T["loop: Agents never load the host to reproduce a flake"] = function()
	for _, name in ipairs({ "fix", "implement" }) do
		local prompt =
			table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/" .. name .. ".md")), "\n")
		eq(
			prompt:find("never load the host", 1, true) ~= nil or prompt:find("Never load the host", 1, true) ~= nil,
			true
		)
	end
	local fix = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/fix.md")), "\n")
	eq(fix:find("Run `make fmt`, then commit", 1, true) ~= nil, true)
end

T["loop: Harness slips are not implementation attempts"] = function()
	for _, name in ipairs({ "fix", "implement" }) do
		local prompt =
			table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/" .. name .. ".md")), "\n")
		eq(prompt:gsub("%s+", " "):find("rerunning is not an attempt", 1, true) ~= nil, true, { fail_reason = name })
	end
end

T["loop: Implement and fix self-check like the gate before handing back"] = function()
	local makefile = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, "Makefile")), "\n")
	local target = makefile:match("\nself%-check:\n(.-)\n\n")
	eq(target ~= nil, true, { fail_reason = "no self-check target" })
	local needles = { "integrity.py", 'pinned.py --check "$(CHANGE)"', "lint types", "spec_trial.py" }
	for _, needle in ipairs(vim.list_extend(needles, { 'openspec validate "$(CHANGE)" --strict' })) do
		eq(target:find(needle, 1, true) ~= nil, true, { fail_reason = needle })
	end
	eq(target:find("check E2E", 1, true), nil)
	for _, name in ipairs({ "fix", "implement" }) do
		local prompt =
			table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/" .. name .. ".md")), "\n")
		prompt = prompt:gsub("%s+", " ")
		eq(prompt:find("`make self-check CHANGE=$INPUTS.change`", 1, true) ~= nil, true, { fail_reason = name })
		eq(
			prompt:find("an ordinary bug", 1, true) ~= nil and prompt:find("is fixed, never stuck", 1, true) ~= nil,
			true
		)
		for _, needle in ipairs({
			"is fixed, never stuck while an attempt is left",
			"red only from base or loop tooling, not this change: commit anyway and append a `loop: …` line",
		}) do
			eq(prompt:find(needle, 1, true) ~= nil, true, { fail_reason = name .. ": " .. needle })
		end
	end
end

T["loop: Fix keeps the red regression test and review blocks scope creep"] = function()
	local fix = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/fix.md")), "\n")
	eq(fix:gsub("%s+", " "):find("least of all the red regression test an earlier pass added", 1, true) ~= nil, true)
	local review = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/review.md")), "\n")
	review = review:gsub("%s+", " ")
	eq(review:find("do not cover is `[must-fix]`", 1, true) ~= nil, true)
	eq(review:find("unless the gate needed it to go green (then say so", 1, true) ~= nil, true)
	local in_scope = "in scope, no finding: new test files for the change's scenarios, files `make fmt` changed"
		.. " only in whitespace, and `openspec/changes/<change>/`"
	eq(review:find(in_scope, 1, true) ~= nil, true, { fail_reason = review })
end

T["loop: Review lists every must-fix in one pass"] = function()
	local review = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/review.md")), " ")
	review = review:gsub("%s+", " ")
	for _, needle in ipairs({
		"check every unit that implements it (every adapter, caller or plugin integration, not a sample",
		"list all `[must-fix]` findings at once",
		"says why that pass missed it",
	}) do
		eq(review:find(needle, 1, true) ~= nil, true, { fail_reason = needle })
	end
	local fix = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/fix.md")), " ")
	local shared = "is fixed in every unit it applies to, each checked against its own native API"
	eq(fix:gsub("%s+", " "):find(shared, 1, true) ~= nil, true)
end

T["loop: Fix prompt shortens an overlong delta requirement"] = function()
	local fix = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/fix.md")), "\n")
	eq(fix:gsub("%s+", " "):find("Requirement text is very long", 1, true) ~= nil, true)
	eq(fix:find("spec_trial.py", 1, true) ~= nil, true)
end

T["loop: Adopted change with every task ticked skips the spec step"] = function()
	local done, todo = "## 1. Task\n- [x] 1.1 a", "## 1. Task\n- [x] 1.1 a\n- [ ] 1.2 b"
	local ui = {
		["openspec/changes/c/tasks.md"] = done,
		["openspec/changes/c/design.md"] = "# Design\n\n## Proposed render\nx",
	}
	eq(adopted_state(ui), { archived = false, tasks_done = true, visible_ui = true })
	local technical =
		{ ["openspec/changes/c/tasks.md"] = done, ["openspec/changes/c/design.md"] = "# Design\n\n## Decisions\nx" }
	eq(adopted_state(technical), { archived = false, tasks_done = true, visible_ui = false })
	local rejected = {
		["openspec/changes/c/tasks.md"] = done,
		["openspec/changes/c/proposal.md"] = "## Why\nx\n\n## Rejected run\n- review: test weakened",
	}
	eq(adopted_state(rejected), { archived = false, tasks_done = false, visible_ui = false })
	eq(
		adopted_state({ ["openspec/changes/c/tasks.md"] = done }),
		{ archived = false, tasks_done = true, visible_ui = false }
	)
	eq(
		adopted_state({ ["openspec/changes/c/tasks.md"] = todo }),
		{ archived = false, tasks_done = false, visible_ui = false }
	)
	eq(
		adopted_state({ ["openspec/changes/c/proposal.md"] = "# c" }),
		{ archived = false, tasks_done = false, visible_ui = false }
	)
	eq(adopted_state({ ["README.md"] = "x" }), { archived = true, tasks_done = false, visible_ui = false })
	local queue =
		table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/workflows/work-queue/work-queue.yaml")), "\n")
	eq(
		queue:find(
			'when: "$pick.output.found == true && $adopted-state.output.archived == false && $adopted-state.output.tasks_done == false"',
			1,
			true
		) ~= nil,
		true
	)
	local prompt = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")), " ")
	prompt = prompt:gsub("%s+", " ")
	eq(
		prompt:find(
			"`$ARTIFACTS_DIR/adopt-notes.md`, the hunks it gave up, only if it exists; never search for it",
			1,
			true
		) ~= nil,
		true
	)
end

return T
