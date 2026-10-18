local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local ESCALATION = vim.fs.joinpath(H.root, ".archon/scripts/escalation.py")

---@param cmd string[]
---@param cwd string
local function git_ok(cmd, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, cmd), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = table.concat(cmd, " ") .. "\n" .. result.stderr })
end

---@param root string
---@param files table<string, string|false> false deletes the file
local function write(root, files)
	for path, content in pairs(files) do
		local target = vim.fs.joinpath(root, path)
		if content == false then
			vim.fn.delete(target)
		else
			vim.fn.mkdir(vim.fs.dirname(target), "p")
			vim.fn.writefile(vim.split(content, "\n", { plain = true }), target)
		end
	end
end

--- Main spec of `capability` with one requirement holding `titles` as scenarios.
---@param capability string
---@param titles string[]
---@return string
local function spec(capability, titles)
	local out = { "# " .. capability, "", "## Requirements", "", "### Requirement: Fixture coverage", "" }
	for _, title in ipairs(titles) do
		vim.list_extend(out, { "#### Scenario: " .. title, "- **WHEN** the fixture runs", "- **THEN** it passes", "" })
	end
	return table.concat(out, "\n")
end

--- Test file with one case per name; `group` nests them in a set.
---@param names string[]
---@param group? string
---@return string
local function cases(names, group)
	local out = { "local T = {}" }
	if group then
		table.insert(out, ('T["%s"] = MiniTest.new_set()'):format(group))
	end
	for _, name in ipairs(names) do
		table.insert(
			out,
			(group and 'T["%s"]["%s"] = function() end' or 'T["%s"] = function() end'):format(group or name, name)
		)
	end
	return table.concat(out, "\n") .. "\nreturn T\n"
end

--- Runs the judge on branch `run` holding `after` (uncommitted) over an `auto` commit of `before`.
---@param before table<string, string>
---@param after table<string, string|false>
---@return { decision: string, reasons: string }
local function judge(before, after)
	local repo = H.tempdir(child)
	write(repo, before)
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "initial" }, repo)
	git_ok({ "checkout", "-q", "-b", "run" }, repo)
	write(repo, after)
	local env = vim.tbl_extend("force", H.GIT_ENV, { ARTIFACTS_DIR = H.tempdir(child), BASE_BRANCH = "auto" })
	local result = H.system(child, { "python3", ESCALATION }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout)
end

---@param text string
---@param part string
---@return boolean
local function has(text, part)
	return text:find(part, 1, true) ~= nil
end

local C_SPEC, C_TEST = "openspec/specs/c/spec.md", "tests/unit/c/test_c.lua"

T["loop: Judge ships a tested scenario rename"] = function()
	local base = { [C_SPEC] = spec("c", { "old title", "kept" }), [C_TEST] = cases({ "c: old title", "c: kept" }) }
	local renamed =
		judge(base, { [C_SPEC] = spec("c", { "new title", "kept" }), [C_TEST] = cases({ "c: new title", "c: kept" }) })
	eq(renamed.decision, "ship", { fail_reason = renamed.reasons })
	local reordered = judge(base, { [C_SPEC] = spec("c", { "kept", "old title" }) })
	eq(reordered.decision, "ship", { fail_reason = reordered.reasons })
	local delta = table.concat({
		"## RENAMED Requirements",
		"- FROM: `### Requirement: Fixture coverage`",
		"- TO: `### Requirement: Fixture cases`",
	}, "\n")
	local requirement = judge(base, {
		[C_SPEC] = spec("c", { "old title", "kept" }):gsub("Fixture coverage", "Fixture cases"),
		["openspec/changes/x/specs/c/spec.md"] = delta,
	})
	eq(requirement.decision, "ship", { fail_reason = requirement.reasons })
end

T["loop: Judge ships a renamed capability"] = function()
	local result = judge(
		{ ["openspec/specs/a/spec.md"] = spec("a", { "one", "two" }), [C_TEST] = cases({ "a: one", "a: two" }) },
		{
			["openspec/specs/a/spec.md"] = false,
			["openspec/specs/b/spec.md"] = spec("a", { "one", "two" }),
			[C_TEST] = cases({ "b: one", "b: two" }),
		}
	)
	eq(result.decision, "ship", { fail_reason = result.reasons })
end

T["loop: Judge notes a scenario removal a rename does not cover"] = function()
	local base = { [C_SPEC] = spec("c", { "old title", "kept" }), [C_TEST] = cases({ "c: old title", "c: kept" }) }
	local removed = judge(base, { [C_SPEC] = spec("c", { "kept" }) })
	eq({
		removed.decision,
		has(removed.reasons, "note: breaking: removes behaviour") and has(removed.reasons, "c: old title"),
	}, { "ship", true })
	local kept_test = judge(base, {
		[C_SPEC] = spec("c", { "new title", "kept" }),
		[C_TEST] = cases({ "c: old title", "c: new title", "c: kept" }),
	})
	eq({
		kept_test.decision,
		has(kept_test.reasons, "note: breaking: removes behaviour") and has(kept_test.reasons, "c: old title"),
	}, { "ship", true })
	local untested = judge(base, { [C_SPEC] = spec("c", { "new title", "kept" }) })
	eq({
		untested.decision,
		has(untested.reasons, "note: breaking: removes behaviour") and has(untested.reasons, "c: old title"),
	}, { "ship", true })
end

T["loop: Judge rejects a lost test case by name"] = function()
	local base = { [C_SPEC] = spec("c", { "old title", "kept" }), [C_TEST] = cases({ "c: old title", "c: kept" }) }
	local swapped = judge(base, { [C_TEST] = cases({ "c: old title", "c: unrelated" }) })
	eq({ swapped.decision, has(swapped.reasons, "c: kept") }, { "reject", true })
	local nested = judge(
		{ [C_SPEC] = spec("c", { "kept" }), [C_TEST] = cases({ "c: kept", "c: other" }, "group") },
		{ [C_TEST] = cases({ "c: other", "c: unrelated" }, "group") }
	)
	eq({ nested.decision, has(nested.reasons, "c: kept"), has(nested.reasons, "group") }, { "reject", true, false })
	local moved = judge(base, {
		[C_SPEC] = spec("c", { "kept" }),
		["openspec/specs/d/spec.md"] = spec("d", { "new title" }),
		[C_TEST] = cases({ "d: new title", "c: kept" }),
	})
	eq({ moved.decision, has(moved.reasons, "c: old title") }, { "reject", true })
end

T["loop: Judge ships a deleted test file whose cases all moved"] = function()
	local base = { [C_SPEC] = spec("c", { "kept" }), [C_TEST] = cases({ "c: kept" }) }
	local moved = judge(base, { [C_TEST] = false, ["tests/unit/c/test_d.lua"] = cases({ "c: kept" }) })
	eq(moved.decision, "ship", { fail_reason = moved.reasons })
	local deleted = judge(base, { [C_TEST] = false, ["tests/unit/c/test_d.lua"] = cases({ "c: other" }) })
	eq({ deleted.decision, has(deleted.reasons, "test files deleted: " .. C_TEST) }, { "reject", true })
end

T["loop: A title-only REMOVED requirement plans its main-spec scenarios"] = function()
	local result = H.system(
		child,
		{ "python3", "-m", "unittest", "-q", "test_planned_removals" },
		vim.fs.joinpath(H.root, ".archon/scripts")
	)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

T["loop: Judge ships a test the change's spec delta removes"] = function()
	local base = { [C_SPEC] = spec("c", { "kept", "dropped" }), [C_TEST] = cases({ "c: dropped" }) }
	local removed = table.concat({
		"## REMOVED Requirements",
		"",
		"### Requirement: Fixture coverage",
		"",
		"#### Scenario: dropped",
		"- **WHEN** the fixture runs",
		"- **THEN** it passes",
	}, "\n")
	local delta = "openspec/changes/x/specs/c/spec.md"
	local planned = judge(base, { [C_TEST] = false, [delta] = removed })
	eq(has(planned.reasons, "test files deleted"), false, { fail_reason = planned.reasons })
	eq(has(planned.reasons, "test case(s) removed"), false, { fail_reason = planned.reasons })
	local other = judge(
		vim.tbl_extend("force", base, { [C_TEST] = cases({ "c: dropped", "c: kept" }) }),
		{ [C_TEST] = false, [delta] = removed }
	)
	eq({ other.decision, has(other.reasons, "c: kept"), has(other.reasons, "c: dropped") }, { "reject", true, false })
end

return T
