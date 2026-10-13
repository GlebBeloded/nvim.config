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

--- Throwaway repo whose `.archon/workflows/w.yaml` has one node declaring `skills`, with this
--- checkout's skills_check.py linked in.
---@param skills string[]
---@return string
local function make_skill_repo(skills)
	local repo = H.tempdir(child)
	local workflow = {
		"name: w",
		"nodes:",
		"  - id: n",
		"    prompt: p",
		"    skills: [" .. table.concat(skills, ", ") .. "]",
	}
	write_files(repo, { [".archon/workflows/w.yaml"] = table.concat(workflow, "\n") })
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
---@return test.SystemResult
local function run_check(repo, bin)
	return H.system(
		child,
		{ "python3", ".archon/scripts/skills_check.py", ".archon/workflows/w.yaml" },
		repo,
		stub_env(bin)
	)
end

T["loop: Skill preflight fails on an unresolved plugin skill"] = function()
	local repo = make_skill_repo({ "superpowers:writing-plans" })
	local bin = H.tempdir(child)
	write_claude_stub(bin, {
		{ id = PLUGIN_ID, scope = "project", enabled = true, installPath = bin, errors = { "not installed" } },
	})
	local result = run_check(repo, bin)
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	eq(result.stderr:find("superpowers:writing-plans", 1, true) ~= nil, true, { fail_reason = result.stderr })
end

T["loop: Skill preflight passes when every declared skill resolves"] = function()
	local repo = make_skill_repo({ "superpowers:writing-plans", "openspec-propose" })
	write_files(repo, { [".claude/skills/openspec-propose/SKILL.md"] = "x" })
	local install = H.tempdir(child)
	write_files(install, { ["skills/writing-plans/SKILL.md"] = "x" })
	local bin = H.tempdir(child)
	write_claude_stub(bin, { { id = PLUGIN_ID, scope = "user", enabled = true, installPath = install } })
	local result = run_check(repo, bin)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

return T
