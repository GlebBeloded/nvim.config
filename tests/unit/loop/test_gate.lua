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
	env = vim.tbl_extend("force", env, { INPUTS_CRITICAL = "0", INPUTS_APPROVE = "true", INPUTS_ATTEMPT = "1" })
	return vim.tbl_extend("force", env, extra or {})
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
	local body = 'if [ "$1" = test ]; then echo "$2 $3" >>"%s/reruns"; exit %d; fi\ncat "%s/check.log"\nexit 1'
	return fake_tool(scratch, "make", body:format(scratch, rerun_code, scratch))
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

--- make stub: `make check` prints `log`; any other target appends its arguments to `<scratch>/reruns`
--- and exits `rerun_code`.
---@param scratch string
---@param log string[]
---@param rerun_code integer
---@return string bin
local function rerun_make(scratch, log, rerun_code)
	write(scratch, { ["check.log"] = table.concat(log, "\n") })
	local body = 'if [ "$1" != check ]; then echo "$*" >>"%s/reruns"; exit %d; fi\ncat "%s/check.log"\nexit 1'
	return fake_tool(scratch, "make", body:format(scratch, rerun_code, scratch))
end

--- gate.py on a check printing `log`, its reruns exiting `rerun_code`.
---@param log string[]
---@param rerun_code integer
---@return table verdict, string reruns, string check_log
local function rerun_gate(log, rerun_code, files)
	local repo = branch_repo(vim.tbl_extend("force", { ["README.md"] = "x" }, files or {}))
	local scratch, artifacts = H.tempdir(child), H.tempdir(child)
	local env = { ARTIFACTS_DIR = artifacts, PATH = rerun_make(scratch, log, rerun_code) .. ":" .. vim.env.PATH }
	local out = loop_script("gate.py", repo, env)
	local reruns = vim.fs.joinpath(scratch, "reruns")
	return out, vim.fn.filereadable(reruns) == 1 and read(reruns) or "", read(vim.fs.joinpath(artifacts, "check-1.log"))
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
	eq(judge.decision, "ask", { fail_reason = judge.reasons })
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

T["loop: Fix prompt probes first and caps attempts"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md")):gsub("%s+", " ")
	has(fix, "run one headless probe first (the scratch-file probe rule below) that logs the relevant state")
	has(fix, "At most 2 implementation attempts per pass")
	has(fix, "write `## Blocked` in tasks.md with the probe output and both attempts")
	has(fix, "never uses timers or sleeps (`vim.defer_fn`, `vim.uv` timers, `vim.wait`) to win a race")
	has(fix, "unless the proposal's `## Decision` allows it")
end

T["loop: Blocked attempts keep the red test"] = function()
	for _, name in ipairs({ "fix.md", "implement.md" }) do
		local prompt = read(vim.fs.joinpath(H.root, ".archon/commands", name)):gsub("%s+", " ")
		has(prompt, "run one headless probe first (the scratch-file probe rule below) that logs the relevant state")
		has(prompt, "At most 2 implementation attempts per")
		has(prompt, "revert only the non-test edits (`lua/` and other code; keep the new red")
		has(prompt, "commit the failing test together with tasks.md (a blocked change never ships)")
		eq(prompt:find("revert the uncommitted edits", 1, true), nil)
	end
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
	local repo = branch_repo({ ["tests/unit/a/test_a.lua"] = 'T["a: old"] = function() end' })
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	local bin = fake_tool(scratch, "make", "exit 0")
	local env = { ARTIFACTS_DIR = artifacts, PATH = bin .. ":" .. vim.env.PATH }
	loop_script("verdict.py", repo, verdict_env(artifacts))
	local seen =
		'[{"file":"tests/unit/a/test_a.lua","case":"a: old"},{"file":"tests/unit/a/test_a.lua","case":"a: tmp"}]'
	write(artifacts, { ["case-seen.json"] = seen })

	local first = loop_script("gate.py", repo, env)
	eq(first.green, false)
	has(first.failures, "hard rule: test added then removed during build: a: tmp")
	eq(first.failures:find("a: old", 1, true), nil, { fail_reason = first.failures })
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

return T
