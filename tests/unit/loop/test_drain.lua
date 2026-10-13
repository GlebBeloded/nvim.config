local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

--- `archon` stub: `workflow run` logs its arguments and prints a run id from the change input;
--- `workflow wait <id>` reports the outcome in $OUTCOMES/<id> (default completed).
local ARCHON_STUB = [[#!/bin/sh
case "$1 $2" in
"workflow run")
	echo "$*" >>"$ARCHON_RUNS"
	for arg; do case $arg in change=*) change=${arg#change=} ;; esac; done
	echo "{\"ok\": true, \"runId\": \"run-$change\"}" ;;
"workflow wait")
	outcome=$(cat "$OUTCOMES/$3" 2>/dev/null || echo completed)
	if [ "$outcome" = paused ]; then
		echo '{"result": "attention", "attention": {"kind": "awaiting_response"}}'
	else
		echo "{\"result\": \"attention\", \"attention\": {\"kind\": \"terminal\", \"status\": \"$outcome\"}}"
	fi ;;
esac
exit 0
]]

--- `openspec` stub: `list --json` lists the directories in openspec/changes/ except archive/.
local OPENSPEC_STUB = [[#!/bin/sh
printf '{"changes":['
sep=
for dir in openspec/changes/*/; do
	name=$(basename "$dir")
	[ "$name" = archive ] || [ ! -d "$dir" ] && continue
	printf '%s{"name":"%s"}' "$sep" "$name"
	sep=,
done
echo ']}'
]]

local SCRIPTS = { "queue_pick.py", "skills_check.py", "drain.py", "blocked.py" }

---@param path string
---@param content string
local function write_executable(path, content)
	child.lua("vim.fn.writefile(vim.split(..., '\\n'), select(2, ...)); vim.uv.fs_chmod(select(2, ...), 493)", {
		content,
		path,
	})
end

---@param path string
---@return string[]
local function read_lines(path)
	return child.lua_get("vim.fn.filereadable(...) == 1 and vim.fn.readfile(...) or {}", { path })
end

--- Repo on branch `auto` with one commit, this checkout's Makefile and the queue scripts.
---@return string
local function make_repo()
	local repo = H.tempdir(child)
	eq(H.system(child, { "git", "init", "-q", "-b", "auto" }, repo, H.GIT_ENV).code, 0)
	eq(H.system(child, { "git", "commit", "-q", "--allow-empty", "-m", "init" }, repo, H.GIT_ENV).code, 0)
	child.lua("vim.uv.fs_symlink(...)", { vim.fs.joinpath(H.root, "Makefile"), vim.fs.joinpath(repo, "Makefile") })
	local scripts = vim.fs.joinpath(repo, ".archon/scripts")
	child.fn.mkdir(scripts, "p")
	for _, script in ipairs(SCRIPTS) do
		child.lua(
			"vim.uv.fs_copyfile(...)",
			{ vim.fs.joinpath(H.root, ".archon/scripts", script), vim.fs.joinpath(scripts, script) }
		)
	end
	return repo
end

--- Active change `name` created on `created`, with `proposal` lines when given.
---@param repo string
---@param name string
---@param created string
---@param proposal? string[]
local function write_change(repo, name, created, proposal)
	local dir = vim.fs.joinpath(repo, "openspec/changes", name)
	child.fn.mkdir(dir, "p")
	child.fn.writefile({ "created: " .. created }, vim.fs.joinpath(dir, ".openspec.yaml"))
	child.fn.writefile(proposal or { "## Why", "w", "", "Kind: bug" }, vim.fs.joinpath(dir, "proposal.md"))
end

---@class test.DrainEnv
---@field env table<string, string>
---@field runs string runs log path
---@field outcomes string directory of per-run outcomes

--- Stubs first on PATH, a temp HOME and no Archon DB; queue inputs cleared.
---@return test.DrainEnv
local function stub_env()
	local bin = H.tempdir(child)
	local outcomes = H.tempdir(child)
	write_executable(vim.fs.joinpath(bin, "archon"), ARCHON_STUB)
	write_executable(vim.fs.joinpath(bin, "openspec"), OPENSPEC_STUB)
	local runs = vim.fs.joinpath(bin, "runs.log")
	local env = vim.tbl_extend("force", H.GIT_ENV, {
		HOME = H.tempdir(child),
		ARCHON = vim.fs.joinpath(bin, "archon"),
		ARCHON_RUNS = runs,
		ARCHON_DB = vim.fs.joinpath(bin, "none.db"),
		OUTCOMES = outcomes,
		PATH = bin .. ":" .. child.lua_get("vim.env.PATH"),
		MAKEFLAGS = "",
		MAKELEVEL = "",
		CHANGE = "",
		INPUTS_CHANGE = "",
		N = "",
	})
	return { env = env, runs = runs, outcomes = outcomes }
end

---@param stubs test.DrainEnv
---@param change string
---@param outcome string
local function set_outcome(stubs, change, outcome)
	child.fn.writefile({ outcome }, vim.fs.joinpath(stubs.outcomes, "run-" .. change))
end

---@param repo string
---@param stubs test.DrainEnv
---@param args? string[]
---@return test.SystemResult
local function drain(repo, stubs, args)
	return H.system(child, vim.list_extend({ "make", "drain" }, args or {}), repo, stubs.env)
end

--- Changes the stub was asked to run, in order (each must be a detached work-queue run).
---@param stubs test.DrainEnv
---@return string[]
local function ran(stubs)
	return vim.tbl_map(function(line)
		eq(line:find("workflow run work-queue --detach --json", 1, true) ~= nil, true, { fail_reason = line })
		return line:match("change=(%S+)")
	end, read_lines(stubs.runs))
end

---@param result test.SystemResult
---@return string
local function output(result)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return result.stdout .. result.stderr
end

T["loop: Drain works queued changes until the queue is empty"] = function()
	local repo, stubs = make_repo(), stub_env()
	write_change(repo, "t-a", "2026-01-01")
	write_change(repo, "t-b", "2026-01-02", { "## Why", "w", "", "## Blocked", "needs a decision" })
	write_change(repo, "t-c", "2026-01-03")
	set_outcome(stubs, "t-a", "failed")
	local out = output(drain(repo, stubs))
	eq(ran(stubs), { "t-a", "t-c" })
	eq(out:find("skip t-b (Blocked)", 1, true) ~= nil, true, { fail_reason = out })
	eq(out:find("t-a failed", 1, true) ~= nil, true, { fail_reason = out })
	eq(out:find("queue is empty", 1, true) ~= nil, true, { fail_reason = out })
end

T["loop: Drain stops after N runs"] = function()
	local repo, stubs = make_repo(), stub_env()
	write_change(repo, "t-a", "2026-01-01")
	write_change(repo, "t-c", "2026-01-03")
	output(drain(repo, stubs, { "N=1" }))
	eq(ran(stubs), { "t-a" })
end

T["loop: Drain stops at a run that waits for the user"] = function()
	local repo, stubs = make_repo(), stub_env()
	write_change(repo, "t-a", "2026-01-01")
	write_change(repo, "t-c", "2026-01-03")
	set_outcome(stubs, "t-a", "paused")
	local out = output(drain(repo, stubs))
	eq(ran(stubs), { "t-a" })
	eq(out:find("t-a waits for you", 1, true) ~= nil, true, { fail_reason = out })
end

---@param repo string
---@param env table<string, string>
---@return string change picked, "" when none
---@return string stderr
local function pick(repo, env)
	local result = H.system(child, { "python3", ".archon/scripts/queue_pick.py" }, repo, env)
	eq(result.code, 0, { fail_reason = result.stderr })
	return vim.json.decode(result.stdout).change, result.stderr
end

T["loop: Queue waits for archived dependencies"] = function()
	local repo, stubs = make_repo(), stub_env()
	write_change(repo, "t-a", "2026-01-01", { "## Why", "w", "", "Kind: bug", "Depends: t-b" })
	write_change(repo, "t-b", "2026-01-02")
	eq(pick(repo, stubs.env), "t-b")
	local named, err = pick(repo, vim.tbl_extend("force", stubs.env, { INPUTS_CHANGE = "t-a" }))
	eq(named, "")
	eq(err:find("t-b", 1, true) ~= nil, true, { fail_reason = err })
	local archive = vim.fs.joinpath(repo, "openspec/changes/archive")
	child.fn.mkdir(archive, "p")
	child.lua("vim.uv.fs_rename(...)", {
		vim.fs.joinpath(repo, "openspec/changes/t-b"),
		vim.fs.joinpath(archive, "2026-01-03-t-b"),
	})
	eq(pick(repo, stubs.env), "t-a")
end

return T
