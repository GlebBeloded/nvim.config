local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local PLUGIN_ID = "superpowers@superpowers-marketplace"

--- Writes `files` (relative path -> content) under `dir`.
---@param dir string
---@param files table<string, string>
local function write_files(dir, files)
	child.lua(
		[[local dir, files = ...
		for path, content in pairs(files) do
			local full = vim.fs.joinpath(dir, path)
			vim.fn.mkdir(vim.fs.dirname(full), "p")
			vim.fn.writefile(vim.split(content, "\n"), full)
		end]],
		{ dir, files }
	)
end

---@param path string
---@param content string
local function write_executable(path, content)
	write_files(vim.fs.dirname(path), { [vim.fs.basename(path)] = content })
	child.lua("vim.uv.fs_chmod(..., 493)", { path })
end

--- Links this checkout's `name` (repo-relative) into `repo` at the same path.
---@param repo string
---@param name string
local function link_from_checkout(repo, name)
	local target = vim.fs.joinpath(repo, name)
	child.fn.mkdir(vim.fs.dirname(target), "p")
	child.lua("vim.uv.fs_symlink(...)", { vim.fs.joinpath(H.root, name), target })
end

--- Throwaway repo whose `.archon/workflows/w.yaml` has one node declaring `skills` (then the
--- `extra_yaml` lines) and whose `.archon/config.yaml` names `assistant`, with this checkout's
--- skills_check.py linked in.
---@param skills string[]
---@param opts? { assistant?: string, extra_yaml?: string[] }
---@return string
local function make_skill_repo(skills, opts)
	opts = opts or {}
	local repo = H.tempdir(child)
	local workflow = {
		"name: w",
		"nodes:",
		"  - id: n",
		"    prompt: p",
		"    skills: [" .. table.concat(skills, ", ") .. "]",
	}
	vim.list_extend(workflow, opts.extra_yaml or {})
	write_files(repo, {
		[".archon/workflows/w.yaml"] = table.concat(workflow, "\n"),
		[".archon/config.yaml"] = "assistant: " .. (opts.assistant or "claude"),
	})
	link_from_checkout(repo, ".archon/scripts/skills_check.py")
	return repo
end

--- `claude` stub in `bin`: `plugin list --json` prints `plugins` as JSON; every call appends its
--- arguments to `bin/claude.log`.
---@param bin string
---@param plugins table[]
---@return string log
local function write_claude_stub(bin, plugins)
	local log = vim.fs.joinpath(bin, "claude.log")
	local list = vim.fs.joinpath(bin, "plugins.json")
	write_files(bin, { ["plugins.json"] = vim.json.encode(plugins) })
	write_executable(
		vim.fs.joinpath(bin, "claude"),
		table.concat({
			"#!/bin/sh",
			string.format('echo "$*" >>"%s"', log),
			string.format('[ "$1 $2 $3" = "plugin list --json" ] && cat "%s"', list),
			"exit 0",
		}, "\n")
	)
	return log
end

--- `codex` stub in `bin`: `plugin list --json` prints `{ installed = installed, available = {} }`
--- as JSON and exits `list_code` (default 0); every call appends its arguments to `bin/codex.log`.
---@param bin string
---@param installed table[]
---@param list_code? integer
---@return string log
local function write_codex_stub(bin, installed, list_code)
	local log = vim.fs.joinpath(bin, "codex.log")
	local list = vim.fs.joinpath(bin, "codex-plugins.json")
	-- vim.json.encode turns an empty table into `{}`; Codex reports an empty list as `[]`.
	local encoded = #installed == 0 and "[]" or vim.json.encode(installed)
	write_files(bin, { ["codex-plugins.json"] = '{"installed":' .. encoded .. ',"available":[]}' })
	write_executable(
		vim.fs.joinpath(bin, "codex"),
		table.concat({
			"#!/bin/sh",
			string.format('echo "$*" >>"%s"', log),
			string.format('[ "$1 $2 $3" = "plugin list --json" ] && { cat "%s"; exit %d; }', list, list_code or 0),
			"exit 0",
		}, "\n")
	)
	return log
end

--- Env with `bin` first on PATH; `extra` is merged on top. HOME stays real so python3 finds
--- PyYAML in the user site.
---@param bin string
---@param extra? table<string, string>
---@return table<string, string>
local function stub_env(bin, extra)
	return vim.tbl_extend("force", H.GIT_ENV, {
		PATH = bin .. ":" .. child.lua_get("vim.env.PATH"),
		MAKEFLAGS = "",
		MAKELEVEL = "",
	}, extra or {})
end

---@param repo string
---@param bin string
---@param extra_env? table<string, string>
---@return test.SystemResult
local function run_check(repo, bin, extra_env)
	return H.system(
		child,
		{ "python3", ".archon/scripts/skills_check.py", ".archon/workflows/w.yaml" },
		repo,
		stub_env(bin, extra_env)
	)
end

T["loop: Skill preflight fails on an unresolved plugin skill"] = function()
	local repo = make_skill_repo({ "superpowers:writing-plans" }, { assistant = "claude" })
	local bin = H.tempdir(child)
	write_claude_stub(bin, {
		{ id = PLUGIN_ID, scope = "project", enabled = true, installPath = bin, errors = { "not installed" } },
	})
	local result = run_check(repo, bin)
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	eq(result.stderr:find("superpowers:writing-plans", 1, true) ~= nil, true, { fail_reason = result.stderr })
end

T["loop: Skill preflight fails on a Claude plugin with no install path"] = function()
	local repo = make_skill_repo({ "superpowers:writing-plans" }, { assistant = "claude" })
	local bin = H.tempdir(child)
	write_claude_stub(bin, { { id = PLUGIN_ID, scope = "user", enabled = true } })
	local result = run_check(repo, bin)
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	eq(result.stderr:find("superpowers:writing-plans", 1, true) ~= nil, true, { fail_reason = result.stderr })
	eq(result.stderr:find("Traceback", 1, true), nil, { fail_reason = result.stderr })
end

T["loop: Skill preflight passes when every declared skill resolves"] = function()
	local repo = make_skill_repo({ "superpowers:writing-plans", "openspec-propose" }, { assistant = "claude" })
	write_files(repo, { [".claude/skills/openspec-propose/SKILL.md"] = "x" })
	local install = H.tempdir(child)
	write_files(install, { ["skills/writing-plans/SKILL.md"] = "x" })
	local bin = H.tempdir(child)
	write_claude_stub(bin, { { id = PLUGIN_ID, scope = "user", enabled = true, installPath = install } })
	local result = run_check(repo, bin)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

--- Dir holding `skills/<skill>/SKILL.md` for each of `skills`: a plugin install or source path.
---@param skills string[]
---@return string
local function make_plugin_dir(skills)
	local dir = H.tempdir(child)
	for _, skill in ipairs(skills) do
		write_files(dir, { ["skills/" .. skill .. "/SKILL.md"] = "x" })
	end
	return dir
end

--- Runs the check with a claude stub that loads writing-plans and a codex stub with `installed`.
---@param installed table[]
---@param list_code? integer
---@return test.SystemResult
local function run_codex_check(installed, list_code)
	local repo = make_skill_repo({ "superpowers:writing-plans" }, { assistant = "codex" })
	local bin = H.tempdir(child)
	write_claude_stub(bin, {
		{ id = PLUGIN_ID, scope = "user", enabled = true, installPath = make_plugin_dir({ "writing-plans" }) },
	})
	write_codex_stub(bin, installed, list_code)
	return run_check(repo, bin)
end

T["loop: Skill preflight fails on a plugin skill Codex does not have"] = function()
	local result = run_codex_check({})
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	eq(result.stderr:find("superpowers:writing-plans", 1, true) ~= nil, true, { fail_reason = result.stderr })

	-- Installed but disabled: still unresolved.
	local source = { path = make_plugin_dir({ "writing-plans" }) }
	result = run_codex_check({ { name = "superpowers", installed = true, enabled = false, source = source } })
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	eq(result.stderr:find("superpowers:writing-plans", 1, true) ~= nil, true, { fail_reason = result.stderr })

	-- `codex plugin list --json` fails: a message naming codex, not a traceback.
	result = run_codex_check({}, 1)
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	eq(result.stderr:find("codex", 1, true) ~= nil, true, { fail_reason = result.stderr })
	eq(result.stderr:find("Traceback", 1, true), nil, { fail_reason = result.stderr })
end

T["loop: Skill preflight resolves skills for each node's provider"] = function()
	local repo = make_skill_repo({ "superpowers:writing-plans", "openspec-propose" }, {
		assistant = "codex",
		extra_yaml = {
			"  - id: l",
			"    provider: claude",
			"    loop_group:",
			"      nodes:",
			"        - id: r",
			"          prompt: p",
			"          skills: [superpowers:requesting-code-review]",
		},
	})
	write_files(repo, { [".agents/skills/openspec-propose/SKILL.md"] = "x" })
	local bin = H.tempdir(child)
	write_codex_stub(bin, {
		{
			name = "superpowers",
			installed = true,
			enabled = true,
			source = { path = make_plugin_dir({ "writing-plans" }) },
		},
	})
	write_claude_stub(bin, {
		{ id = PLUGIN_ID, scope = "user", enabled = true, installPath = make_plugin_dir({ "requesting-code-review" }) },
	})
	local result = run_check(repo, bin)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

--- Codex stub entry for the remote superpowers plugin: no `source.path`, so its root is the
--- Codex plugin cache. `version` is dropped when `opts.no_version` is set.
---@param opts? { no_version?: boolean }
---@return table
local function remote_codex_plugin(opts)
	return {
		name = "superpowers",
		marketplaceName = "openai-curated-remote",
		version = not (opts and opts.no_version) and "6.4.2" or nil,
		installed = true,
		enabled = true,
		source = { source = "remote", id = "plugins~Plugin_x" },
	}
end

--- Runs the check of a codex repo declaring writing-plans with `CODEX_HOME = codex_home` and a codex
--- stub reporting `plugin`.
---@param codex_home string
---@param plugin table
---@return test.SystemResult
local function run_remote_codex_check(codex_home, plugin)
	local repo = make_skill_repo({ "superpowers:writing-plans" }, { assistant = "codex" })
	local bin = H.tempdir(child)
	write_codex_stub(bin, { plugin })
	return run_check(repo, bin, { CODEX_HOME = codex_home })
end

---@return string codex_home holding the 6.4.2 remote superpowers cache with writing-plans
local function make_codex_cache()
	local codex_home = H.tempdir(child)
	local skill = "plugins/cache/openai-curated-remote/superpowers/6.4.2/skills/writing-plans/SKILL.md"
	write_files(codex_home, { [skill] = "x" })
	return codex_home
end

T["loop: Skill preflight resolves a remote Codex plugin from the plugin cache"] = function()
	local result = run_remote_codex_check(make_codex_cache(), remote_codex_plugin())
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

---@param result test.SystemResult
local function expect_unresolved_writing_plans(result)
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	eq(result.stderr:find("superpowers:writing-plans", 1, true) ~= nil, true, { fail_reason = result.stderr })
	eq(result.stderr:find("Traceback", 1, true), nil, { fail_reason = result.stderr })
end

T["loop: Skill preflight fails on a remote Codex plugin missing from the plugin cache"] = function()
	expect_unresolved_writing_plans(run_remote_codex_check(H.tempdir(child), remote_codex_plugin()))

	-- The entry names no version: no root, even with the cache present.
	expect_unresolved_writing_plans(
		run_remote_codex_check(make_codex_cache(), remote_codex_plugin({ no_version = true }))
	)
end

local YAML_TO_JSON = "import json,sys,yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))"

---@class test.WorkflowNode
---@field id string
---@field bash? string
---@field command? string
---@field skills? string[]
---@field depends_on? string[]
---@field loop_group? { nodes: test.WorkflowNode[] }

---@class test.Workflow
---@field name string
---@field nodes test.WorkflowNode[]

--- Every `.archon/workflows/*.yaml` of this checkout, parsed by PyYAML.
---@return test.Workflow[]
local function load_workflows()
	local paths = vim.fn.glob(vim.fs.joinpath(H.root, ".archon/workflows/*.yaml"), false, true)
	return vim.tbl_map(function(path)
		local result = H.system(child, { "python3", "-c", YAML_TO_JSON, path }, H.root)
		eq(result.code, 0, { fail_reason = path .. "\n" .. result.stderr })
		return vim.json.decode(result.stdout)
	end, paths)
end

--- Top-level nodes paired with each node they own: itself and its `loop_group.nodes`.
---@param workflow test.Workflow
---@return { top: test.WorkflowNode, node: test.WorkflowNode }[]
local function owned_nodes(workflow)
	local owned = {}
	for _, top in ipairs(workflow.nodes) do
		table.insert(owned, { top = top, node = top })
		for _, inner in ipairs(top.loop_group and top.loop_group.nodes or {}) do
			table.insert(owned, { top = top, node = inner })
		end
	end
	return owned
end

---@param node test.WorkflowNode
---@return boolean
local function declares_plugin_skill(node)
	return vim.iter(node.skills or {}):any(function(skill)
		return skill:find(":", 1, true) ~= nil
	end)
end

--- Whether `from` reaches node `target` through the transitive `depends_on` of `by_id`.
---@param by_id table<string, test.WorkflowNode>
---@param from test.WorkflowNode
---@param target string
---@return boolean
local function reaches(by_id, from, target)
	local seen, stack = {}, vim.deepcopy(from.depends_on or {})
	while #stack > 0 do
		local id = table.remove(stack)
		if id == target then
			return true
		end
		if not seen[id] and by_id[id] then
			seen[id] = true
			vim.list_extend(stack, by_id[id].depends_on or {})
		end
	end
	return false
end

--- `{ workflow, node }` for each plugin-skill node that does not depend on the preflight node.
---@param workflow test.Workflow
---@return { workflow: string, node: string }[]
local function preflight_violations(workflow)
	local check = vim.iter(workflow.nodes):find(function(node)
		return (node.bash or ""):find(".archon/scripts/skills_check.py", 1, true) ~= nil
	end)
	if not check then
		return { { workflow = workflow.name, node = "(no skills_check.py bash node)" } }
	end
	local by_id = {}
	for _, node in ipairs(workflow.nodes) do
		by_id[node.id] = node
	end
	local violations = {}
	for _, owned in ipairs(owned_nodes(workflow)) do
		if declares_plugin_skill(owned.node) and not reaches(by_id, owned.top, check.id) then
			table.insert(violations, { workflow = workflow.name, node = owned.node.id })
		end
	end
	return violations
end

T["loop: Skill preflight runs before every skill-declaring node"] = function()
	local violations = vim.iter(load_workflows()):map(preflight_violations):flatten():totable()
	eq(violations, {})
end

---@type string[] Plain-text needles of the load-first step every skill-declaring command opens with.
local LOAD_FIRST_NEEDLES = { "Skill tool", "before any other step", "does not load, stop" }

--- `{ command, problem }` for each way the command of `node` fails to name and load its skills.
---@param node test.WorkflowNode
---@return { command: string, problem: string }[]
local function command_violations(node)
	local path = vim.fs.joinpath(H.root, ".archon/commands", node.command .. ".md")
	-- Joined on spaces with whitespace collapsed: markdown wraps lines anywhere.
	local text = table.concat(vim.fn.readfile(path), " "):gsub("%s+", " ")
	local problems = {}
	local function add(problem)
		table.insert(problems, { command = node.command, problem = problem })
	end
	for _, skill in ipairs(node.skills) do
		if not text:find("`" .. skill .. "`", 1, true) then
			add("does not name `" .. skill .. "`")
		end
		local codex_name = "$" .. skill:gsub("^[%w-]+:", "") -- Codex loads `$<skill>` copies (skills_check.py)
		if not text:find(codex_name, 1, true) then
			add("does not name " .. codex_name)
		end
	end
	for _, needle in ipairs(LOAD_FIRST_NEEDLES) do
		if not text:find(needle, 1, true) then
			add("lacks load-first text: " .. needle)
		end
	end
	for named in text:gmatch("`(superpowers:[%w-]+)`") do
		if not vim.list_contains(node.skills, named) then
			add("names undeclared `" .. named .. "`")
		end
	end
	return problems
end

---@param owned { node: test.WorkflowNode }
---@return boolean
local function has_skills_and_command(owned)
	return owned.node.skills ~= nil and owned.node.command ~= nil
end

T["loop: Every declared skill is named and loaded by its command"] = function()
	local violations = vim.iter(load_workflows())
		:map(owned_nodes)
		:flatten()
		:filter(has_skills_and_command)
		:map(function(owned)
			return command_violations(owned.node)
		end)
		:flatten()
		:totable()
	eq(violations, {})
end

--- Repo on branch `auto` with one commit, this checkout's Makefile and skills_check.py linked in
--- (as in test_cleanup.lua) and `.claude/settings.json` enabling the superpowers plugin.
---@return string
local function make_setup_repo()
	local repo = H.tempdir(child)
	eq(H.system(child, { "git", "init", "-q", "-b", "auto" }, repo, H.GIT_ENV).code, 0)
	eq(H.system(child, { "git", "commit", "-q", "--allow-empty", "-m", "init" }, repo, H.GIT_ENV).code, 0)
	link_from_checkout(repo, "Makefile")
	link_from_checkout(repo, ".archon/scripts/skills_check.py")
	write_files(repo, { [".claude/settings.json"] = vim.json.encode({ enabledPlugins = { [PLUGIN_ID] = true } }) })
	return repo
end

T["loop: Loop setup installs a missing enabled plugin"] = function()
	local repo = make_setup_repo()
	local bin = H.tempdir(child)
	local log = write_claude_stub(bin, {
		{ id = PLUGIN_ID, scope = "project", enabled = true, installPath = bin, errors = { "not installed" } },
	})
	local archon = vim.fs.joinpath(bin, "archon")
	write_executable(archon, "#!/bin/sh\nexit 0")
	local env = stub_env(bin, { HOME = H.tempdir(child), ARCHON = archon })
	local result = H.system(child, { "make", "loop-setup" }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local calls = child.lua_get("vim.fn.filereadable(...) == 1 and vim.fn.readfile(...) or {}", { log })
	local installed = vim.list_contains(calls, "plugin install " .. PLUGIN_ID .. " --scope user")
	eq(installed, true, { fail_reason = table.concat(calls, "\n") })
end

--- Dir that holds the `yaml` package python3 imports with the real HOME (often the user site).
---@return string
local function pyyaml_dir()
	local find = "import os,yaml; print(os.path.dirname(os.path.dirname(yaml.__file__)))"
	local result = H.system(child, { "python3", "-c", find }, H.root)
	eq(result.code, 0, { fail_reason = result.stderr })
	return vim.trim(result.stdout)
end

T["loop: Loop setup installs a missing Codex plugin"] = function()
	local repo = make_setup_repo()
	write_files(repo, {
		[".archon/config.yaml"] = "assistant: codex",
		[".archon/workflows/w.yaml"] = "name: w\nnodes:\n  - id: n\n    prompt: p\n    skills: [superpowers:writing-plans]",
	})
	local bin = H.tempdir(child)
	write_claude_stub(bin, { { id = PLUGIN_ID, scope = "user", enabled = true, installPath = bin } })
	local log = write_codex_stub(bin, {})
	local archon = vim.fs.joinpath(bin, "archon")
	write_executable(archon, "#!/bin/sh\nexit 0")
	-- Throwaway HOME keeps loop-register off the real Archon registration; PYTHONPATH keeps PyYAML.
	local env = stub_env(bin, { HOME = H.tempdir(child), ARCHON = archon, PYTHONPATH = pyyaml_dir() })
	local result = H.system(child, { "make", "loop-setup" }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local calls = child.lua_get("vim.fn.filereadable(...) == 1 and vim.fn.readfile(...) or {}", { log })
	local added = vim.list_contains(calls, "plugin add superpowers@openai-curated-remote")
	eq(added, true, { fail_reason = table.concat(calls, "\n") })
end

return T
