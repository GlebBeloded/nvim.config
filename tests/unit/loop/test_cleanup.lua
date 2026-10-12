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

---@param cmd string[]
---@param cwd string
---@param env? table<string, string>
---@return { code: integer, stdout: string, stderr: string }
local function system(cmd, cwd, env)
	return child.lua_get("vim.system(..., { cwd = select(2, ...), env = select(3, ...), text = true }):wait(30000)", {
		cmd,
		cwd,
		env or vim.empty_dict(),
	})
end

---@return string
local function tempdir()
	return child.lua_get(
		"(function() local d = vim.fn.tempname(); vim.fn.mkdir(d, 'p'); return vim.uv.fs_realpath(d) end)()"
	)
end

--- Git identity and an empty config, so commits work without the user's (signing) setup.
---@type table<string, string>
local GIT_ENV = {
	GIT_AUTHOR_NAME = "test",
	GIT_AUTHOR_EMAIL = "test@example.com",
	GIT_COMMITTER_NAME = "test",
	GIT_COMMITTER_EMAIL = "test@example.com",
	GIT_CONFIG_GLOBAL = "/dev/null",
	GIT_CONFIG_NOSYSTEM = "1",
}

--- Repo on branch `auto` with one commit, no `local` remote, this checkout's Makefile and
--- queue_pick.py (for `make queue`).
---@return string
local function make_repo()
	local repo = tempdir()
	eq(system({ "git", "init", "-q", "-b", "auto" }, repo, GIT_ENV).code, 0)
	eq(system({ "git", "commit", "-q", "--allow-empty", "-m", "init" }, repo, GIT_ENV).code, 0)
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
--- `loop-register` away from the real ~/.archon); `extra` is merged on top.
---@param extra? table<string, string>
---@return table<string, string>
local function stub_env(extra)
	local bin = tempdir()
	return vim.tbl_extend("force", GIT_ENV, {
		HOME = tempdir(),
		ARCHON = write_stub(bin),
		LOOP_LOG = vim.fs.joinpath(bin, "cleanup.log"),
		ARCHON_RUNS = vim.fs.joinpath(bin, "runs.log"),
		PATH = bin .. ":" .. child.lua_get("vim.env.PATH"),
		MAKEFLAGS = "",
		MAKELEVEL = "",
	}, extra or {})
end

--- Runs `make <args>` in `repo` with `stub_env(env)`.
---@param repo string
---@param args string[]
---@param env? table<string, string>
---@return test.LoopRun
local function run_target(repo, args, env)
	local full = stub_env(env)
	local result = system(vim.list_extend({ "make" }, args), repo, full)
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
	eq({ name, run.code }, { name, 0 }, run.output)
	eq(#run.log >= 2, true, name .. ": cleanup not called\n" .. run.output)
	eq({ name, run.log[1] }, { name, run.log[2] })
	local listed = vim.iter(vim.list_slice(run.log, 3)):any(function(line)
		return vim.trim(line):find("^" .. target.branch) ~= nil
	end)
	eq({ name, listed }, { name, true })
end

T["loop: Cleanup sees the merge the run shipped"] = function()
	vim.iter(TARGETS):each(expect_cleanup_sees_merge)
end

return T
