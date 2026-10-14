local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPTS = vim.fs.joinpath(H.root, ".archon/scripts")
local BLOCKED = "## Blocked (needs user decision)\nlua_ls misses the 1 s bound: pick (A) or (B)."
local DECISION = "## Decision (user)\n1. keep the 1 s bound"
local LOOP_ONLY = "## Blocked\n- loop: trace.lua misreads a case name\nloop: gate log cut short"

---@param path string
---@return string
local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

---@param text string
---@param needle string
local function has(text, needle)
	eq(text:find(needle, 1, true) ~= nil, true, { fail_reason = ("%q not in:\n%s"):format(needle, text) })
end

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
---@return test.SystemResult
local function git_ok(args, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, args), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return result
end

---@param repo string
---@param message string
local function commit_all(repo, message)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", message }, repo)
end

--- Repo on `auto` with `base` committed, then on branch `run` with `files` written (uncommitted).
---@param base table<string, string>
---@param files table<string, string>
---@return string
local function branch_repo(base, files)
	local repo = H.tempdir(child)
	write(repo, vim.tbl_extend("force", { ["README.md"] = "x" }, base))
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	commit_all(repo, "initial")
	git_ok({ "checkout", "-q", "-b", "run" }, repo)
	write(repo, files)
	return repo
end

---@param script string
---@param cwd string
---@param env? table<string, string>
---@param artifacts? string ARTIFACTS_DIR (default: a new temp dir)
---@return table out decoded JSON stdout
---@return string artifacts
local function run(script, cwd, env, artifacts)
	artifacts = artifacts or H.tempdir(child)
	local full = vim.tbl_extend("force", H.GIT_ENV, { ARTIFACTS_DIR = artifacts, BASE_BRANCH = "auto" }, env or {})
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, script) }, cwd, full)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout), artifacts
end

T["loop: Queue spec prompt keeps the user's contract"] = function()
	local prompt = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md"))
	has(prompt, "never change a number or bound")
	has(prompt, "never REMOVE a requirement to ADD it again")
	has(prompt, "never reword the `## Decision` text")
	has(prompt, "keep any `## Blocked` section as it is")
end

T["loop: Queue spec prompt never empties a test file"] = function()
	local prompt = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	has(prompt, "A task never empties a test file: removing a file's last case deletes the file")
	has(prompt, "keep the copy in the file that would be emptied")
end

T["loop: Judge asks when a change re-adds a removed requirement"] = function()
	local delta = table.concat({
		"## REMOVED Requirements",
		"### Requirement: Server readiness",
		"**Reason**: replaced",
		"",
		"## ADDED Requirements",
		"### Requirement: Server readiness.",
		"Each server SHALL answer within 2.5 s.",
		"",
		"#### Scenario: s",
		"- **WHEN** x",
		"- **THEN** y",
	}, "\n")
	local repo = branch_repo({}, { ["openspec/changes/c/specs/lsp/spec.md"] = delta })
	local out = run("escalation.py", repo)
	eq(out.decision, "ask")
	has(out.reasons, "re-adds requirement 'Server readiness'")
end

T["loop: Judge asks when a change rewrites the user's Decision"] = function()
	local proposal = "## Why\nslow\n\n" .. DECISION .. "\n"
	local base = { ["openspec/changes/c/proposal.md"] = proposal }
	local reworded = branch_repo(base, { ["openspec/changes/c/proposal.md"] = proposal:gsub("1 s", "2.5 s") })
	local out = run("escalation.py", reworded)
	eq(out.decision, "ask")
	has(out.reasons, "rewrites the user's ## Decision in openspec/changes/c/proposal.md")
	local why_only = branch_repo(base, { ["openspec/changes/c/proposal.md"] = proposal:gsub("slow", "very slow") })
	eq(run("escalation.py", why_only).decision, "ship")
end

T["loop: Adopt reverts main spec edits"] = function()
	local repo = branch_repo({ ["openspec/specs/lsp/spec.md"] = "main" }, {})
	git_ok({ "checkout", "-q", "-b", "old", "auto" }, repo)
	write(
		repo,
		{ ["openspec/specs/lsp/spec.md"] = "edited", ["openspec/specs/new/spec.md"] = "new", ["lua/a.lua"] = "a" }
	)
	commit_all(repo, "old run")
	git_ok({ "checkout", "-q", "run" }, repo)
	local out = run("adopt.py", repo, { INPUTS_ADOPT = "old" })
	eq(out.conflict, false)
	has(out.summary, "adopted old:")
	has(out.summary, "reverted its main spec edits (openspec/specs/lsp/spec.md, openspec/specs/new/spec.md)")
	eq(git_ok({ "diff", "--name-only", "auto", "HEAD" }, repo).stdout, "lua/a.lua\n")
	eq(git_ok({ "status", "--porcelain" }, repo).stdout, "")
	eq(read(vim.fs.joinpath(repo, "openspec/specs/lsp/spec.md")), "main")
end

T["loop: Blocked queued change goes straight to the user"] = function()
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/changes/b/proposal.md"] = "## Why\nx\n\n" .. BLOCKED .. "\n\n## Impact\n- y",
		["openspec/changes/ok/proposal.md"] = "## Why\nx",
	})
	local out, artifacts = run("blocked.py", repo, { INPUTS_CHANGE = "b", LOOP_CHANGES_DIR = "" })
	eq(out, { blocked = true, text = "proposal.md: " .. BLOCKED })
	local escalation = read(vim.fs.joinpath(artifacts, "escalation.md"))
	has(escalation, "# Judge: ask")
	has(escalation, "pick (A) or (B)")
	eq(run("blocked.py", repo, { INPUTS_CHANGE = "ok", LOOP_CHANGES_DIR = "" }).blocked, false)
end

--- Commits everything in `repo` with committer date `date` (seconds since the epoch).
---@param repo string
---@param date integer
local function commit_at(repo, date)
	git_ok({ "add", "-A" }, repo)
	local env = vim.tbl_extend("force", H.GIT_ENV, { GIT_COMMITTER_DATE = ("@%d +0000"):format(date) })
	local result = H.system(child, { "git", "commit", "-q", "-m", "at " .. date }, repo, env)
	eq(result.code, 0, { fail_reason = result.stderr })
end

T["loop: A later user Decision resolves a Blocked section"] = function()
	local repo = branch_repo({}, { ["openspec/changes/b/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n" .. BLOCKED })
	commit_at(repo, 1700000000)
	write(repo, { ["openspec/changes/b/proposal.md"] = "## Why\nx\n\n" .. DECISION })
	commit_at(repo, 1700000100)
	eq(run("blocked.py", repo, { INPUTS_CHANGE = "b", LOOP_CHANGES_DIR = "" }).blocked, false)
	write(repo, { ["openspec/changes/b/tasks.md"] = "## 1. T\n\n" .. BLOCKED .. "\nagain" })
	eq(run("blocked.py", repo, { INPUTS_CHANGE = "b", LOOP_CHANGES_DIR = "" }).blocked, true)
end

T["loop: An Unblocked section resolves an earlier Blocked section"] = function()
	local repo = branch_repo({}, { ["openspec/changes/b/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n" .. BLOCKED })
	commit_at(repo, 1700000000)
	write(repo, { ["openspec/changes/b/proposal.md"] = "## Why\nx\n\n## Unblocked\nwrap the gsub call in parentheses" })
	commit_at(repo, 1700000100)
	eq(run("blocked.py", repo, { INPUTS_CHANGE = "b", LOOP_CHANGES_DIR = "" }).blocked, false)
end

T["loop: Verdict ends the build loop on a Blocked section"] = function()
	local repo = branch_repo({}, { ["openspec/changes/c/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n" .. BLOCKED })
	local out = run("verdict.py", repo, {
		INPUTS_CHANGE = "c",
		INPUTS_GREEN = "false",
		INPUTS_SPEC_OK = "true",
		INPUTS_TASKS_DONE = "false",
		INPUTS_CRITICAL = "0",
		INPUTS_ATTEMPT = "1",
		LOOP_CHANGES_DIR = "",
	})
	eq({ out.done, out.blocked, out.exhausted, out.passed }, { true, true, false, false })
end

T["loop: Judge quotes a Blocked section and asks"] = function()
	local repo = branch_repo({}, { ["openspec/changes/c/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n" .. BLOCKED })
	local out, artifacts = run("escalation.py", repo, {
		INPUTS_CHANGE = "c",
		INPUTS_EXHAUSTED = "true",
		INPUTS_FAILED_GATES = "tests",
		LOOP_CHANGES_DIR = "",
	})
	eq({ out.decision, out.escalate }, { "ask", true })
	has(out.reasons, "blocked: tasks.md: " .. BLOCKED)
	has(read(vim.fs.joinpath(artifacts, "escalation.md")), "lua_ls misses the 1 s bound")
end

T["loop: A Blocked section of only loop items never stops the change"] = function()
	local repo = branch_repo({}, { ["openspec/changes/c/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n" .. LOOP_ONLY })
	local env = { INPUTS_CHANGE = "c", LOOP_CHANGES_DIR = "" }
	local out, artifacts = run("blocked.py", repo, env)
	eq(out, { blocked = false, text = "" })
	eq(child.fn.filereadable(vim.fs.joinpath(artifacts, "escalation.md")), 0)
	local verdict = run("verdict.py", repo, {
		INPUTS_CHANGE = "c",
		INPUTS_GREEN = "false",
		INPUTS_SPEC_OK = "true",
		INPUTS_TASKS_DONE = "false",
		INPUTS_CRITICAL = "0",
		INPUTS_ATTEMPT = "1",
		LOOP_CHANGES_DIR = "",
	})
	eq({ verdict.done, verdict.blocked }, { false, false })
	write(repo, { ["openspec/changes/c/tasks.md"] = "## 1. T\n\n" .. LOOP_ONLY .. "\nthe 1 s bound cannot hold" })
	eq(run("blocked.py", repo, env).blocked, true)
end

local STUCK = '## Stuck\n- Probe: `Left: "[]"`, `Right: "{}"`\n- Attempt 2: round-trip still red'

T["loop: Verdict sends a Stuck section to the fix pass"] = function()
	local repo = branch_repo({}, { ["openspec/changes/c/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n" .. STUCK })
	local env = {
		INPUTS_CHANGE = "c",
		INPUTS_GREEN = "true",
		INPUTS_SPEC_OK = "true",
		INPUTS_TASKS_DONE = "true",
		INPUTS_CRITICAL = "0",
		INPUTS_APPROVE = "true",
		INPUTS_ATTEMPT = "1",
		LOOP_CHANGES_DIR = "",
	}
	local out = run("verdict.py", repo, env)
	eq({ out.done, out.passed, out.blocked, out.stuck, out.failed_gates }, { false, false, false, true, "stuck" })
	has(out.feedback, "stuck (tasks.md, earlier attempts; fix it, then delete the section): " .. STUCK)
	local workflow = read(vim.fs.joinpath(H.root, ".archon/workflows/nvim-deliver/nvim-deliver.yaml"))
	has(workflow, "- id: fix-stuck # the same fix pass at high effort when tasks.md has `## Stuck`")
	has(
		workflow,
		'effort: high\n          idle_timeout: 900000\n          when: "$LOOP_PREV.verdict.output.done == false && $LOOP_PREV.verdict.output.stuck == true"'
	)
end

T["loop: A Stuck change never asks and is never held before spec"] = function()
	local repo = branch_repo({}, { ["openspec/changes/c/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n" .. STUCK })
	local env = { INPUTS_CHANGE = "c", LOOP_CHANGES_DIR = "" }
	eq(run("blocked.py", repo, env), { blocked = false, text = "" })
	local judge = run("escalation.py", repo, vim.tbl_extend("force", env, { INPUTS_EXHAUSTED = "true" }))
	eq({ judge.decision, judge.escalate }, { "reject", false })
	has(judge.reasons, "- stuck:\n  ## Stuck\n  - Probe:")
	local tasks = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "tasks.py") }, repo, {
		ARTIFACTS_DIR = H.tempdir(child),
		INPUTS_CHANGE = "c",
	})
	eq(tasks.code, 0, { fail_reason = "the task loop ends on a Stuck section: " .. tasks.stderr })
end

T["loop: Agents decide small choices and record them"] = function()
	for _, name in ipairs({ "implement.md", "fix.md" }) do
		local prompt = read(vim.fs.joinpath(H.root, ".archon/commands", name)):gsub("%s+", " ")
		has(prompt, "record each in one line under `## Agent decisions` in tasks.md")
		has(
			prompt,
			"Write `## Blocked` only for a choice that changes user-visible behaviour beyond the spec or design"
		)
		has(prompt, "it states the question, the options and your recommendation")
		eq(prompt:find("block it with that evidence", 1, true), nil, { fail_reason = name })
	end
	has(read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")), "delete the `## Stuck` section in the same commit")
	has(
		read(vim.fs.joinpath(H.root, ".archon/commands/review.md")),
		"each line under tasks.md `## Agent decisions` is consistent"
	)
end

T["loop: Judge lists loop notes for the auditor"] = function()
	local repo = branch_repo({}, { ["openspec/changes/c/tasks.md"] = "## 1. T\n- [x] 1.1 x\n\n" .. LOOP_ONLY })
	local artifacts = H.tempdir(child)
	write(artifacts, { ["loop-notes.md"] = "loop: lock.sh owner read raced\n\n- loop: gate log cut short" })
	local out = run("escalation.py", repo, { INPUTS_CHANGE = "c", LOOP_CHANGES_DIR = "" }, artifacts)
	eq(out.decision, "ship")
	local escalation = read(vim.fs.joinpath(artifacts, "escalation.md"))
	for _, note in ipairs({ "trace.lua misreads a case name", "gate log cut short", "lock.sh owner read raced" }) do
		has(out.reasons, "\n- note: loop: " .. note)
		has(escalation, "- note: loop: " .. note)
	end
	eq(select(2, out.reasons:gsub("gate log cut short", "")), 1)
end

T["loop: Fix and implement prompts send loop tooling failures to loop notes"] = function()
	for _, name in ipairs({ "fix.md", "implement.md" }) do
		local prompt = read(vim.fs.joinpath(H.root, ".archon/commands", name))
		has(prompt, "append one line `loop: <failure>` to `$ARTIFACTS_DIR/loop-notes.md` (not tasks.md")
		eq(prompt:find("write `## Blocked` with `loop:", 1, true), nil, { fail_reason = name })
	end
end

T["loop: Judge hands the review findings to the follow-up"] = function()
	local repo = branch_repo({}, {})
	local findings = "## Removed assert\ntests/unit/x.lua drops the eq on the count\n" .. ("y"):rep(3000)
	local out = run("escalation.py", repo, { INPUTS_WEAKENED_TEST = "true", INPUTS_REVIEW_FINDINGS = findings })
	eq(out.decision, "reject")
	has(
		out.reasons,
		"- review: test weakened\n- review findings:\n  ## Removed assert\n  tests/unit/x.lua drops the eq"
	)
	local quoted = out.reasons:match("%- review findings:\n(.*)$")
	eq(#quoted:gsub("\n  ", "\n") <= 1500 + 2, true, { fail_reason = ("%d chars"):format(#quoted) })
	eq(out.reasons:find("\n## ", 1, true), nil)
	local shipped = run("escalation.py", repo, { INPUTS_REVIEW_FINDINGS = findings })
	eq({ shipped.decision, shipped.reasons:find("review findings", 1, true) }, { "ship", nil })
end

T["loop: A blocked run never ships"] = function()
	local out = run("decide.py", H.tempdir(child), {
		INPUTS_BLOCKED = "true",
		INPUTS_VERDICT = "ask",
		INPUTS_NEEDED = "true",
		INPUTS_DECISION = "approve",
	})
	eq({ out.go, out.decision }, { false, "reject" })
end

return T
