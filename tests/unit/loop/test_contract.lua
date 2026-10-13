local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPTS = vim.fs.joinpath(H.root, ".archon/scripts")
local BLOCKED = "## Blocked (needs user decision)\nlua_ls misses the 1 s bound: pick (A) or (B)."
local DECISION = "## Decision (user)\n1. keep the 1 s bound"

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
---@return table out decoded JSON stdout
---@return string artifacts
local function run(script, cwd, env)
	local artifacts = H.tempdir(child)
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
