local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local VERDICT = vim.fs.joinpath(H.root, ".archon/scripts/verdict.py")
local ESCALATION = vim.fs.joinpath(H.root, ".archon/scripts/escalation.py")

---@param path string
---@return string
local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

---@param root string
---@param path string
---@param content string
local function write(root, path, content)
	local target = vim.fs.joinpath(root, path)
	vim.fn.mkdir(vim.fs.dirname(target), "p")
	vim.fn.writefile(vim.split(content, "\n", { plain = true }), target)
end

---@param bullets string[]
---@return string
local function workflow(bullets)
	local lines = { "before", "", "## Loop lessons", "" }
	for _, lesson in ipairs(bullets) do
		table.insert(lines, "- " .. lesson)
	end
	vim.list_extend(lines, { "", "## After", "", "after" })
	return table.concat(lines, "\n")
end

---@param repo string
---@param artifacts string
---@return test.SystemResult
local function run_verdict(repo, artifacts)
	local env = vim.tbl_extend("force", H.GIT_ENV, {
		ARTIFACTS_DIR = artifacts,
		INPUTS_GREEN = "true",
		INPUTS_SPEC_OK = "true",
		INPUTS_TASKS_DONE = "true",
		INPUTS_CRITICAL = "0",
		INPUTS_APPROVE = "true",
		INPUTS_ATTEMPT = "2",
	})
	return H.system(child, { "python3", VERDICT }, repo, env)
end

---@param args string[]
---@param cwd string
local function git_ok(args, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, args), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

--- Throwaway checkout on `auto` with `docs/workflow.md` committed, as the judge diffs against `auto`.
---@param text string
---@return string repo
local function lessons_repo(text)
	local repo = H.tempdir(child)
	write(repo, "docs/workflow.md", text)
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "initial" }, repo)
	return repo
end

---@param repo string
---@param artifacts string
---@param exhausted? boolean
---@return test.SystemResult
local function run_escalation(repo, artifacts, exhausted)
	local env = vim.tbl_extend("force", H.GIT_ENV, {
		ARTIFACTS_DIR = artifacts,
		BASE_BRANCH = "auto",
		INPUTS_EXHAUSTED = exhausted == false and "false" or "true",
		INPUTS_FAILED_GATES = exhausted == false and "" or "tests",
	})
	return H.system(child, { "python3", ESCALATION }, repo, env)
end

--- A passing verdict, then the judge, which is where lessons are persisted.
---@param repo string
---@param artifacts string
---@param candidate string
---@return test.SystemResult judge
local function record(repo, artifacts, candidate)
	write(artifacts, "lesson-candidates.txt", candidate)
	local before = read(vim.fs.joinpath(repo, "docs/workflow.md"))
	local verdict = run_verdict(repo, artifacts)
	eq(verdict.code, 0, { fail_reason = verdict.stdout .. verdict.stderr })
	eq(vim.json.decode(verdict.stdout).passed, true)
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), before)
	return run_escalation(repo, artifacts, false)
end

---@param text string
---@param needle string
---@return integer
local function position(text, needle)
	local start = text:find(needle, 1, true)
	eq(start ~= nil, true, { fail_reason = ("missing %q"):format(needle) })
	return start --[[@as integer]]
end

---@param prompt string
---@param task_context string
local function expect_lesson_order(prompt, task_context)
	local skills = position(prompt, "naming it.")
	local lessons = position(prompt, "## Loop lessons")
	local context = position(prompt, task_context)
	eq(skills < lessons and lessons < context, true)
end

T["loop: Fix and implement prompts read loop lessons"] = function()
	local workflow_text = read("docs/workflow.md")
	local explore = read(".archon/commands/explore-bug.md")
	local implement = read(".archon/commands/implement.md")

	position(workflow_text, "## Loop lessons")
	expect_lesson_order(explore, "Bug: $ARGUMENTS")
	expect_lesson_order(implement, "Change: openspec/changes/$INPUTS.change/")
	position(implement, "$ARTIFACTS_DIR/lesson-candidates.txt")
	position(implement, "failure from the previous pass")
	position(implement, "directly verified")
end

T["loop: Passing retry records its corrected failure"] = function()
	local repo = lessons_repo(workflow({ "Existing lesson" }))
	local artifacts = H.tempdir(child)
	local lesson = "Under host load, scale startup budgets before diagnosing a regression"

	local result = record(repo, artifacts, lesson)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(vim.json.decode(result.stdout).decision, "ship")
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow({ "Existing lesson", lesson }))
end

T["loop: Repeated lessons stay deduplicated and bounded"] = function()
	local repo = lessons_repo(workflow({ "Existing lesson", "Older lesson" }))
	local artifacts = H.tempdir(child)
	local candidates = {}
	for i = 1, 15 do
		table.insert(candidates, "New lesson " .. i)
	end
	table.insert(candidates, "  existing   LESSON  ")

	local result = record(repo, artifacts, table.concat(candidates, "\n"))
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local expected = {}
	for i = 2, 15 do
		table.insert(expected, "New lesson " .. i)
	end
	table.insert(expected, "existing LESSON")
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow(expected))

	for _, malformed in ipairs({ "before\n\n## After\n\nafter", "before\n\n## Loop lessons\n\n- no boundary" }) do
		write(repo, "docs/workflow.md", malformed)
		result = record(repo, artifacts, "Another lesson")
		eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
		eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), malformed)
	end
end

T["loop: Unfixed failures do not become lessons"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local original = workflow({ "Existing lesson" })
	write(repo, "docs/workflow.md", original)

	local result = run_verdict(repo, artifacts)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), original)
end

T["loop: Exhausted run retains a corrected earlier failure"] = function()
	local repo = lessons_repo(workflow({ "Existing lesson" }))
	local artifacts = H.tempdir(child)
	local lesson = "Wait for asynchronous commits before asserting repository state"
	write(artifacts, "lesson-candidates.txt", lesson)

	for _ = 1, 2 do
		local result = run_escalation(repo, artifacts)
		eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
		local expected_reason = "- fix loop exhausted (3 attempts) with gates still red: tests"
		eq(vim.json.decode(result.stdout), { decision = "reject", escalate = false, reasons = expected_reason })
		eq(read(vim.fs.joinpath(artifacts, "escalation.md")), "# Judge: reject\n\n" .. expected_reason)
		eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow({ "Existing lesson", lesson }))
	end
end

T["loop: Build passes leave workflow docs unchanged"] = function()
	local repo = lessons_repo(workflow({ "Existing lesson" }))
	local artifacts = H.tempdir(child)
	write(artifacts, "lesson-candidates.txt", "A lesson from this pass")

	local result = run_verdict(repo, artifacts)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow({ "Existing lesson" }))
	local status = H.system(child, { "git", "status", "--porcelain" }, repo, H.GIT_ENV)
	eq(status.stdout, "")
end

T["loop: Persisted lesson candidates are cleared"] = function()
	local repo = lessons_repo(workflow({ "Existing lesson" }))
	local artifacts = H.tempdir(child)
	local lesson = "Clear persisted candidates so they never merge twice"
	write(artifacts, "lesson-candidates.txt", lesson)

	local result = run_escalation(repo, artifacts, false)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read(vim.fs.joinpath(artifacts, "lesson-candidates.txt")), "")
	write(repo, "docs/workflow.md", workflow({ "Existing lesson" }))
	result = run_escalation(repo, artifacts, false)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow({ "Existing lesson" }))
end

T["loop: Near-duplicate and loop tooling lessons are not kept"] = function()
	local old = "Keep requirement prose under 500 characters before the trial archive validation"
	local repo = lessons_repo(workflow({ old, "Other lesson" }))
	local near = "Keep the requirement prose under 500 characters before trial archive validation runs."
	local candidates = { near, "loop: integrity flags a test file whose cases all moved", "LOOP: gate false positive" }

	local result = record(repo, H.tempdir(child), table.concat(candidates, "\n"))
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow({ "Other lesson", near }))
end

T["loop: Lessons of a pass the review rejected are not kept"] = function()
	local repo = lessons_repo(workflow({ "Existing lesson" }))
	local artifacts = H.tempdir(child)
	local candidates = vim.fs.joinpath(artifacts, "lesson-candidates.txt")
	write(artifacts, "lesson-candidates.txt", "Earlier verified lesson")
	eq(run_verdict(repo, artifacts).code, 0)
	vim.fn.writefile({ "Lesson of the overturned pass" }, candidates, "a")
	local env = vim.tbl_extend("force", H.GIT_ENV, { ARTIFACTS_DIR = artifacts, INPUTS_GREEN = "true" })
	env = vim.tbl_extend("force", env, { INPUTS_SPEC_OK = "true", INPUTS_CRITICAL = "0", INPUTS_APPROVE = "false" })
	local rejected = H.system(child, { "python3", VERDICT }, repo, env)
	eq(rejected.code, 0, { fail_reason = rejected.stderr })
	eq(read(candidates), "Earlier verified lesson")
	vim.fn.writefile({ "Lesson of the approved pass" }, candidates, "a")

	local result = record(repo, artifacts, read(candidates))
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local lessons = { "Existing lesson", "Earlier verified lesson", "Lesson of the approved pass" }
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow(lessons))
end

return T
