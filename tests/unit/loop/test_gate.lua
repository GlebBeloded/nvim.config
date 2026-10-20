local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPTS = vim.fs.joinpath(H.root, ".archon/scripts")

---@param path string
---@return string
local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
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

--- `bin/<name>` in `dir`: an executable shell script.
---@param dir string
---@param name string
---@param body string
---@return string bin directory to prepend to PATH
local function fake_tool(dir, name, body)
	local bin = vim.fs.joinpath(dir, "bin")
	write(bin, { [name] = "#!/bin/sh\n" .. body })
	vim.fn.setfperm(vim.fs.joinpath(bin, name), "rwxr-xr-x")
	return bin
end

---@param text string
---@param needle string
local function has(text, needle)
	eq(text:find(needle, 1, true) ~= nil, true, { fail_reason = ("missing %q in:\n%s"):format(needle, text) })
end

---@return string red check log as tests/check.sh prints it: lint first, a long test section after it
local function red_check_log()
	local lines = {
		"FAIL lint             0.2 s",
		"ok   trace            0.5 s",
		"FAIL test            44.9 s",
		"",
		"===== lint =====",
		"error[undefined_variable]: `kmap` is not defined",
		"    ┌─ lua/gleb/keymaps.lua:134:1",
		"",
		"===== test =====",
		"\27[1mTotal number of cases:\27[0m 300",
	}
	for i = 1, 200 do
		table.insert(lines, ("tests/integration/a/test_a.lua | a: case %d: \27[1;32mo\27[0m"):format(i))
	end
	vim.list_extend(lines, {
		"\27[1mFails (2) and Notes (0)\27[0m",
		"\27[1;31mFAIL\27[0m in tests/integration/a/test_a.lua | a: first broken case:",
		"  Failed expectation for equality",
		"\27[1;31mFAIL\27[0m in tests/screen/statusline/test_b.lua | statusline: second broken case:",
	})
	for i = 1, 100 do
		table.insert(lines, ("  Traceback line %d"):format(i))
	end
	vim.list_extend(lines, { "", "check: FAILED: lint test (46.2 s)" })
	return table.concat(lines, "\n")
end

T["loop: Gate failures keep an early lint section"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	write(scratch, { ["check.log"] = red_check_log() })
	local bin = fake_tool(scratch, "make", ('cat "%s/check.log"\nexit 1'):format(scratch))
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "", PATH = bin .. ":" .. vim.env.PATH }

	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "gate.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local verdict = vim.json.decode(result.stdout)
	eq(verdict.green, false)
	local failures = verdict.failures
	has(failures, vim.fs.joinpath(artifacts, "check-1.log"))
	has(failures, "FAIL lint             0.2 s")
	has(failures, "check: FAILED: lint test (46.2 s)")
	has(failures, "error[undefined_variable]: `kmap` is not defined")
	has(failures, "tests/integration/a/test_a.lua | a: first broken case")
	has(failures, "tests/screen/statusline/test_b.lua | statusline: second broken case")
	eq(failures:find("\27", 1, true), nil)
	eq(failures:find(" | a: case 1: o", 1, true), nil)
	eq(#failures <= 5000, true)
	eq(read(vim.fs.joinpath(artifacts, "check-1.log")):find("\27", 1, true), nil)
end

T["loop: Gate gives language servers a long timeout"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	local bin = fake_tool(scratch, "make", ('echo "$LSP_TIMEOUT_MS" >"%s/lsp_timeout"'):format(scratch))
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "", PATH = bin .. ":" .. vim.env.PATH }

	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "gate.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read(vim.fs.joinpath(scratch, "lsp_timeout")), "120000")
end

---@param value string?
---@param default_ms integer
---@return integer
local function lsp_timeout_with(value, default_ms)
	local saved = vim.env.LSP_TIMEOUT_MS
	vim.env.LSP_TIMEOUT_MS = value
	local ok, ms = pcall(H.lsp_timeout, default_ms)
	vim.env.LSP_TIMEOUT_MS = saved
	assert(ok, ms)
	return ms
end

T["loop: LSP waits in tests honor LSP_TIMEOUT_MS"] = function()
	eq(lsp_timeout_with(nil, 10000), 10000)
	eq(lsp_timeout_with("", 10000), 10000)
	eq(lsp_timeout_with("abc", 10000), 10000)
	eq(lsp_timeout_with("0", 10000), 10000)
	eq(lsp_timeout_with("120000", 10000), 120000)
end

T["loop: Types output drops LuaLS progress lines"] = function()
	local repo = H.tempdir(child)
	local progress = [[printf '>>>>>>>>=====  12/369 [Found 5 problems in 1 files]\r>>>>>>>>>>>>= 300/369\n']]
	local diagnostic =
		[[printf 'lua/x.lua:1:1 [Warning] Undefined global `kmap`.\nDiagnosis complete, 1 problems found\n']]
	local luals = ('[ "$1" = --version ] && { echo 3.0.0; exit 0; }\n%s\n%s\nexit 1'):format(progress, diagnostic)
	local bin = fake_tool(H.tempdir(child), "lua-language-server", luals)
	local env = { PATH = bin .. ":" .. vim.env.PATH, VIMRUNTIME = vim.env.VIMRUNTIME }

	local result = H.system(child, { "sh", vim.fs.joinpath(H.root, "tests/types.sh") }, repo, env)
	eq(result.code, 1, { fail_reason = result.stdout .. result.stderr })
	has(result.stdout, "lua/x.lua:1:1 [Warning] Undefined global `kmap`.")
	has(result.stdout, "Diagnosis complete, 1 problems found")
	eq(result.stdout:find("/369", 1, true), nil, { fail_reason = result.stdout })
end

T["loop: Fix prompt reruns failed files and names reference commits"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md"))
	has(fix, "Rerun every test file named in a `FAIL in …` line")
	has(fix, "`tests/screen/<area>`")
	has(fix, "never a `check-*.log` glob")
	has(fix, "at most `-C 3`")
	has(fix, "never a broad multi-word `rg` over\n`lua tests`")
	has(fix, "only when its cell diff is limited to UI that\na merged or base commit changed; name that commit")
	eq(fix:find("Rerun only", 1, true), nil)
end

---@param tasks string
---@return boolean has_task
local function pack_has_task(tasks)
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["openspec/changes/c/tasks.md"] = tasks,
	})
	local env = { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "context_pack.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local out = vim.json.decode(result.stdout)
	eq(out.context, vim.fs.joinpath(artifacts, "context.md"))
	return out.has_task
end

T["loop: Steps commit the run files they edit"] = function()
	local repo = H.tempdir(child)
	write(repo, { ["openspec/changes/c/tasks.md"] = "- [ ] 1.1 x", ["lua/a.lua"] = "a" })
	for _, cmd in ipairs({ { "init", "-q", "-b", "auto" }, { "add", "-A" }, { "commit", "-qm", "base" } }) do
		eq(H.system(child, vim.list_extend({ "git" }, cmd), repo, H.GIT_ENV).code, 0)
	end
	write(repo, { ["openspec/changes/c/tasks.md"] = "- [x] 1.1 x", ["lua/a.lua"] = "edited" })
	local commit = "import sys; sys.path.insert(0, sys.argv[1]); import integrity; "
		.. "print(integrity.commit_paths('tick', 'openspec/changes/c/tasks.md'), integrity.commit_paths('again', 'openspec/changes/c/tasks.md'))"
	local result = H.system(child, { "python3", "-c", commit, SCRIPTS }, repo, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(vim.trim(result.stdout), "True False")
	local status = H.system(child, { "git", "status", "--porcelain" }, repo, H.GIT_ENV)
	eq(vim.trim(status.stdout), "M lua/a.lua")
	has(
		read(vim.fs.joinpath(SCRIPTS, "gate.py")),
		'commit_paths(f"chore(openspec): tick gate items of {change}", str(tasks))'
	)
	has(
		read(vim.fs.joinpath(SCRIPTS, "escalation.py")),
		'commit_paths("docs(workflow): loop lessons", "docs/workflow.md")'
	)
end

T["loop: Context pack reports when no task is left"] = function()
	eq(pack_has_task("## 1. Done\n- [x] 1.1 a"), false)
	eq(pack_has_task("## 1. Todo\n- [x] 1.1 a\n- [ ] 1.2 b"), true)
	local workflow = read(vim.fs.joinpath(H.root, ".archon/workflows/nvim-deliver/nvim-deliver.yaml"))
	has(
		workflow,
		'- id: implement\n          command: implement\n          depends_on: [pack]\n          when: "$pack.output.has_task == true"'
	)
end

T["loop: Startup timing fails on a startup error"] = function()
	-- a checkout copy whose init.lua fails: the harness finds its root from its own file path
	local root = H.tempdir(child)
	write(root, { ["init.lua"] = 'error("smoke-startup-boom")' })
	for _, file in ipairs({ "minimal_init.lua", "helpers.lua", "smoke/run.lua", "smoke/budget.lua" }) do
		write(root, { ["tests/" .. file] = read(vim.fs.joinpath(H.root, "tests", file)) })
	end
	local env = { TEST_DEPS_DIR = vim.fs.joinpath(H.root, ".tests/deps"), STARTUP_BUDGET_MS = "100000" }
	local cmd = { vim.v.progpath, "-u", "tests/minimal_init.lua", "-l", "tests/smoke/run.lua", "startup" }

	local result = H.system(child, cmd, root, env)
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	has(result.stdout, "FAIL startup exited cleanly without stderr")
	has(result.stdout, "smoke-startup-boom")
end

--- Repo on `auto` holding `files`, then on branch `run`.
---@param files table<string, string>
---@return string
local function branch_repo(files)
	local repo = H.tempdir(child)
	write(repo, files)
	for _, args in ipairs({
		{ "init", "-q", "-b", "auto" },
		{ "add", "-A" },
		{ "commit", "-q", "-m", "i" },
		{ "checkout", "-q", "-b", "run" },
	}) do
		local result = H.system(child, vim.list_extend({ "git" }, args), repo, H.GIT_ENV)
		eq(result.code, 0, { fail_reason = result.stderr })
	end
	return repo
end

---@param script string gate.py, verdict.py or escalation.py
---@param repo string
---@param env table<string, string>
---@return table
local function loop_script(script, repo, env)
	local full = vim.tbl_extend("force", H.GIT_ENV, { BASE_BRANCH = "auto", INPUTS_CHANGE = "" }, env)
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, script) }, repo, full)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout)
end

---@param artifacts string
---@param extra? table<string, string>
---@return table<string, string> verdict inputs of a pass whose gates all hold
local function verdict_env(artifacts, extra)
	local env =
		{ ARTIFACTS_DIR = artifacts, INPUTS_GREEN = "true", INPUTS_SPEC_OK = "true", INPUTS_TASKS_DONE = "true" }
	env = vim.tbl_extend(
		"force",
		env,
		{ INPUTS_CRITICAL = "0", INPUTS_APPROVE = "true", INPUTS_ATTEMPT = "1", INPUTS_FULL_GREEN = "true" }
	)
	return vim.tbl_extend("force", env, extra or {})
end

T["loop: Verdict passes only after the full gate is green"] = function()
	local repo = branch_repo({ ["README.md"] = "x" })
	local full_red = { INPUTS_FULL_GREEN = "false", INPUTS_FULL_FAILURES = "full make check E2E=1 is red: e2e" }
	local red = loop_script("verdict.py", repo, verdict_env(H.tempdir(child), full_red))
	eq({ red.passed, red.done, red.failed_gates }, { false, false, "full" })
	has(red.feedback, "full make check E2E=1 is red: e2e")
	local skipped = loop_script("verdict.py", repo, verdict_env(H.tempdir(child), { INPUTS_FULL_GREEN = "skipped" }))
	eq({ skipped.passed, skipped.failed_gates }, { false, "full" })
	local green = loop_script("verdict.py", repo, verdict_env(H.tempdir(child)))
	eq(green.passed, true)
	local quick_red = verdict_env(H.tempdir(child), { INPUTS_GREEN = "false", INPUTS_FULL_GREEN = "skipped" })
	eq(loop_script("verdict.py", repo, quick_red).failed_gates, "tests")
end

T["loop: Gate checks hard rules before make check"] = function()
	local repo = branch_repo({ ["tests/unit/a/test_a.lua"] = 'T["a: one"] = function() end' })
	write(repo, { ["tests/unit/a/test_a.lua"] = "-- emptied" })
	local scratch = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local bin = fake_tool(scratch, "make", ('touch "%s/make-ran"'):format(scratch))

	local gate = loop_script("gate.py", repo, { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH })
	eq(
		{ gate.green, vim.fn.filereadable(vim.fs.joinpath(scratch, "make-ran")) },
		{ false, 0 },
		{ fail_reason = gate.failures }
	)
	has(gate.failures, "hard rule: 1 test case(s) removed: a: one")
	local env = verdict_env(artifacts, { INPUTS_GREEN = "false", INPUTS_FAILURES = gate.failures })
	local verdict = loop_script("verdict.py", repo, env)
	local _, count = verdict.feedback:gsub("test case%(s%) removed", "")
	eq({ verdict.done, count }, { false, 1 }, { fail_reason = verdict.feedback })
end

T["loop: Gate lists planning files a fix pass edited"] = function()
	local change = {
		["openspec/changes/c/proposal.md"] = "# c",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [ ] 1.1 a",
		["openspec/changes/c/specs/x/spec.md"] = "## ADDED Requirements",
	}
	local repo = branch_repo(change)
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	fake_tool(scratch, "openspec", "exit 0")
	local bin = fake_tool(scratch, "make", "exit 0")
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "c", PATH = bin .. ":" .. vim.env.PATH }
	local scope = vim.fs.joinpath(artifacts, "fix-scope.md")

	loop_script("verdict.py", repo, verdict_env(artifacts, { INPUTS_CHANGE = "c", INPUTS_APPROVE = "false" }))
	write(repo, {
		["openspec/changes/c/proposal.md"] = "# c, rescoped",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [x] 1.1 a",
	})
	loop_script("gate.py", repo, env)
	has(read(scope), "openspec/changes/c/proposal.md")
	eq(read(scope):find("tasks.md", 1, true), nil)
	local red = verdict_env(artifacts, { INPUTS_CHANGE = "c", INPUTS_GREEN = "false" })
	has(loop_script("verdict.py", repo, red).feedback, "fix pass edited planning files")
	loop_script("gate.py", repo, env)
	eq(vim.fn.filereadable(scope), 0)
	has(read(vim.fs.joinpath(H.root, ".archon/commands/review.md")), "`$ARTIFACTS_DIR/fix-scope.md`")
end

T["loop: Gate skips the fix-scope check once the change is archived"] = function()
	local repo = branch_repo({
		["openspec/changes/c/proposal.md"] = "# c",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [x] 1.1 a",
	})
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	fake_tool(scratch, "openspec", "exit 0")
	local bin = fake_tool(scratch, "make", "exit 0")
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "c", PATH = bin .. ":" .. vim.env.PATH }
	loop_script("verdict.py", repo, verdict_env(artifacts, { INPUTS_CHANGE = "c", INPUTS_APPROVE = "false" }))
	child.lua(
		"vim.fn.rename(...)",
		{ vim.fs.joinpath(repo, "openspec/changes/c"), vim.fs.joinpath(repo, "openspec/changes/archive-c") }
	)
	loop_script("gate.py", repo, env)
	eq(vim.fn.filereadable(vim.fs.joinpath(artifacts, "fix-scope.md")), 0)
end

T["loop: Fix prompt stays on the listed findings"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " ")
	has(fix, "when every finding below starts with `hard rule:`, load none")
	has(fix, "never edit the change's proposal.md, .openspec.yaml or spec deltas unless a finding is about them")
end

--- make stub: `make check` prints a check log whose `targets` failed with `case` failing; `make test`
--- appends its arguments to `<scratch>/reruns` and exits `rerun_code`.
---@param scratch string
---@param targets string
---@param rerun_code integer
---@return string bin
local function flaky_make(scratch, targets, rerun_code)
	local log = table.concat({
		"FAIL test 1.0 s",
		"===== test =====",
		"FAIL in tests/unit/a/test_a.lua | a: flaky case:",
		"check: FAILED: " .. targets .. " (1.0 s)",
	}, "\n")
	write(scratch, { ["check.log"] = log })
	local pass = "tests/unit/a/test_a.lua | a: flaky case: o"
	local body =
		'if [ "$1" = test ]; then echo "$2 $3" >>"%s/reruns"; echo "%s"; exit %d; fi\ncat "%s/check.log"\nexit 1'
	return fake_tool(scratch, "make", body:format(scratch, pass, rerun_code, scratch))
end

T["loop: Gate names the overlong delta requirement and its repro"] = function()
	local long = string.rep("The session SHALL keep its name. ", 20)
	local repo = branch_repo({
		["openspec/changes/c/proposal.md"] = "# c",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [x] 1.1 a",
		["openspec/changes/c/specs/session/spec.md"] = "## MODIFIED Requirements\n\n### Requirement: Restore on bare startup\n"
			.. long
			.. "\n\n#### Scenario: x\n- **WHEN** x\n- **THEN** y",
	})
	local artifacts, scratch = H.tempdir(child), H.tempdir(child)
	fake_tool(scratch, "openspec", "echo 'Requirement text is very long'; exit 1")
	local bin = fake_tool(scratch, "make", "exit 0")
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "c", PATH = bin .. ":" .. vim.env.PATH }
	local out = loop_script("gate.py", repo, env)
	eq(out.spec_ok, false)
	has(out.failures, "python3 .archon/scripts/spec_trial.py c")
	has(out.failures, "delta `Restore on bare startup`")
	has(out.failures, "limit 500")
end

T["loop: Gate passes a test case that passes on rerun"] = function()
	local repo = branch_repo({ ["README.md"] = "x" })
	local case = "tests/unit/a/test_a.lua | a: flaky case"
	local function gate(targets, rerun_code)
		local scratch, artifacts = H.tempdir(child), H.tempdir(child)
		local env =
			{ ARTIFACTS_DIR = artifacts, PATH = flaky_make(scratch, targets, rerun_code) .. ":" .. vim.env.PATH }
		local reruns = vim.fs.joinpath(scratch, "reruns")
		local out = loop_script("gate.py", repo, env)
		return out,
			vim.fn.filereadable(reruns) == 1 and read(reruns) or "",
			read(vim.fs.joinpath(artifacts, "check-1.log"))
	end

	local passed, reruns, log = gate("test", 0)
	eq({ passed.green, passed.flaky, reruns }, { true, { case }, "FILE=tests/unit/a/test_a.lua CASE=a: flaky case" })
	has(log, "flaky (failed, then passed on rerun): " .. case)
	local failed, failed_reruns = gate("test", 1)
	eq({ failed.green, failed.flaky, failed_reruns ~= "" }, { false, {}, true })
	local other, other_reruns = gate("lint test", 0)
	eq({ other.green, other.flaky, other_reruns }, { false, {}, "" })

	local artifacts = H.tempdir(child)
	local env = verdict_env(artifacts, { INPUTS_FLAKY = vim.json.encode(passed.flaky) })
	local verdict = loop_script("verdict.py", repo, env)
	eq(verdict.passed, true)
	has(verdict.notes, case)
	local judge = loop_script("escalation.py", repo, { ARTIFACTS_DIR = artifacts, INPUTS_NOTES = verdict.notes })
	eq(judge.decision, "ship")
	has(judge.reasons, "- note: flaky test cases (failed, then passed on rerun): " .. case)
end

local READINESS_PASS = "tests/integration/lsp/test_readiness.lua | lsp: slow case: o"

--- make stub: `make check` prints `log`; any other target appends its arguments to `<scratch>/reruns`,
--- prints `<scratch>/<target>.out` (`outputs`; a readiness rerun prints its case as passed) and exits
--- `<scratch>/<target>.code` when given, else `rerun_code`.
---@param scratch string
---@param log string[]
---@param rerun_code integer
---@param outputs? table<string, string>
---@return string bin
local function rerun_make(scratch, log, rerun_code, outputs)
	local files = vim.tbl_extend("force", { ["check.log"] = table.concat(log, "\n") }, outputs or {})
	write(scratch, vim.tbl_extend("keep", files, { ["test-readiness.out"] = READINESS_PASS }))
	local body = table.concat({
		'if [ "$1" != check ]; then echo "$*" >>"%s/reruns"',
		'[ -f "%s/$1.out" ] && cat "%s/$1.out"',
		'[ -f "%s/$1.code" ] && exit "$(cat "%s/$1.code")"',
		"exit %d; fi",
		'cat "%s/check.log"',
		"exit 1",
	}, "\n")
	local s = scratch
	return fake_tool(scratch, "make", body:format(s, s, s, s, s, rerun_code, s))
end

--- gate.py on a check printing `log`, its reruns exiting `rerun_code` (rerun_make).
---@param log string[]
---@param rerun_code integer
---@param files? table<string, string> on the base branch
---@param opts? { outputs?: table<string, string>, branch?: table<string, string>, env?: table<string, string>, tools?: table<string, string> }
---@return table verdict, string reruns, string check_log, string artifacts, string repo
local function rerun_gate(log, rerun_code, files, opts)
	opts = opts or {}
	local repo = branch_repo(vim.tbl_extend("force", { ["README.md"] = "x" }, files or {}))
	write(repo, opts.branch or {})
	local scratch, artifacts = H.tempdir(child), H.tempdir(child)
	local bin = rerun_make(scratch, log, rerun_code, opts.outputs)
	for name, body in pairs(opts.tools or {}) do
		fake_tool(scratch, name, body)
	end
	local env =
		vim.tbl_extend("force", { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH }, opts.env or {})
	local out = loop_script("gate.py", repo, env)
	local reruns = vim.fs.joinpath(scratch, "reruns")
	local rerun_list = vim.fn.filereadable(reruns) == 1 and read(reruns) or ""
	return out, rerun_list, read(vim.fs.joinpath(artifacts, "check-1.log")), artifacts, repo
end

--- gate.py on a branch editing `branch` (over `base`), its make stub logging each call with CAPS to `calls`
--- and exiting `quick_code` on the quick tier (a CHECK_TARGETS check), 0 on the full check; `env` adds inputs.
---@param base table<string, string>
---@param branch table<string, string>
---@param quick_code integer
---@return table verdict, string calls, string artifacts
local function tier_gate(base, branch, quick_code, env)
	local repo = branch_repo(vim.tbl_extend("force", { ["README.md"] = "x" }, base))
	write(repo, branch)
	local scratch, artifacts = H.tempdir(child), H.tempdir(child)
	local body = 'echo "$* CAPS=$CAPS" >>"%s/calls"\ncase "$2" in CHECK_TARGETS=*) exit %d;; esac\nexit 0'
	local bin = fake_tool(scratch, "make", body:format(scratch, quick_code))
	env = vim.tbl_extend("force", { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH }, env or {})
	local out = loop_script("gate.py", repo, env)
	return out, read(vim.fs.joinpath(scratch, "calls")), artifacts
end

T["loop: Gate runs the quick tier before the full check"] = function()
	local base = { ["tests/integration/pr/test_a.lua"] = "-- a", ["tests/unit/loop/test_b.lua"] = "-- b" }
	local quick = "check CHECK_TARGETS=lint types trace specs test"
	local full = "check E2E=1 CAPS="
	local pr = { ["lua/gleb/pr/view.lua"] = "-- v", ["tests/integration/pr/test_a.lua"] = "-- a2" }

	local red, red_calls, artifacts = tier_gate(base, pr, 1)
	eq({ red.green, red_calls }, { false, quick .. " CAPS=pr" })
	has(read(vim.fs.joinpath(artifacts, "check-1.log")), "quick tier: lint types trace specs test with CAPS=pr")
	local green, calls, green_artifacts = tier_gate(base, pr, 0)
	eq({ green.green, calls }, { true, quick .. " CAPS=pr" })
	eq(vim.fn.filereadable(vim.fs.joinpath(green_artifacts, "check-1.log")), 1)

	local _, loop_calls = tier_gate(base, { [".archon/scripts/x.py"] = "x" }, 0)
	eq(loop_calls, "check CHECK_TARGETS=lint types trace specs loop-test CAPS=")
	local _, shared_calls = tier_gate(base, { ["init.lua"] = "-- i", ["docs/a.md"] = "a" }, 0)
	eq(shared_calls, quick .. " CAPS=")
	local _, docs_calls = tier_gate(base, { ["docs/a.md"] = "a", ["openspec/changes/c/proposal.md"] = "# c" }, 0)
	eq(docs_calls, "check CHECK_TARGETS=lint types trace specs CAPS=")
	local e2e = { ["lua/gleb/pr/view.lua"] = "-- v", ["tests/e2e/find-action/test_x.lua"] = "-- x" }
	local _, e2e_calls =
		tier_gate(vim.tbl_extend("force", base, { ["tests/unit/find-action/test_f.lua"] = "-- f" }), e2e, 0)
	eq(e2e_calls, quick .. " CAPS=find-action,pr")
	-- a support file maps to the tests that name it; a shared one, or one no test names, to every capability
	local used = vim.tbl_extend("force", base, { ["tests/fixtures/gh/data.lua"] = "-- d" })
	used["tests/integration/pr/test_a.lua"] = "local D = require('tests.fixtures.gh.data')"
	local _, used_calls = tier_gate(used, { ["tests/fixtures/gh/data.lua"] = "-- d2" }, 0)
	eq(used_calls, quick .. " CAPS=pr")
	local _, unused_calls = tier_gate(base, { ["tests/fixtures/other/x.lua"] = "-- x" }, 0)
	eq(unused_calls, quick .. " CAPS=")
	local _, plugin_calls = tier_gate(base, { ["lua/gleb/plugins/editor.lua"] = "-- p" }, 0)
	eq(plugin_calls, quick .. " CAPS=")
	local _, sandbox_calls = tier_gate(base, { ["lua/gleb/pr/view.lua"] = "-- v", ["tests/sandbox/x.sh"] = "x" }, 0)
	eq(sandbox_calls, quick .. " loop-test CAPS=pr")
	local _, smoke_calls = tier_gate(base, { ["lua/gleb/pr/view.lua"] = "-- v", ["tests/smoke/x.lua"] = "x" }, 0)
	eq(smoke_calls, quick .. " CAPS=pr")
	-- the full-gate node: only the full check, no attempt of its own
	local full_out, full_calls = tier_gate(base, pr, 1, { INPUTS_TIER = "full" })
	eq({ full_out.green, full_calls, full_out.attempt }, { true, full, 1 })
	-- a module other areas require runs their tests too
	local graph = vim.tbl_extend("force", base, {
		["tests/integration/git/test_g.lua"] = "-- g",
		["lua/gleb/git/base.lua"] = "return {}",
		["lua/gleb/pr/init.lua"] = 'local base = require("gleb.git.base")',
	})
	local _, graph_calls = tier_gate(graph, { ["lua/gleb/git/base.lua"] = "return { x = 1 }" }, 0)
	eq(graph_calls, quick .. " CAPS=git,pr")
end

T["loop: Gate reruns a known flaky case up to three times"] = function()
	local file = "tests/unit/a/test_a.lua"
	local log = {
		"FAIL test 1.0 s",
		"===== test =====",
		"FAIL in " .. file .. " | a: slow case:",
		"check: FAILED: test (1.0 s)",
	}
	local base = {
		[file] = 'T["a: slow case"] = function() end',
		["tests/flaky.txt"] = "# known\n" .. file .. " | a: slow case",
	}
	--- make stub: the check prints `log`; rerun n passes when n reaches `pass_at`
	local function gate(pass_at, files, branch, artifacts)
		local repo = branch_repo(vim.tbl_extend("force", { ["README.md"] = "x" }, files))
		write(repo, branch or {})
		local scratch = H.tempdir(child)
		artifacts = artifacts or H.tempdir(child)
		vim.fn.mkdir(artifacts, "p")
		write(scratch, { ["check.log"] = table.concat(log, "\n") })
		local body = table.concat({
			'if [ "$1" = check ]; then cat "%s/check.log"; exit 1; fi',
			'echo x >>"%s/reruns"; n=$(wc -l <"%s/reruns")',
			'[ "$n" -ge %d ] && { echo "%s | a: slow case: o"; exit 0; }',
			"exit 1",
		}, "\n")
		local s = scratch
		local bin = fake_tool(scratch, "make", body:format(s, s, s, pass_at, file))
		local out = loop_script("gate.py", repo, { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH })
		local reruns = vim.fs.joinpath(scratch, "reruns")
		return out, vim.fn.filereadable(reruns) == 1 and #vim.fn.readfile(reruns) or 0
	end

	local third, third_runs = gate(3, base)
	eq({ third.green, third.flaky, third_runs }, { true, { file .. " | a: slow case" }, 3 })
	local never, never_runs = gate(4, base)
	eq({ never.green, never_runs }, { false, 3 })
	local plain, plain_runs = gate(2, { [file] = base[file] })
	eq({ plain.green, plain_runs }, { false, 1 })
	-- the gates' history: passed on rerun in 3 earlier runs (flake_stats.py), with no tests/flaky.txt line
	-- (log times set explicitly: after the test file's commit counts, before it is history a fix reset)
	local function runs_dir(offset)
		local runs = vim.fs.joinpath(H.tempdir(child), "runs") -- as Archon's artifacts/runs/<run id>
		for _, run in ipairs({ "r1", "r2", "r3" }) do
			local path = vim.fs.joinpath(runs, run, "check-1.log")
			write(runs, { [run .. "/check-1.log"] = "===== rerun " .. file .. " | a: slow case: boom: ok =====" })
			vim.uv.fs_utime(path, os.time() + offset, os.time() + offset)
		end
		return vim.fs.joinpath(runs, "now")
	end
	local history, history_runs = gate(3, { [file] = base[file] }, nil, runs_dir(3600))
	eq({ history.green, history_runs }, { true, 3 })
	local stale, stale_runs = gate(3, { [file] = base[file] }, nil, runs_dir(-3600))
	eq({ stale.green, stale_runs }, { false, 1 })
	local added = gate(1, { [file] = base[file] }, { ["tests/flaky.txt"] = file .. " | a: slow case" })
	eq(added.green, false)
	has(added.failures, "hard rule: tests/flaky.txt gains a case on this branch")
end

T["loop: Gate reruns a failed readiness case once"] = function()
	local case = "tests/integration/lsp/test_readiness.lua | lsp: slow case"
	local log = {
		"FAIL test-readiness 9.0 s",
		"===== test-readiness =====",
		"FAIL in " .. case .. ":",
		"check: FAILED: test-readiness (9.0 s)",
	}
	local passed, reruns, check_log = rerun_gate(log, 0)
	eq({ passed.green, passed.flaky, reruns }, { true, { case }, "test-readiness CASE=lsp: slow case" })
	has(check_log, "flaky (failed, then passed on rerun): " .. case)
	local failed = rerun_gate(log, 1)
	eq({ failed.green, failed.flaky }, { false, {} })
end

T["loop: Gate reruns a readiness case whose label carries its error"] = function()
	local file = "tests/integration/lsp/test_readiness.lua"
	local label = file .. " | lsp: slow case: ready after 3157 ms, bound 2500 ms"
	local log = {
		"FAIL test-readiness 9.0 s",
		"===== test-readiness =====",
		"FAIL in " .. label,
		"check: FAILED: test-readiness (9.0 s)",
	}
	local _, reruns = rerun_gate(log, 0, { [file] = 'T["lsp: slow case"] = function() end' })
	eq(reruns, "test-readiness CASE=lsp: slow case")
end

T["loop: Gate reruns e2e once after a sandbox failure"] = function()
	local infra = "sandbox: nvim-e2e did not answer SSH within 180 s (/tmp/vm.log)"
	local function e2e_log(body)
		return vim.list_extend(
			{ "FAIL e2e 230.0 s", "===== e2e =====" },
			vim.list_extend(body, { "make[2]: *** [e2e] Error 1", "", "check: FAILED: e2e (230.3 s)" })
		)
	end
	local sandbox = { "Error: VM 'nvim-e2e' is not running", "[2026-10-13T17:49:01Z] INFO: Cleaned up", infra }
	local passed, reruns = rerun_gate(e2e_log(sandbox), 0)
	eq({ passed.green, passed.flaky, reruns }, { true, { "e2e: " .. infra }, "e2e E2E=1" })
	local failed, failed_reruns = rerun_gate(e2e_log(sandbox), 1)
	eq({ failed.green, failed.flaky, failed_reruns }, { false, {}, "e2e E2E=1" })
	local broken, broken_reruns = rerun_gate(e2e_log({ "FAIL in tests/e2e/a/test_a.lua | a: key:", infra }), 0)
	eq({ broken.green, broken_reruns }, { false, "" })
	local other, other_reruns = rerun_gate(e2e_log({ "keys: Accessibility not granted" }), 0)
	eq({ other.green, other_reruns }, { false, "" })
end

T["loop: Gate reruns smoke-health once after a checkhealth error"] = function()
	local error = 'vim.health | - ❌ ERROR Failed to run healthcheck for "vim.health" plugin. Exception:'
	local log = {
		"FAIL smoke-health 22.8 s",
		"===== smoke-health =====",
		"FAIL checkhealth without ERROR: vim.health",
		"     " .. error,
		"check: FAILED: smoke-health (169.7 s)",
	}
	local passed, reruns = rerun_gate(log, 0)
	eq({ passed.green, passed.flaky, reruns }, { true, { "smoke-health: " .. error }, "smoke-health" })
	local failed, failed_reruns = rerun_gate(log, 1)
	eq({ failed.green, failed.flaky, failed_reruns }, { false, {}, "smoke-health" })
end

T["loop: Gate reruns the stack layer once after a failure"] = function()
	local failure = "FAIL in tests/stack/shortcuts/test_stack.lua | shortcuts: Cmd+L moves focus: stack: timed out"
	local log = {
		"FAIL stack 25.0 s",
		"===== stack =====",
		failure,
		"check: FAILED: stack (169.7 s)",
	}
	local passed, reruns = rerun_gate(log, 0)
	eq({ passed.green, passed.flaky, reruns }, { true, { "stack: " .. failure }, "stack" })
	local failed, failed_reruns = rerun_gate(log, 1)
	eq({ failed.green, failed.flaky, failed_reruns }, { false, {}, "stack" })
end

--- check log of a pass failing in `test-readiness` on `lsp: slow case` and in e2e on `e2e_body`.
---@param e2e_body string[]
---@return string[]
local function readiness_e2e_log(e2e_body)
	local log = { "FAIL e2e 5.0 s", "FAIL test-readiness 9.0 s", "===== e2e =====" }
	vim.list_extend(log, e2e_body)
	return vim.list_extend(log, {
		"make[2]: *** [e2e] Error 1",
		"===== test-readiness =====",
		"FAIL in tests/integration/lsp/test_readiness.lua | lsp: slow case: ready after 2694 ms, bound 2500 ms",
		"check: FAILED: e2e test-readiness (110.2 s)",
	})
end

T["loop: Gate stops on sandbox infra that fails again on rerun"] = function()
	local abort = "sandbox: pulling macos-tahoe-vanilla:latest needs ~42 GB while it unpacks: 60 GB free would leave"
		.. " 18 GB, under the 25 GB reserve. Aborted."
	local outputs = { ["e2e.out"] = abort .. "\nmake: *** [e2e] Error 1", ["e2e.code"] = "1" }
	local files = { ["tests/integration/lsp/test_readiness.lua"] = 'T["lsp: slow case"] = function() end' }
	local out, reruns, _, artifacts, repo = rerun_gate(readiness_e2e_log({ abort }), 0, files, { outputs = outputs })
	eq({ out.green, out.flaky, out.infra }, { false, {}, abort })
	eq(reruns, "e2e E2E=1\ntest-readiness CASE=lsp: slow case")
	has(out.failures, "infra: e2e did not run (sandbox failed twice): " .. abort)
	eq(read(vim.fs.joinpath(artifacts, "attempts")), "0")

	local env =
		verdict_env(H.tempdir(child), { INPUTS_GREEN = "false", INPUTS_ATTEMPT = "3", INPUTS_INFRA = out.infra })
	local verdict = loop_script("verdict.py", repo, env)
	eq({ verdict.done, verdict.passed, verdict.exhausted, verdict.infra }, { true, false, false, abort })
	local judge = loop_script("escalation.py", repo, { ARTIFACTS_DIR = H.tempdir(child), INPUTS_INFRA = verdict.infra })
	eq({ judge.decision, judge.escalate }, { "infra", false })
	has(judge.reasons, "- infra: e2e did not run (the sandbox failed twice, not the change): " .. abort)
	local decide = loop_script("decide.py", repo, { INPUTS_VERDICT = judge.decision, INPUTS_DECISION = "auto" })
	eq({ decide.go, decide.cancel, decide.decision }, { false, true, "infra" })

	local timing = { ["test-readiness.out"] = "x", ["test-readiness.code"] = "1" }
	local real =
		rerun_gate(readiness_e2e_log({ abort }), 0, files, { outputs = vim.tbl_extend("force", outputs, timing) })
	eq({ real.green, real.infra }, { false, "" })
	local lost = "sandbox: Lume lost track of nvim-e2e (lume ssh refuses it); restarting nvim-e2e"
	local back = rerun_gate(readiness_e2e_log({ lost }), 0, files)
	eq({ back.green, back.infra, #back.flaky }, { true, "", 2 })
end

T["loop: Gate never passes a case the change owns as flaky"] = function()
	local log = {
		"FAIL test 1.0 s",
		"===== test =====",
		"FAIL in tests/unit/a/test_a.lua | a: flaky case:",
		"check: FAILED: test (1.0 s)",
	}
	local outputs = { ["test.out"] = "tests/unit/a/test_a.lua | a: flaky case: o" }
	local base = { ["tests/unit/a/test_a.lua"] = 'T["a: flaky case"] = function() end' }
	local edited = { ["tests/unit/a/test_a.lua"] = 'T["a: flaky case"] = function() end\n-- edited' }
	local touched, touched_reruns = rerun_gate(log, 0, base, { outputs = outputs, branch = edited })
	eq({ touched.green, touched.flaky, touched_reruns }, { false, {}, "" })

	local change = {
		["openspec/changes/c/proposal.md"] = "# c",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [x] 1.1 a\n  Scenarios: `a: flaky case`",
	}
	local opts = { outputs = outputs, env = { INPUTS_CHANGE = "c" }, tools = { openspec = "exit 0" } }
	local owned, owned_reruns = rerun_gate(log, 0, vim.tbl_extend("force", base, change), opts)
	eq({ owned.green, owned.flaky, owned_reruns }, { false, {}, "" })

	local unmatched = rerun_gate(log, 0, base, { outputs = { ["test.out"] = "No test cases matched" } })
	eq({ unmatched.green, unmatched.flaky }, { false, {} })
	local other = rerun_gate(log, 0, base, { outputs = outputs })
	eq({ other.green, other.flaky }, { true, { "tests/unit/a/test_a.lua | a: flaky case" } })
end

T["loop: Gate reruns an old case in a test file the change edits"] = function()
	local file = "tests/unit/a/test_a.lua"
	local log = {
		"FAIL test 1.0 s",
		"===== test =====",
		"FAIL in " .. file .. " | a: old case:",
		"check: FAILED: test (1.0 s)",
	}
	local base = { [file] = 'T["a: old case"] = function() end\n\nT["a: new case"] = function()\nend' }
	local edited = { [file] = 'T["a: old case"] = function() end\n\nT["a: new case"] = function()\n\tlocal x = 1\nend' }
	local outputs = { ["test.out"] = file .. " | a: old case: o\n" .. file .. " | a: new case: o" }
	local old, old_reruns = rerun_gate(log, 0, base, { outputs = outputs, branch = edited })
	local rerun = "test FILE=" .. file .. " CASE=a: old case"
	eq({ old.green, old.flaky, old_reruns }, { true, { file .. " | a: old case" }, rerun })

	local both = vim.list_extend(vim.list_slice(log, 1, 3), { "FAIL in " .. file .. " | a: new case:", log[4] })
	local mixed, mixed_reruns = rerun_gate(both, 0, base, { outputs = outputs, branch = edited })
	eq({ mixed.green, mixed.flaky, mixed_reruns }, { false, {}, "test FILE=" .. file .. " CASE=a: old case" })
	has(mixed.failures, "passed on rerun (flaky, not this change's): " .. file .. " | a: old case")
end

T["loop: Gate reruns a failed case of a nested set"] = function()
	local file = "tests/unit/a/test_a.lua"
	local log = {
		"FAIL test 1.0 s",
		"===== test =====",
		"FAIL in " .. file .. " | load | a: nested case: Failed expectation",
		"check: FAILED: test (1.0 s)",
	}
	local base = { [file] = 'T["load"] = MiniTest.new_set()\nT["load"]["a: nested case"] = function() end' }
	local passed, reruns = rerun_gate(log, 0, base, { outputs = { ["test.out"] = file .. " | load: o" } })
	eq({ passed.green, reruns }, { true, "test FILE=" .. file .. " CASE=load | a: nested case" })
	local failed = rerun_gate(log, 0, base, { outputs = { ["test.out"] = file .. " | load: x" } })
	eq(failed.green, false)
end

T["loop: Fix prompt never makes an empty commit"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " ")
	has(fix, "or none when nothing needs changing (say so: the gate reruns); never an empty commit")
	has(fix, "never `git commit --allow-empty`")
	has(fix, "or restates a rule of this command: such lessons are dropped")
end

T["loop: Gate flags a test case added then removed during build"] = function()
	local repo = branch_repo({ ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end' })
	write(repo, { ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end\nT["a: new"] = function() end' })
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	local bin = fake_tool(scratch, "make", "exit 0")
	local env = { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH }

	loop_script("verdict.py", repo, verdict_env(artifacts))
	write(repo, { ["tests/unit/a/test_a.lua"] = "-- emptied" })
	local first = loop_script("gate.py", repo, env)
	eq(first.green, false)
	has(first.failures, "hard rule: test added then removed during build: a: new")
	eq(first.failures:find("during build: a: new, a: old", 1, true), nil)
	loop_script(
		"verdict.py",
		repo,
		verdict_env(artifacts, { INPUTS_GREEN = "false", INPUTS_FAILURES = first.failures })
	)
	local second = loop_script("gate.py", repo, env)
	eq(second.failures:find("during build", 1, true), nil, { fail_reason = second.failures })

	write(repo, { ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end' })
	local judge = loop_script("escalation.py", repo, { ARTIFACTS_DIR = artifacts })
	eq(judge.decision, "reject", { fail_reason = judge.reasons })
	has(judge.reasons, "test added then removed during build: a: new")
end

T["loop: Judge ships once a dropped test case is restored"] = function()
	local repo = branch_repo({ ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end' })
	local artifacts = H.tempdir(child)
	write(artifacts, { ["dropped-cases.json"] = '["a: new"]' })
	write(repo, { ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end\nT["a: new"] = function() end' })
	local judge = loop_script("escalation.py", repo, { ARTIFACTS_DIR = artifacts })
	eq(judge.decision, "ship", { fail_reason = judge.reasons })
end

T["loop: Fix feedback keeps a failing case's message"] = function()
	local result = H.system(child, { "python3", "-m", "unittest", "-q", "test_check_log" }, SCRIPTS)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	has(
		read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " "),
		"A failing case this change owns (its own or one it edited) is never dismissed as transient or flaky with no commit"
	)
end

T["loop: Fix prompt probes first and caps attempts"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " ")
	has(fix, "run one headless probe first (the scratch-file probe rule below) that logs the relevant state")
	has(fix, "At most 2 implementation attempts per pass")
	has(fix, "write (or replace) `## Stuck` in tasks.md with the probe output and both attempts")
	has(fix, "never uses timers or sleeps (`vim.defer_fn`, `vim.uv` timers, `vim.wait`) to win a race")
	has(fix, "unless the proposal's `## Decision` allows it")
	has(
		fix,
		"A `## Decision` in proposal.md overrides any review finding it covers, also one carried over from an earlier review"
	)
end

T["loop: An auditor Decision runs the spec step"] = function()
	local spec = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	has(
		spec,
		"An auditor `## Decision` in proposal.md is part of that contract and is applied here, in an existing folder too"
	)
	local result = H.system(
		child,
		{ "python3", "-m", "unittest", "-q", "test_spec_ready" },
		vim.fs.joinpath(H.root, ".archon/scripts")
	)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	has(
		read(vim.fs.joinpath(H.root, ".archon/scripts/spec_ready.py")),
		'AUDITOR = re.compile(r"^## Decision \\(auditor\\b"'
	)
end

T["loop: Gate reruns a case a hung worker left unrun"] = function()
	local result = H.system(child, { "python3", "-m", "unittest", "-q", "test_case_name" }, SCRIPTS)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

T["loop: An unfinished spec pass reruns the spec step"] = function()
	local spec = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	has(spec, 'Last, after everything else: `rm -f "$ARTIFACTS_DIR/spec-pending"`')
	local queue = read(vim.fs.joinpath(H.root, ".archon/workflows/work-queue/work-queue.yaml"))
	for _, node in ipairs({ "complete", "spec-retry" }) do
		local body = queue:match("\n  %- id: " .. node:gsub("%-", "%%-") .. " .-\n  %- id:")
		has(body, "idle_timeout: 900000")
	end
	local result = H.system(
		child,
		{ "python3", "-m", "unittest", "-q", "test_spec_ready" },
		vim.fs.joinpath(H.root, ".archon/scripts")
	)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

T["loop: Each task's context pack merges a moved auto first"] = function()
	local deliver = read(vim.fs.joinpath(H.root, ".archon/workflows/nvim-deliver/nvim-deliver.yaml"))
	has(deliver, 'sync_base: "true" # sync_base.py: an auditor Decision on auto reaches the next task')
	local pack = read(vim.fs.joinpath(H.root, ".archon/scripts/context_pack.py"))
	eq(
		pack:find("INPUTS_SYNC_BASE", 1, true)
			< pack:find('change_dir = pathlib.Path("openspec/changes") / CHANGE', 1, true),
		true
	)
end

T["loop: Gate merges a moved auto first"] = function()
	local deliver = read(vim.fs.joinpath(H.root, ".archon/workflows/nvim-deliver/nvim-deliver.yaml"))
	has(deliver, 'sync_base: "true" # sync_base.py')
	local gate = read(vim.fs.joinpath(H.root, ".archon/scripts/gate.py"))
	has(gate, 'if os.environ.get("INPUTS_SYNC_BASE") == "true":')
	eq(gate:find("INPUTS_SYNC_BASE", 1, true) < gate:find("blocked = blocked_text(change)", 1, true), true)
	local result = H.system(
		child,
		{ "python3", "-m", "unittest", "-q", "test_sync_base" },
		vim.fs.joinpath(H.root, ".archon/scripts")
	)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

T["loop: Review flags a test reading a change folder"] = function()
	local review = read(vim.fs.joinpath(H.root, ".archon/commands/review.md")):gsub("%s+", " ")
	has(review, "a test that reads a file under `openspec/changes/` at runtime breaks when the change is archived")
end

T["loop: A new look is checked against its approved render"] = function()
	local implement = read(vim.fs.joinpath(H.root, ".archon/commands/implement.md")):gsub("%s+", " ")
	has(implement, "a screenshot the test run created itself is never the reference for a new look")
	local review = read(vim.fs.joinpath(H.root, ".archon/commands/review.md")):gsub("%s+", " ")
	has(review, "a new screen case with a screenshot but no colour mask from the approved render is untested")
	has(review, "a tasks.md rewrite that drops a `make types`/`make check`/`make colorize` step is weakened")
end

T["loop: Review treats a narrowed screen check as weakened"] = function()
	local review = read(vim.fs.joinpath(H.root, ".archon/commands/review.md")):gsub("%s+", " ")
	has(
		review,
		"a screen case that checks fewer mask rows or swaps a screenshot comparison for text checks is weakened"
	)
end

T["loop: Fix resolves a trace duplicate"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " ")
	has(
		fix,
		"A trace DUPLICATE (one case name in two test files) is yours to resolve even when an earlier pass made it"
	)
	has(fix, "never record it as inherited")
end

T["loop: A stuck fix pass fixes the other gate failures too"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " ")
	has(
		fix,
		"it is your first finding, not your only one (fix every other `FAIL in` line of the gate log in the same pass"
	)
end

T["loop: Implement and fix probe UI edge cells"] = function()
	for _, name in ipairs({ "fix.md", "implement.md" }) do
		local prompt = read(vim.fs.joinpath(H.root, ".archon/commands", name)):gsub("%s+", " ")
		has(
			prompt,
			"an empty result (also empty after a filter or toggle), a multibyte line, `VimResized` across the layout breakpoint"
		)
		has(prompt, "torn down on `WinClosed`")
	end
end

T["loop: The task loop ends when only gates wait on a stuck task"] = function()
	local result = H.system(child, { "python3", "-m", "unittest", "-q", "test_stuck_tasks" }, SCRIPTS)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

T["loop: Stuck attempts keep the red test"] = function()
	for _, name in ipairs({ "fix.md", "implement.md" }) do
		local prompt = read(vim.fs.joinpath(H.root, ".archon/commands", name)):gsub("%s+", " ")
		has(prompt, "run one headless probe first (the scratch-file probe rule below) that logs the relevant state")
		has(prompt, "At most 2 implementation attempts per")
		has(prompt, "revert only the non-test edits (`lua/` and other code; keep the new red")
		has(prompt, "git add -N -- . ':!tests' && git diff -- . ':!tests' > $ARTIFACTS_DIR/stuck-attempt-<task>.diff")
		has(prompt, "commit the failing test together with tasks.md")
		has(prompt, "`## Stuck` in tasks.md with the probe output and both attempts")
		eq(prompt:find("revert the uncommitted edits", 1, true), nil)
	end
	has(
		read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")),
		"when `$ARTIFACTS_DIR/stuck-attempt-<task>.diff` for that task (or a `stuck-attempt.diff` its `## Stuck` names) exists, first `git apply` it"
	)
end

T["loop: Test run records the cases it collected"] = function()
	local root = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(root, {
		["probe/test_probe.lua"] = 'local T = require("mini.test").new_set()\nT["seen: probe"] = function() end\nreturn T',
	})
	write(artifacts, { ["case-seen.json"] = '[{"file":"tests/unit/a/test_a.lua","case":"a: earlier"}]' })
	vim.uv.fs_symlink(vim.fs.joinpath(H.root, "tests"), vim.fs.joinpath(root, "tests"))
	local env = {
		ARTIFACTS_DIR = artifacts,
		FILE = "probe/test_probe.lua",
		JOBS = "1",
		TEST_DEPS_DIR = vim.fs.joinpath(H.root, ".tests/deps"),
	}
	local cmd = { vim.v.progpath, "-u", "tests/minimal_init.lua", "-l", "tests/parallel.lua" }
	local result = H.system(child, cmd, root, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(vim.json.decode(read(vim.fs.joinpath(artifacts, "case-seen.json"))), {
		{ file = "tests/unit/a/test_a.lua", case = "a: earlier" },
		{ file = "probe/test_probe.lua", case = "seen: probe" },
	})
end

T["loop: Gate flags a test case added and removed within one pass"] = function()
	local repo = branch_repo({
		["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end\nT[scenario]["kept by variable"] = function() end',
		["tests/unit/b/test_b.lua"] = "for _, language in ipairs(languages) do\n\tT[s][language.name] = function() end\nend",
	})
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	local bin = fake_tool(scratch, "make", "exit 0")
	local env = { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH }
	loop_script("verdict.py", repo, verdict_env(artifacts))
	local seen = '[{"file":"tests/unit/a/test_a.lua","case":"a: old"},{"file":"tests/unit/a/test_a.lua","case":"a: tmp"},'
		.. '{"file":"tests/unit/a/test_a.lua","case":"kept by variable"},{"file":"/tmp/fixture/test_stall.lua","case":"hang: ok first"},'
		.. '{"file":"tests/unit/b/test_b.lua","case":"go"}]'
	write(artifacts, { ["case-seen.json"] = seen })

	local first = loop_script("gate.py", repo, env)
	eq(first.green, false)
	has(first.failures, "hard rule: test added then removed during build: a: tmp")
	eq(first.failures:find("a: old", 1, true), nil, { fail_reason = first.failures })
	-- a variable-keyed case its file still names, and a fixture runner's case outside tests/, are not dropped
	eq(first.failures:find("kept by variable", 1, true), nil, { fail_reason = first.failures })
	eq(first.failures:find("hang: ok first", 1, true), nil, { fail_reason = first.failures })
	-- a case named from data (`T[s][language.name]`) cannot be checked against the source: never flagged
	eq(
		first.failures:find(": go", 1, true) or first.failures:find(", go", 1, true),
		nil,
		{ fail_reason = first.failures }
	)
	loop_script(
		"verdict.py",
		repo,
		verdict_env(artifacts, { INPUTS_GREEN = "false", INPUTS_FAILURES = first.failures })
	)
	eq(vim.fn.filereadable(vim.fs.joinpath(artifacts, "case-seen.json")), 0)
	local second = loop_script("gate.py", repo, env)
	eq(second.failures:find("during build", 1, true), nil, { fail_reason = second.failures })
end

T["loop: Gate reports a Blocked change before make check"] = function()
	local repo = branch_repo({
		["openspec/changes/c/proposal.md"] = "# c",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [ ] 1.1 a\n\n## Blocked\n\n- pick (A) or (B)",
	})
	local scratch = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local bin = fake_tool(scratch, "make", ('touch "%s/make-ran"'):format(scratch))
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "c", PATH = bin .. ":" .. vim.env.PATH }

	local gate = loop_script("gate.py", repo, env)
	eq(
		{ gate.green, gate.blocked, vim.fn.filereadable(vim.fs.joinpath(scratch, "make-ran")) },
		{ false, true, 0 },
		{ fail_reason = gate.failures }
	)
	has(gate.failures, "blocked: tasks.md: ## Blocked")
	has(gate.failures, "pick (A) or (B)")
	eq({ gate.attempt, loop_script("gate.py", repo, env).attempt }, { 1, 1 }) -- a blocked pass is no attempt
	local workflow = read(vim.fs.joinpath(H.root, ".archon/workflows/nvim-deliver/nvim-deliver.yaml"))
	has(workflow, 'when: "$gate.output.blocked == false && $gate.output.green == true')
end

---@param proposal string
---@return string context.md of a change whose proposal.md is `proposal`
local function pack_context(proposal)
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n- lesson\n\n## The loop\n",
		["openspec/changes/c/proposal.md"] = proposal,
		["openspec/changes/c/tasks.md"] = "## 1. Todo\n- [ ] 1.1 a",
	})
	local env = { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "context_pack.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return read(vim.fs.joinpath(artifacts, "context.md"))
end

T["loop: Context pack carries the proposal's evidence"] = function()
	local refs = "- neo-tree sources/filesystem/init.lua:198: debounced navigate"
	local context = pack_context("## Why\n\nrace\n\n## Evidence\n\n" .. refs .. "\n\n## Impact\n\n- x\n")
	local evidence, lessons = context:find("## Evidence\n\n" .. refs, 1, true), context:find("## Loop lessons", 1, true)
	eq(evidence ~= nil and evidence < lessons, true, { fail_reason = context })
	eq(pack_context("## Why\n\nrace\n"):find("## Evidence", 1, true), nil)
end

T["loop: Spec prompts require root-cause evidence"] = function()
	for _, name in ipairs({ "queue-spec.md", "spec-bug.md" }) do
		local prompt = read(vim.fs.joinpath(H.root, ".archon/commands", name)):gsub("%s+", " ")
		has(prompt, "an `## Evidence` section")
		has(prompt, "`file:line` refs (repo or installed plugin source) or")
	end
	local implement = read(vim.fs.joinpath(H.root, ".archon/commands/implement.md")):gsub("%s+", " ")
	has(implement, "do not re-read plugin source the Evidence already covers")
end

T["loop: Judge notes minor review findings on ship"] = function()
	local repo = branch_repo({ ["README.md"] = "x" })
	local artifacts = H.tempdir(child)
	local findings = table.concat({
		"No blocking findings.",
		"1. [minor] lua/gleb/keymaps.lua:90 reads a private neo-tree field.",
		"Minor (non-blocking):",
		"2. Rule 4.3: magic number at lua/gleb/keymaps.lua:91.",
	}, "\n")
	local verdict = loop_script("verdict.py", repo, verdict_env(artifacts, { INPUTS_REVIEW_FINDINGS = findings }))
	eq(verdict.passed, true, { fail_reason = verdict.feedback })
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_REVIEW_FINDINGS = verdict.review_findings }
	local judge = loop_script("escalation.py", repo, env)
	eq(judge.decision, "ship", { fail_reason = judge.reasons })
	local escalation = read(vim.fs.joinpath(artifacts, "escalation.md"))
	has(escalation, "- note: review (minor): 1. [minor] lua/gleb/keymaps.lua:90 reads a private neo-tree field.")
	has(escalation, "- note: review (minor): 2. Rule 4.3: magic number at lua/gleb/keymaps.lua:91.")
	eq(escalation:find("No blocking findings", 1, true), nil)
end

T["loop: Verdict sends only blocking review findings to fix"] = function()
	local repo = branch_repo({ ["README.md"] = "x" })
	local artifacts = H.tempdir(child)
	local findings = table.concat({
		"1. [must-fix] lua/gleb/a.lua:3 drops the selection.",
		"2. [minor] lua/gleb/a.lua:9 magic number,",
		"   also at line 12.",
		"Minor (non-blocking):",
		"3. naming nit in tests/unit/a/test_a.lua.",
		"4. [must-fix] lua/gleb/a.lua:20 leaks the autocmd.",
	}, "\n")
	local env = verdict_env(artifacts, { INPUTS_APPROVE = "false", INPUTS_REVIEW_FINDINGS = findings })
	local rejected = loop_script("verdict.py", repo, env)
	has(rejected.feedback, "review: 1. [must-fix] lua/gleb/a.lua:3 drops the selection.")
	has(rejected.feedback, "4. [must-fix] lua/gleb/a.lua:20 leaks the autocmd.")
	local leaked = vim.tbl_map(function(minor)
		return rejected.feedback:find(minor, 1, true) ~= nil
	end, { "magic number", "also at line 12", "naming nit" })
	eq(leaked, { false, false, false }, { fail_reason = rejected.feedback })
	eq(rejected.review_findings, findings)
	local skipped = loop_script("verdict.py", repo, verdict_env(artifacts, { INPUTS_GREEN = "false" }))
	eq(skipped.failed_gates, "tests")
end

T["loop: Exhausted judge quotes the last failures"] = function()
	local repo = branch_repo({
		["README.md"] = "x",
		["openspec/changes/c/tasks.md"] = "## 1. T\n- [ ] 1.1 x\n\n## Stuck\n- Probe: stuck probe text",
	})
	local failures = "make check is red:\nFAIL trace\n  actions: Invented name  (tests/unit/a/test_a.lua)"
	local artifacts = H.tempdir(child)
	write(artifacts, { reviews = "3" }) -- three reviewed passes before: a red pass burns no attempt itself
	local red = verdict_env(artifacts, {
		INPUTS_CHANGE = "c",
		INPUTS_GREEN = "false",
		INPUTS_ATTEMPT = "3",
		INPUTS_FAILURES = failures,
		INPUTS_APPROVE = "false",
		INPUTS_REVIEW_FINDINGS = "1. [must-fix] review text",
	})
	local verdict = loop_script("verdict.py", repo, red)
	eq(verdict.exhausted, true)
	local env = { ARTIFACTS_DIR = H.tempdir(child), INPUTS_CHANGE = "c", INPUTS_EXHAUSTED = "true" }
	env =
		vim.tbl_extend("force", env, { INPUTS_FAILED_GATES = verdict.failed_gates, INPUTS_FAILURES = verdict.failures })
	local judge = loop_script("escalation.py", repo, env)
	eq(judge.decision, "reject")
	has(judge.reasons, "- last failures:\n  make check is red:\n  FAIL trace\n    actions: Invented name")
	eq({ judge.reasons:find("stuck probe text", 1, true), judge.reasons:find("review text", 1, true) }, { nil, nil })
	local workflow = read(vim.fs.joinpath(H.root, ".archon/workflows/nvim-deliver/nvim-deliver.yaml"))
	has(workflow, "failures: $build.output.failures")
end

T["loop: Gate returns dropped cases to fix with the remedy"] = function()
	local repo = branch_repo({ ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end' })
	write(repo, { ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end\nT["a: new"] = function() end' })
	local artifacts = H.tempdir(child)
	local bin = fake_tool(H.tempdir(child), "make", "exit 0")
	local env = { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH }
	loop_script("verdict.py", repo, verdict_env(artifacts))
	write(repo, { ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end' })
	local gate = loop_script("gate.py", repo, env)
	has(gate.failures, "during build: a: new (restore these cases under their names, or add a same-titled scenario")
	local red = verdict_env(artifacts, { INPUTS_GREEN = "false", INPUTS_FAILURES = gate.failures })
	local verdict = loop_script("verdict.py", repo, red)
	eq({ verdict.done, verdict.failed_gates }, { false, "tests,rules" }, { fail_reason = verdict.feedback })
	has(verdict.feedback, "restore these cases under their names")
	local judge = loop_script("escalation.py", repo, { ARTIFACTS_DIR = artifacts })
	eq(judge.decision ~= "ship", true, { fail_reason = judge.reasons })
end

T["loop: Fix prompt names regression tests after scenarios"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " ")
	has(fix, "Name each new regression test `<capability>: <scenario title>`")
	has(
		fix,
		"add a same-titled scenario (ADDED, or MODIFIED restating a main-spec one) to openspec/changes/$INPUTS.change/specs"
	)
	has(fix, "never invent a case name the specs lack, and never fold or rename a case an earlier pass added")
	has(fix, "A regression test replays the finding's exact trigger through the real entry point")
	has(fix, "A fix holds on every update path of what it patches")
end

T["loop: Implement tests mode-dependent behaviour in the mode"] = function()
	local implement = read(vim.fs.joinpath(H.root, ".archon/commands/implement.md")):gsub("%s+", " ")
	has(implement, "Mode-dependent behaviour (Visual, Insert, operator-pending)")
	has(implement, "through the real mapping with the mode still active")
	has(implement, "never after `<Esc>`")
	has(
		implement,
		"Every test drives the real entry point (the real mapping or `<CR>`, the real picker, populated data)"
	)
	local queue_spec = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	has(queue_spec, "Each test task names the real entry point it drives")
end

return T
