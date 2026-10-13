local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

--- `archon` stub: `workflow run` ships the run (branch from --branch, one commit, merged into
--- auto with --no-ff), `isolation cleanup --merged` logs what Archon would judge "merged".
local ARCHON_STUB = [[#!/bin/sh
case "$1 $2" in
"workflow run")
	[ -n "$ARCHON_RUNS" ] && echo "$*" >>"$ARCHON_RUNS"
	while [ $# -gt 0 ]; do
		[ "$1" = --branch ] && branch=$2
		shift
	done
	git checkout -q -b "$branch" && git commit -q --allow-empty -m run &&
		git checkout -q auto && git merge -q --no-ff -m ship "$branch" ;;
"isolation cleanup")
	{ git rev-parse local/auto auto; git branch --merged local/auto; } >>"$LOOP_LOG" ;;
esac
exit 0
]]

--- `openspec` stub: `list --json` prints $OPENSPEC_LIST, by default one change `t-change`.
local OPENSPEC_STUB = [[#!/bin/sh
if [ -n "$OPENSPEC_LIST" ]; then echo "$OPENSPEC_LIST"; else echo '{"changes":[{"name":"t-change"}]}'; fi
]]

---@param path string
---@param content string
local function write_executable(path, content)
	child.lua("vim.fn.writefile(vim.split(..., '\\n'), select(2, ...)); vim.uv.fs_chmod(select(2, ...), 493)", {
		content,
		path,
	})
end

--- Repo on branch `auto` with one commit, no `local` remote, this checkout's Makefile and
--- queue_pick.py (for `make queue`).
---@return string
local function make_repo()
	local repo = H.tempdir(child)
	eq(H.system(child, { "git", "init", "-q", "-b", "auto" }, repo, H.GIT_ENV).code, 0)
	eq(H.system(child, { "git", "commit", "-q", "--allow-empty", "-m", "init" }, repo, H.GIT_ENV).code, 0)
	child.lua("vim.uv.fs_symlink(...)", { vim.fs.joinpath(H.root, "Makefile"), vim.fs.joinpath(repo, "Makefile") })
	local scripts = vim.fs.joinpath(repo, ".archon/scripts")
	child.fn.mkdir(scripts, "p")
	child.lua(
		"vim.uv.fs_copyfile(...)",
		{ vim.fs.joinpath(H.root, ".archon/scripts/queue_pick.py"), vim.fs.joinpath(scripts, "queue_pick.py") }
	)
	return repo
end

--- Writes the `archon` and `openspec` stubs into `dir`; returns the `archon` stub path.
---@param dir string
---@return string
local function write_stub(dir)
	local archon = vim.fs.joinpath(dir, "archon")
	write_executable(archon, ARCHON_STUB)
	write_executable(vim.fs.joinpath(dir, "openspec"), OPENSPEC_STUB)
	return archon
end

---@class test.LoopRun
---@field code integer make exit code
---@field output string make stdout and stderr
---@field log string[] lines the stub logged at `isolation cleanup --merged`
---@field runs string[] arguments of each `workflow run` the stub received

---@param path string
---@return string[]
local function read_lines(path)
	return child.lua_get("vim.fn.filereadable(...) == 1 and vim.fn.readfile(...) or {}", { path })
end

--- Env with the stubs first on PATH, their logs in a fresh temp dir and a temp HOME (keeps
--- `loop-register` away from the real ~/.archon); the queue inputs are cleared so an enclosing
--- loop run's `CHANGE`/`INPUTS_CHANGE` cannot leak in; `extra` is merged on top.
---@param extra? table<string, string>
---@return table<string, string>
local function stub_env(extra)
	local bin = H.tempdir(child)
	return vim.tbl_extend("force", H.GIT_ENV, {
		HOME = H.tempdir(child),
		ARCHON = write_stub(bin),
		LOOP_LOG = vim.fs.joinpath(bin, "cleanup.log"),
		ARCHON_RUNS = vim.fs.joinpath(bin, "runs.log"),
		PATH = bin .. ":" .. child.lua_get("vim.env.PATH"),
		MAKEFLAGS = "",
		MAKELEVEL = "",
		CHANGE = "",
		INPUTS_CHANGE = "",
	}, extra or {})
end

--- Runs `make <args>` in `repo` with `stub_env(env)`.
---@param repo string
---@param args string[]
---@param env? table<string, string>
---@return test.LoopRun
local function run_target(repo, args, env)
	local full = stub_env(env)
	local result = H.system(child, vim.list_extend({ "make" }, args), repo, full)
	return {
		code = result.code,
		output = result.stdout .. result.stderr,
		log = read_lines(full.LOOP_LOG),
		runs = read_lines(full.ARCHON_RUNS),
	}
end

---@type { args: string[], branch: string }[]
local TARGETS = {
	{ args = { "fix", "BUG=x" }, branch = "loop/fix%-" },
	{ args = { "feature", "IDEA=x" }, branch = "loop/feat%-" },
	{ args = { "queue", "CHANGE=t-change" }, branch = "loop/t%-change" },
	{ args = { "update", "PLUGIN=x" }, branch = "loop/update%-x%-" },
}

---@param target { args: string[], branch: string }
local function expect_cleanup_sees_merge(target)
	local run = run_target(make_repo(), target.args)
	local name = target.args[1]
	eq({ name, run.code }, { name, 0 }, { fail_reason = run.output })
	eq(#run.log >= 2, true, { fail_reason = name .. ": cleanup not called\n" .. run.output })
	eq({ name, run.log[1] }, { name, run.log[2] })
	local listed = vim.iter(vim.list_slice(run.log, 3)):any(function(line)
		return vim.trim(line):find("^" .. target.branch) ~= nil
	end)
	eq({ name, listed }, { name, true })
end

T["loop: Cleanup sees the merge the run shipped"] = function()
	vim.iter(TARGETS):each(expect_cleanup_sees_merge)
end

--- Adds an active change `name` with `created` in its .openspec.yaml to `repo` and commits it.
---@param repo string
---@param name string
---@param created string
local function write_change(repo, name, created)
	local dir = vim.fs.joinpath(repo, "openspec/changes", name)
	child.fn.mkdir(dir, "p")
	child.fn.writefile({ "created: " .. created }, vim.fs.joinpath(dir, ".openspec.yaml"))
	eq(H.system(child, { "git", "add", "openspec" }, repo, H.GIT_ENV).code, 0)
	eq(H.system(child, { "git", "commit", "-q", "-m", "change " .. name }, repo, H.GIT_ENV).code, 0)
end

--- Asserts `make queue` (no CHANGE) works `name` and asked Archon for its `loop/` branch.
---@param run test.LoopRun
---@param name string
local function expect_queue_works(run, name)
	eq(run.code, 0, { fail_reason = run.output })
	eq(run.output:find("JSONDecodeError", 1, true), nil, { fail_reason = run.output })
	eq(run.output:find("Working on " .. name, 1, true) ~= nil, true, { fail_reason = run.output })
	local branched = vim.iter(run.runs):any(function(line)
		return line:find("--branch loop/" .. name, 1, true) ~= nil
	end)
	eq(branched, true, { fail_reason = table.concat(run.runs, "\n") })
end

--- Asserts queue_pick.py, run directly in `repo` with `env`, prints one JSON object picking `name`.
---@param repo string
---@param env table<string, string>
---@param name string
local function expect_picks(repo, env, name)
	local result = H.system(child, { "python3", ".archon/scripts/queue_pick.py" }, repo, env)
	eq(result.code, 0, { fail_reason = result.stderr })
	local ok, picked = pcall(vim.json.decode, result.stdout)
	eq(ok, true, { fail_reason = result.stdout })
	eq(picked.change, name)
end

T["loop: Queue skips a taken change"] = function()
	local repo = make_repo()
	write_change(repo, "t-change", "2026-01-01")
	write_change(repo, "t-next", "2026-01-02")
	eq(H.system(child, { "git", "branch", "loop/t-change" }, repo, H.GIT_ENV).code, 0)
	local list = { OPENSPEC_LIST = '{"changes":[{"name":"t-change"},{"name":"t-next"}]}' }
	-- Pick directly first: the archon stub creates loop/t-next when make queue runs it.
	expect_picks(repo, stub_env(list), "t-next")
	expect_queue_works(run_target(repo, { "queue" }, list), "t-next")
end

return T
