local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPT = vim.fs.joinpath(H.root, ".archon/scripts/no_design.py")
local SCHEMA_DIR = "openspec/schemas/spec-driven-no-design"
local PROPOSAL = "## Why\nTighten a loop test.\n\nKind: bug\n\n## What Changes\n- x\n\n## Impact\n- tests only"
local TASKS = "## 1. Tighten\nScenarios: `loop: x`\n- [ ] 1.1 Run it"

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

--- A repo with the no-design schema and change `c` holding `meta` as its .openspec.yaml.
---@param meta string
---@return string repo
local function change_repo(meta)
	local repo = H.tempdir(child)
	write(repo, {
		["openspec/config.yaml"] = "schema: spec-driven",
		["openspec/changes/c/.openspec.yaml"] = meta,
		["openspec/changes/c/proposal.md"] = PROPOSAL,
		["openspec/changes/c/tasks.md"] = TASKS,
	})
	vim.fn.mkdir(vim.fs.joinpath(repo, "openspec/schemas"), "p")
	H.system(child, { "cp", "-R", vim.fs.joinpath(H.root, SCHEMA_DIR), vim.fs.joinpath(repo, SCHEMA_DIR) }, repo)
	return repo
end

---@param repo string
---@return table
local function no_design(repo)
	local env = { INPUTS_CHANGE = "c", LOOP_CHANGES_DIR = "" }
	local result = H.system(child, { "python3", SCRIPT }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout)
end

T["loop: Skip-specs change gets the no-design schema"] = function()
	local repo = change_repo("schema: spec-driven\nskip_specs: true")
	eq(no_design(repo), { skip_specs = true, design = false })
	has(read(vim.fs.joinpath(repo, "openspec/changes/c/.openspec.yaml")), "schema: spec-driven-no-design")
	local result = H.system(child, { "openspec", "status", "--change", "c", "--json" }, repo)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local status = vim.json.decode(result.stdout)
	local ids = vim.tbl_map(function(artifact)
		return artifact.id
	end, status.artifacts)
	eq(ids, { "proposal", "specs", "tasks" })
	eq(status.isComplete, true)
end

T["loop: No-design switch is committed on its own"] = function()
	local repo = change_repo("schema: spec-driven\nskip_specs: true")
	local git = function(args)
		local result = H.system(child, vim.list_extend({ "git" }, args), repo, H.GIT_ENV)
		eq(result.code, 0, { fail_reason = result.stderr })
		return result.stdout
	end
	git({ "init", "-q", "-b", "run" })
	git({ "add", "-A" })
	git({ "commit", "-q", "-m", "base" })
	no_design(repo)
	eq(git({ "status", "--porcelain" }), "")
	eq(vim.trim(git({ "log", "-1", "--format=%s" })), "chore(openspec): c uses the no-design schema")
end

---@param repo string
---@return table status `openspec status --json` of change `c`
local function status(repo)
	local result = H.system(child, { "openspec", "status", "--change", "c", "--json" }, repo)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout)
end

local DELTA = "## MODIFIED Requirements\n\n### Requirement: X\nThe loop SHALL x.\n\n#### Scenario: x\n- **WHEN** x\n- **THEN** y"

T["loop: Change without a new look gets the no-design schema"] = function()
	local repo = change_repo("schema: spec-driven")
	write(repo, { ["openspec/changes/c/specs/loop/spec.md"] = DELTA })
	eq(no_design(repo), { skip_specs = false, design = false })
	eq(read(vim.fs.joinpath(repo, "openspec/changes/c/.openspec.yaml")), "schema: spec-driven-no-design")
	local state = status(repo)
	eq(vim.tbl_map(function(artifact)
		return artifact.id
	end, state.artifacts), { "proposal", "specs", "tasks" })
	eq(state.isComplete, true)
end

T["loop: Change with a new look keeps the design schema"] = function()
	local feature = change_repo("schema: spec-driven-no-design")
	write(feature, { ["openspec/changes/c/proposal.md"] = "## Why\nx\n\nKind: feature\n\n## Impact\n- x" })
	eq(no_design(feature), { skip_specs = false, design = true })
	eq(read(vim.fs.joinpath(feature, "openspec/changes/c/.openspec.yaml")), "schema: spec-driven")
	local rendered = change_repo("schema: spec-driven")
	write(rendered, { ["openspec/changes/c/proposal.md"] = PROPOSAL .. "\n\n## Proposed render\nx" })
	eq(no_design(rendered), { skip_specs = false, design = true })
	eq(read(vim.fs.joinpath(rendered, "openspec/changes/c/.openspec.yaml")), "schema: spec-driven")
	local skip = change_repo("schema: spec-driven\nskip_specs: true")
	write(skip, { ["openspec/changes/c/proposal.md"] = "## Why\nx\n\nKind: feature\n\n## Impact\n- x" })
	eq(no_design(skip), { skip_specs = true, design = false })
end

---@param queue string
---@param id string
---@return string body of node `id`, up to the next node
local function node(queue, id)
	local body = queue:match("%- id: " .. vim.pesc(id) .. "[^\n]*\n(.-)\n  %- id:")
	eq(body ~= nil, true, { fail_reason = "no node " .. id })
	return body
end

T["loop: Work queue spec step returns no JSON"] = function()
	local queue = read(vim.fs.joinpath(H.root, ".archon/workflows/work-queue/work-queue.yaml"))
	has(node(queue, "meta"), "script: no_design")
	local complete = node(queue, "complete")
	has(complete, "command: queue-spec")
	eq(complete:find("output_format", 1, true), nil)
	eq(queue:find("complete-skip", 1, true), nil)
	local classify = node(queue, "classify")
	has(classify, "script: classify")
	has(classify, "depends_on: [complete]")
	has(classify, "required: [visible_ui, architecture]")
	has(node(queue, "spec-gate"), "depends_on: [complete, classify,")
	has(node(queue, "preview"), "$adopted-state.output.tasks_done == false && $classify.output.visible_ui == true")
end

local CLASSIFY = vim.fs.joinpath(H.root, ".archon/scripts/classify.py")
local RENDER = "# Design\n\n## Proposed render\nx"

---@param files table<string, string> change `c`'s files by name
---@return table classify.py's JSON for `c`
local function classify(files)
	local repo = H.tempdir(child)
	local change = {}
	for name, content in pairs(files) do
		change["openspec/changes/c/" .. name] = content
	end
	write(repo, vim.tbl_extend("force", { ["openspec/changes/c/.openspec.yaml"] = "schema: spec-driven" }, change))
	local result = H.system(child, { "python3", CLASSIFY }, repo, { INPUTS_CHANGE = "c", LOOP_CHANGES_DIR = "" })
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout)
end

---@param impact string
---@return string proposal whose Impact section is `impact` (wiring files named outside it do not count)
local function proposal(impact)
	return "## Why\nSee init.lua and lazy-lock.json.\n\n## Impact\n- " .. impact .. "\n"
end

T["loop: Classify reads visible UI and architecture from the change"] = function()
	local none = { visible_ui = false, architecture = false }
	eq(classify({ ["design.md"] = RENDER }), { visible_ui = true, architecture = false })
	eq(classify({ ["design.md"] = "# Design\n\n## Decisions\nx", ["proposal.md"] = proposal("tests only") }), none)
	for _, path in ipairs({ "`lua/gleb/plugins/plugins.lua`", "`init.lua`", "lazy-lock.json" }) do
		eq(classify({ ["proposal.md"] = proposal(path) }), { visible_ui = false, architecture = true })
	end
	eq(classify({ ["proposal.md"] = proposal("`lua/gleb/lsp/config/terraform/init.lua`") }), none)
	eq(classify({ ["tasks.md"] = "## 1. x\n- [ ] 1.1 edit lua/gleb/plugins/plugins.lua" }).architecture, true)
	local skip = {
		[".openspec.yaml"] = "schema: spec-driven-no-design\nskip_specs: true",
		["design.md"] = RENDER,
		["proposal.md"] = proposal("init.lua"),
	}
	eq(classify(skip), none)
end

T["loop: Queue spec prompt opens with a skip_specs fast path"] = function()
	local prompt = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	local fast = prompt:find("**Fast path, `skip_specs: true`**", 1, true)
	local full = prompt:find("**Full path** (no `skip_specs`)", 1, true)
	eq(fast ~= nil and full ~= nil and fast < full, true)
	has(prompt, "`[~] specs (skipped: change declares skip_specs)`, `[x] tasks`")
	has(
		prompt,
		"Forbidden on this path: reading `.archon/`, `openspec/config.yaml` or `openspec/changes/archive/`, running `openspec instructions` (any artifact)"
	)
	has(prompt, "sed -n '/^rules:/,/^operations:/p' openspec/config.yaml")
	eq(prompt:find("context.md", 1, true), nil)
end

T["loop: Queue spec prompt keeps the schema and greps one capability"] = function()
	local prompt = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	has(prompt, "the work-queue meta step already set the change's `schema:` in `.openspec.yaml`")
	has(prompt, "Never change the `schema:` line, never read `openspec/schemas/` or run `openspec instructions design`.")
	has(prompt, "delete only the `skip_specs` line from `.openspec.yaml` (keep its `schema:` line)")
	eq(prompt:find("set `schema: spec-driven` in", 1, true), nil)
	has(prompt, "never list every Requirement or Scenario of all specs (no `rg` over `openspec/specs/` as a whole)")
	has(prompt, "rg -n '^### Requirement:|^#### Scenario:' openspec/specs/<capability>/spec.md")
end

T["loop: Queue spec prompt sees a tightened assertion fail"] = function()
	local prompt = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	has(prompt, "The refactor template is only for changes that leave every assertion as is.")
	has(prompt, "task 1.1 makes the new assertion fail once by a temporary fault")
	has(prompt, "see it fail and record the failure, then remove the fault")
end

return T
