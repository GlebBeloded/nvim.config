local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPTS = vim.fs.joinpath(H.root, ".archon/scripts")
local PIN = "keymaps: gr bound to Telescope references (openspec/specs/keymaps/spec.md:4)"
local KEYMAPS = 'map("n", "gr", require("telescope.builtin").lsp_references, "LSP: References")'

local SPEC = table.concat({
	"## Requirements",
	"### Requirement: LSP actions",
	"The config SHALL map `gr` to Telescope references.",
	"#### Scenario: gr bound to Telescope references",
	'- **WHEN** `vim.fn.maparg("gr", "n", false, true).callback` is read',
	'- **THEN** it equals `require("telescope.builtin").lsp_references`',
	"",
	"#### Scenario: Every mapping has a desc",
	"- **WHEN** `maparg(lhs).desc` is read for `a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`, `gr`",
	"- **THEN** each is set",
	"",
	"#### Scenario: Help lists no gr row",
	"- **THEN** the screen matches the reference screenshot: no `gr` row",
	"",
	"### Requirement: Known bugs",
	"#### Scenario: xfail names a queued change",
	"- **WHEN** a test wraps a case in `H.xfail`",
	"- **THEN** the case is expected to fail",
}, "\n")

local PROPOSAL = table.concat({
	"## Why",
	"x",
	"",
	"## What Changes",
	"- `gr`: `lsp_references({ include_current_line = true })`.",
	"- Remove the `H.xfail` in `tests/e2e/lsp/test_go_references.lua`.",
	"",
	"## Impact",
	"- Code: `lua/gleb/keymaps.lua`.",
}, "\n")

---@param root string
---@param files table<string, string>
local function write(root, files)
	for path, content in pairs(files) do
		local target = vim.fs.joinpath(root, path)
		vim.fn.mkdir(vim.fs.dirname(target), "p")
		vim.fn.writefile(vim.split(content, "\n", { plain = true }), target)
	end
end

---@param files table<string, string>
---@return string repo with the keymaps spec, config and `files`
local function repo_with(files)
	local repo = H.tempdir(child)
	write(repo, { ["openspec/specs/keymaps/spec.md"] = SPEC, ["lua/gleb/keymaps.lua"] = KEYMAPS })
	write(repo, files)
	return repo
end

---@param args string[]
---@param cwd string
local function git_ok(args, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, args), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

--- Repo committed on `auto`, then branch `run` with `keymaps` committed as lua/gleb/keymaps.lua.
---@param keymaps string
---@return string
local function branch_repo(keymaps)
	local repo =
		repo_with({ ["openspec/changes/c/proposal.md"] = "## What Changes\n- fix references\n\n## Impact\n- none" })
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	git_ok({ "add", "-A" }, repo)
	git_ok({ "commit", "-q", "-m", "initial" }, repo)
	git_ok({ "checkout", "-q", "-b", "run" }, repo)
	write(repo, { ["lua/gleb/keymaps.lua"] = keymaps })
	git_ok({ "commit", "-q", "-am", "change" }, repo)
	return repo
end

---@param repo string
---@param check? boolean
---@return test.SystemResult
local function pinned(repo, check)
	local cmd = { "python3", vim.fs.joinpath(SCRIPTS, "pinned.py") }
	if check then
		table.insert(cmd, "--check")
	end
	table.insert(cmd, "c")
	local env = vim.tbl_extend("force", H.GIT_ENV, { BASE_BRANCH = "auto", LOOP_CHANGES_DIR = "" })
	return H.system(child, cmd, repo, env)
end

---@param path string
---@return string text with whitespace runs folded to one space
local function read(path)
	return (table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, path)), "\n"):gsub("%s+", " "))
end

---@param text string
---@param needle string
local function has(text, needle)
	eq(text:find(needle, 1, true) ~= nil, true, { fail_reason = ("missing %q in:\n%s"):format(needle, text) })
end

T["loop: Pinned lists a scenario a proposal symbol names"] = function()
	local repo = repo_with({ ["openspec/changes/c/proposal.md"] = PROPOSAL })
	local result = pinned(repo)
	eq({ result.code, result.stdout }, { 0, PIN .. "\n" }, { fail_reason = result.stderr })
	local check = pinned(repo, true)
	eq(check.code, 1)
	has(check.stdout, "- " .. PIN)
end

T["loop: Pinned ignores the loop spec's examples"] = function()
	local repo = repo_with({
		["openspec/changes/c/proposal.md"] = PROPOSAL,
		["openspec/specs/loop/spec.md"] = SPEC,
	})
	local result = pinned(repo)
	eq({ result.code, result.stdout }, { 0, PIN .. "\n" }, { fail_reason = result.stderr })
end

T["loop: Pinned skips a planned or explained scenario"] = function()
	local delta = repo_with({
		["openspec/changes/c/proposal.md"] = PROPOSAL,
		["openspec/changes/c/specs/keymaps/spec.md"] = "## MODIFIED Requirements",
	})
	local planned = pinned(delta, true)
	eq({ planned.code, planned.stdout }, { 0, "" }, { fail_reason = planned.stderr })
	local line = "\n- `keymaps: gr bound to Telescope references` still holds: the callback reaches it."
	local explained = pinned(repo_with({ ["openspec/changes/c/proposal.md"] = PROPOSAL .. line }), true)
	eq({ explained.code, explained.stdout }, { 0, "" }, { fail_reason = explained.stderr })
end

T["loop: Pinned reads mappings the branch diff changes"] = function()
	local callback = "local function lsp_refs()\nend\n" .. 'map("n", "gr", lsp_refs, "LSP: References")'
	local changed = pinned(branch_repo(callback))
	eq({ changed.code, changed.stdout }, { 0, PIN .. "\n" }, { fail_reason = changed.stderr })
	local desc = pinned(branch_repo((KEYMAPS:gsub("LSP: References", "LSP: Find references"))))
	eq({ desc.code, desc.stdout }, { 0, "none\n" }, { fail_reason = desc.stderr })
end

T["loop: Gate rejects a pinned scenario before make check"] = function()
	local repo = repo_with({ ["openspec/changes/c/proposal.md"] = PROPOSAL })
	local scratch = H.tempdir(child)
	local bin = vim.fs.joinpath(scratch, "bin")
	write(bin, { make = ('#!/bin/sh\ntouch "%s/make-ran"'):format(scratch) })
	vim.fn.setfperm(vim.fs.joinpath(bin, "make"), "rwxr-xr-x")
	local env = { ARTIFACTS_DIR = H.tempdir(child), INPUTS_CHANGE = "c", PATH = bin .. ":" .. vim.env.PATH }
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "gate.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local gate = vim.json.decode(result.stdout)
	eq({ gate.green, vim.fn.filereadable(vim.fs.joinpath(scratch, "make-ran")) }, { false, 0 })
	has(gate.failures, "hard rule: pinned scenario")
	has(gate.failures, PIN)
end

T["loop: Spec steps receive pinned scenarios"] = function()
	local queue = read(".archon/workflows/work-queue/work-queue.yaml")
	has(queue, "- id: pinned")
	has(queue, "bash: python3 .archon/scripts/pinned.py $pick.output.change")
	has(queue, "depends_on: [pick, skills-check, adopted-state, blocked, pinned, meta]")
	has(queue, "pinned: $pinned.output")
	has(queue, "pinned.py --check $pick.output.change")
	has(read(".archon/workflows/fix-bug/fix-bug.yaml"), "pinned.py --check $spec.output.change")
	local rule = "Each gets a MODIFIED delta restated to the new behaviour, or one line in proposal.md `## Impact`"
	local spec = read(".archon/commands/queue-spec.md")
	has(
		spec,
		"Pinned scenarios (`pinned.py`: main-spec scenarios naming a symbol this change touches): $INPUTS.pinned."
	)
	has(spec, rule)
	local bug = read(".archon/commands/spec-bug.md")
	has(bug, "run `python3 .archon/scripts/pinned.py <change>`")
	has(bug, (rule:gsub("^Each", "each")))
end

T["loop: Fix prompt allows a delta for a contradicted pin"] = function()
	local fix = read(".archon/commands/fix.md")
	has(fix, "a failing test pins a main-spec scenario this change intentionally contradicts")
	has(fix, "add a MODIFIED delta restating that scenario to the new behaviour and update the test to the new THEN")
	has(fix, "An edited assertion must still prove its scenario's THEN")
	has(fix, "replacing a behaviour/callback check with metadata (desc, buffer) is weakening")
end

T["loop: Queue spec prompt keeps skip_specs and flake tasks narrow"] = function()
	local spec = read(".archon/commands/queue-spec.md")
	has(spec, "Locate cited code with `rg -n <symbol>`, not by the proposal's line numbers")
	has(spec, "With `skip_specs: true`, read only `rg -n '^#### Scenario:'` of the named spec, no archive examples")
	has(spec, "visible_ui/architecture are false for test-only changes")
	has(spec, "copy the `FAIL in` lines from the proposal; never search `artifacts/runs` or old gate logs")
end

return T
