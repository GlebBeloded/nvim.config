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

---@param repo string
---@param artifacts string
---@param candidate string
---@return test.SystemResult
local function record(repo, artifacts, candidate)
	write(artifacts, "lesson-candidates.txt", candidate)
	return run_verdict(repo, artifacts)
end

---@param args string[]
---@param cwd string
local function git_ok(args, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, args), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

---@param repo string
---@param artifacts string
---@return test.SystemResult
local function run_escalation(repo, artifacts)
	local env = vim.tbl_extend("force", H.GIT_ENV, {
		ARTIFACTS_DIR = artifacts,
		BASE_BRANCH = "auto",
		INPUTS_EXHAUSTED = "true",
		INPUTS_FAILED_GATES = "tests",
	})
	return H.system(child, { "python3", ESCALATION }, repo, env)
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
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local lesson = "Under host load, scale startup budgets before diagnosing a regression"
	write(repo, "docs/workflow.md", workflow({ "Existing lesson" }))

	local result = record(repo, artifacts, lesson)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(vim.json.decode(result.stdout).passed, true)
	eq(read(vim.fs.joinpath(repo, "docs/workflow.md")), workflow({ "Existing lesson", lesson }))
end

T["loop: Repeated lessons stay deduplicated and bounded"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local original = workflow({ "Existing lesson", "Older lesson" })
	write(repo, "docs/workflow.md", original)
	local candidates = {}
	for i = 1, 10 do
		table.insert(candidates, "New lesson " .. i)
	end
	table.insert(candidates, "  existing   LESSON  ")

	local result = record(repo, artifacts, table.concat(candidates, "\n"))
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local expected = {}
	for i = 2, 10 do
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
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local lesson = "Wait for asynchronous commits before asserting repository state"
	write(repo, "docs/workflow.md", workflow({ "Existing lesson" }))
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "initial" }, repo)
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

return T
