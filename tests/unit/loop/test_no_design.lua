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
	eq(no_design(repo), { skip_specs = true, visible_ui = false, architecture = false })
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

T["loop: Change without skip_specs keeps its schema"] = function()
	local repo = change_repo("schema: spec-driven")
	eq(no_design(repo).skip_specs, false)
	eq(read(vim.fs.joinpath(repo, "openspec/changes/c/.openspec.yaml")), "schema: spec-driven")
end

T["loop: Work queue asks the spec step for JSON only without skip_specs"] = function()
	local queue = read(vim.fs.joinpath(H.root, ".archon/workflows/work-queue/work-queue.yaml"))
	has(queue, "- id: meta")
	has(queue, "script: no_design")
	local complete = queue:match("%- id: complete\n(.-)\n  %- id:")
	has(complete, '&& $meta.output.skip_specs == false"')
	has(complete, "output_format:")
	local skip = queue:match("%- id: complete%-skip[^\n]*\n(.-)\n  %- id:")
	has(skip, "command: queue-spec")
	has(skip, '&& $meta.output.skip_specs == true"')
	eq(skip:find("output_format", 1, true), nil)
	has(queue, "$meta.output.skip_specs == false && $complete.output.visible_ui == true")
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

T["loop: Queue spec prompt sees a tightened assertion fail"] = function()
	local prompt = read(vim.fs.joinpath(H.root, ".archon/commands/queue-spec.md")):gsub("%s+", " ")
	has(prompt, "The refactor template is only for changes that leave every assertion as is.")
	has(prompt, "task 1.1 makes the new assertion fail once by a temporary fault")
	has(prompt, "see it fail and record the failure, then remove the fault")
end

return T
