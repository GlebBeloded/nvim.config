local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

---@class test.ReportFixture
---@field home string
---@field output_root string
---@field repository string
---@field invocation_cwd? string
---@field report_path string
---@field latest_report_path? string
---@field foreign_report_path? string
---@field archon? string
---@field archon_log? string
---@field merge_commit string
---@field hostile_values string[]

---@param value string
---@return string
local function html_escape(value)
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#x27;"))
end

---@param haystack string
---@param needle string
local function expect_contains(haystack, needle)
	eq(haystack:find(needle, 1, true) ~= nil, true, { fail_reason = ("missing %q in:\n%s"):format(needle, haystack) })
end

---@param haystack string
---@param pattern string
local function expect_match(haystack, pattern)
	eq(haystack:find(pattern) ~= nil, true, { fail_reason = ("missing /%s/ in:\n%s"):format(pattern, haystack) })
end

---@param haystack string
---@param needle string
---@return integer
local function count(haystack, needle)
	local total, start = 0, 1
	while true do
		local found = haystack:find(needle, start, true)
		if not found then
			return total
		end
		total, start = total + 1, found + #needle
	end
end

---@param path string
---@param content string
local function write_file(path, content)
	child.lua(
		[[local path, content = ...
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)]],
		{ path, content }
	)
end

---@param target string
---@param link string
local function symlink(target, link)
	child.lua("vim.fn.mkdir(vim.fs.dirname(select(2, ...)), 'p'); assert(vim.uv.fs_symlink(...))", { target, link })
end

---@param path string
---@param content string
local function write_executable(path, content)
	write_file(path, content)
	child.lua("assert(vim.uv.fs_chmod(..., 493))", { path })
end

---@param args string[]
---@param cwd string
---@return test.SystemResult
local function git(args, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, args), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = table.concat(args, " ") .. "\n" .. result.stderr })
	return result
end

---@return string, string
local function make_repository()
	local repository = H.tempdir(child)
	git({ "init", "-q", "-b", "auto" }, repository)
	write_file(vim.fs.joinpath(repository, "base.txt"), "base")
	git({ "add", "-A" }, repository)
	git({ "commit", "-q", "-m", "base" }, repository)
	git({ "checkout", "-q", "-b", "report-change" }, repository)
	write_file(vim.fs.joinpath(repository, "changed.txt"), "changed")
	write_file(vim.fs.joinpath(repository, "git-<unsafe&>.txt"), "unsafe git value")
	git({ "add", "-A" }, repository)
	git({ "commit", "-q", "-m", "report change" }, repository)
	git({ "checkout", "-q", "auto" }, repository)
	write_file(vim.fs.joinpath(repository, "auto.txt"), "auto")
	git({ "add", "-A" }, repository)
	git({ "commit", "-q", "-m", "auto change" }, repository)
	git({ "merge", "-q", "--no-ff", "-m", "merge report change", "report-change" }, repository)
	local merge_commit = vim.trim(git({ "rev-parse", "HEAD" }, repository).stdout)
	eq(vim.trim(git({ "rev-list", "--parents", "-n", "1", merge_commit }, repository).stdout):find(" ") ~= nil, true)
	return repository, merge_commit
end

---@param name string
---@param invocation string
---@param duration? integer
---@param extra? table<string, any>
---@return table<string, any>
local function node_data(name, invocation, duration, extra)
	local data = {
		node = { id = name },
		invocation = { id = invocation, startedAt = "2026-10-13T10:00:00Z", loopPath = {} },
		timing = { startedAt = "2026-10-13T10:00:00Z", durationMs = duration },
		duration_ms = duration,
	}
	return vim.tbl_deep_extend("force", data, extra or {})
end

---@param database string
---@param payload table<string, any>
local function seed_database(database, payload)
	local script = [[
import json, pathlib, sqlite3, sys
database, payload = pathlib.Path(sys.argv[1]), json.loads(sys.argv[2])
database.parent.mkdir(parents=True, exist_ok=True)
connection = sqlite3.connect(database)
connection.executescript("""
CREATE TABLE remote_agent_codebases (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, repository_url TEXT,
  default_cwd TEXT NOT NULL, default_branch TEXT, kind TEXT DEFAULT 'repo'
);
CREATE TABLE remote_agent_workflow_runs (
  id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, codebase_id TEXT,
  workflow_name TEXT NOT NULL, user_message TEXT NOT NULL, status TEXT NOT NULL,
  outcome TEXT, current_step_index INTEGER, metadata TEXT DEFAULT '{}',
  started_at TEXT, completed_at TEXT, last_activity_at TEXT,
  working_path TEXT, output_root TEXT, checkout_baseline TEXT
);
CREATE TABLE remote_agent_workflow_events (
  id TEXT PRIMARY KEY, workflow_run_id TEXT NOT NULL, event_order INTEGER,
  event_type TEXT NOT NULL, step_index INTEGER, step_name TEXT,
  data TEXT DEFAULT '{}', created_at TEXT
);
""")
connection.execute(
  "INSERT INTO remote_agent_codebases (id, name, default_cwd, default_branch) VALUES (?, ?, ?, ?)",
  ("local", payload["codebase_name"], payload.get("default_cwd", payload["repository"]), "auto"),
)
for codebase in payload.get("extra_codebases", []):
  connection.execute(
    "INSERT INTO remote_agent_codebases (id, name, default_cwd, default_branch) VALUES (?, ?, ?, ?)",
    (codebase["id"], codebase["name"], codebase["default_cwd"], "auto"),
  )
connection.execute(
  """INSERT INTO remote_agent_workflow_runs
  (id, conversation_id, codebase_id, workflow_name, user_message, status, outcome,
   metadata, started_at, completed_at, last_activity_at, working_path, output_root)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
  (payload["run_id"], "conversation", "local", payload["workflow_name"], payload["user_message"],
   payload["status"], payload.get("outcome"), json.dumps(payload["metadata"]),
   payload["started_at"], payload.get("completed_at"), payload["last_activity_at"],
   payload["repository"], payload["output_root"]),
)
for order, event in enumerate(payload["events"], 1):
  connection.execute(
    """INSERT INTO remote_agent_workflow_events
    (id, workflow_run_id, event_order, event_type, step_name, data, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)""",
    (f"event-{order}", payload["run_id"], order, event["event_type"],
     event.get("step_name"), json.dumps(event.get("data", {})), event.get("created_at", payload["started_at"])),
  )
for run in payload.get("extra_runs", []):
  connection.execute(
    """INSERT INTO remote_agent_workflow_runs
    (id, conversation_id, codebase_id, workflow_name, user_message, status, outcome,
     metadata, started_at, completed_at, last_activity_at, working_path, output_root)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
    (run["id"], "conversation", run["codebase_id"], "fix-bug", run["id"], "completed", "succeeded",
     json.dumps({"terminal_graph": {"node_ids": []}}), run["started_at"], run["started_at"],
     run["started_at"], run["working_path"], run["output_root"]),
  )
connection.commit()
connection.close()
database.chmod(0o444)
]]
	local result = H.system(child, { "python3", "-c", script, database, vim.json.encode(payload) }, H.root)
	eq(result.code, 0, { fail_reason = result.stderr })
end

---@param opts table<string, any>
---@return test.ReportFixture
local function make_fixture(opts)
	local home = H.tempdir(child)
	local output_root = H.tempdir(child)
	local repository, merge_commit = make_repository()
	local run_id = opts.cancelled and "run-cancelled" or (opts.running and "run-live" or "run-complete")
	local artifact_root = vim.fs.joinpath(output_root, "artifacts/runs", run_id)
	local hostile_values = {
		"<run&unsafe>",
		"<node&unsafe>",
		"<gate&unsafe>",
		"<decision&unsafe>",
		"<failure&unsafe>",
		"<artifact&unsafe>",
		"git-<unsafe&>.txt",
	}

	if not opts.running and not opts.cancelled then
		write_file(vim.fs.joinpath(artifact_root, "root-cause.md"), "root cause " .. hostile_values[6])
		write_file(vim.fs.joinpath(artifact_root, "check-1.log"), "check failed")
		write_file(vim.fs.joinpath(artifact_root, ".archon/secret.txt"), "must not render")
		write_file(vim.fs.joinpath(artifact_root, "ignored.txt"), "must not render")
	end

	local completed_events = {
		{ event_type = "node_started", step_name = "skills-check", data = node_data("skills-check", "skills-1") },
		{
			event_type = "node_completed",
			step_name = "skills-check",
			data = node_data("skills-check", "skills-1", 900),
		},
		{
			event_type = "node_started",
			step_name = "deliver__build.implement",
			data = node_data("implement", "implement-1"),
		},
		{
			event_type = "node_failed",
			step_name = "deliver__build.implement",
			data = node_data("implement", "implement-1", 1200),
		},
		{
			event_type = "node_started",
			step_name = "deliver__build.implement",
			data = node_data("implement", "implement-2"),
		},
		{
			event_type = "node_completed",
			step_name = "deliver__build.implement",
			data = node_data("implement", "implement-2", 2300),
		},
		{
			event_type = "node_skipped_prior_success",
			step_name = "deliver__build.implement",
			data = { node = { id = "implement" }, reason = "prior_success" },
		},
		{
			event_type = "node_skipped",
			step_name = "preview",
			data = { node = { id = "preview" }, reason = "condition", duration_ms = 50 },
		},
		{
			event_type = "node_started",
			step_name = hostile_values[2],
			data = node_data(hostile_values[2], "hostile-node"),
		},
		{
			event_type = "node_completed",
			step_name = hostile_values[2],
			data = node_data(hostile_values[2], "hostile-node", 100),
		},
		{ event_type = "approval_requested", step_name = "design-gate", data = { message = hostile_values[3] } },
		{
			event_type = "approval_received",
			step_name = "design-gate",
			data = { decision = "approved", comment = "approved by operator " .. hostile_values[4] },
		},
		{ event_type = "approval_requested", step_name = "ship-gate", data = { message = "Ship approval" } },
		{
			event_type = "approval_received",
			step_name = "ship-gate",
			data = { decision = "rejected", reason = "rejected by operator" },
		},
		{
			event_type = "node_completed",
			step_name = "deliver__build.gate",
			data = node_data("gate", "gate-1", 500, {
				structured_output = {
					green = false,
					attempt = 1,
					failures = "tasks.md has unchecked tasks " .. hostile_values[5],
				},
			}),
		},
		{
			event_type = "node_completed",
			step_name = "deliver__build.verdict",
			data = node_data("verdict", "verdict-1", 100, {
				structured_output = { passed = false, attempt = 1, failed_gates = "tasks" },
			}),
		},
		{ event_type = "node_started", step_name = "repeat-failed", data = node_data("repeat-failed", "repeat-1") },
		{
			event_type = "node_completed",
			step_name = "repeat-failed",
			data = node_data("repeat-failed", "repeat-1", 100),
		},
		{ event_type = "node_started", step_name = "repeat-failed", data = node_data("repeat-failed", "repeat-2") },
		{
			event_type = "node_failed",
			step_name = "repeat-failed",
			data = node_data("repeat-failed", "repeat-2", 200),
		},
		{
			event_type = "node_completed",
			step_name = "deliver__build.gate",
			data = node_data("gate", "gate-2", 600, {
				structured_output = { green = true, attempt = 2, failures = "" },
			}),
		},
		{
			event_type = "node_completed",
			step_name = "deliver__ship",
			data = node_data("deliver__ship", "ship-1", 700, {
				structured_output = { merged = true, conflict = false, commit = merge_commit },
			}),
		},
	}
	local events = completed_events
	local terminal_nodes = {
		"skills-check",
		"deliver__build.implement",
		"deliver__build.gate",
		"repeat-failed",
		"preview",
		"deliver__ship",
	}
	if opts.running or opts.cancelled then
		events = {
			{
				event_type = "node_started",
				step_name = "live-node",
				data = node_data("live-node", "live-1"),
			},
		}
		if opts.pending_gate then
			vim.list_extend(events, {
				{
					event_type = "approval_requested",
					step_name = "first-gate",
					data = { message = "First approval" },
				},
				{
					event_type = "approval_received",
					step_name = "first-gate",
					data = { decision = "approved", comment = "approved" },
				},
				{
					event_type = "approval_requested",
					step_name = "pending-gate",
					data = { message = "Waiting for operator" },
				},
			})
		end
		terminal_nodes = { "live-node", "waiting-node" }
	end

	local invocation_cwd
	local default_cwd = repository
	local extra_codebases = {}
	local extra_runs = {}
	local foreign_report_path
	if opts.multiple_codebases or opts.stale_registration or opts.archon_stub then
		invocation_cwd = vim.fs.joinpath(H.tempdir(child), "linked")
		git({ "worktree", "add", "-q", "-b", "report-linked", invocation_cwd, "auto" }, repository)
		symlink(vim.fs.joinpath(H.root, "Makefile"), vim.fs.joinpath(invocation_cwd, "Makefile"))
		symlink(
			vim.fs.joinpath(H.root, ".archon/scripts/loop_report.py"),
			vim.fs.joinpath(invocation_cwd, ".archon/scripts/loop_report.py")
		)
	end
	if opts.multiple_codebases then
		local foreign = H.tempdir(child)
		git({ "init", "-q", "-b", "auto" }, foreign)
		git({ "commit", "-q", "--allow-empty", "-m", "foreign" }, foreign)
		extra_codebases = { { id = "foreign", name = "foreign", default_cwd = foreign } }
		extra_runs = {
			{
				id = "local-old",
				codebase_id = "local",
				started_at = "2026-10-13T09:00:00Z",
				working_path = repository,
				output_root = output_root,
			},
			{
				id = "local-a",
				codebase_id = "local",
				started_at = "2026-10-13T11:00:00Z",
				working_path = repository,
				output_root = output_root,
			},
			{
				id = "local-b",
				codebase_id = "local",
				started_at = "2026-10-13T11:00:00Z",
				working_path = repository,
				output_root = output_root,
			},
			{
				id = "foreign-new",
				codebase_id = "foreign",
				started_at = "2026-10-13T12:00:00Z",
				working_path = foreign,
				output_root = output_root,
			},
		}
		foreign_report_path = vim.fs.joinpath(output_root, "artifacts/runs/foreign-new/report.html")
	elseif opts.stale_registration then
		default_cwd = vim.fs.joinpath(H.tempdir(child), "removed-registration")
		child.fn.delete(default_cwd, "rf")
	end
	local archon
	local archon_log
	if opts.archon_stub then
		local bin = H.tempdir(child)
		archon = vim.fs.joinpath(bin, "archon")
		archon_log = vim.fs.joinpath(bin, "archon.log")
		write_executable(archon, '#!/bin/sh\necho "$*" >> "$ARCHON_LOG"')
	end

	seed_database(vim.fs.joinpath(home, ".archon/archon.db"), {
		run_id = run_id,
		codebase_name = "project " .. hostile_values[1],
		workflow_name = "fix-bug " .. hostile_values[1],
		user_message = hostile_values[1],
		status = opts.cancelled and "cancelled" or (opts.running and "running" or "completed"),
		outcome = (opts.running or opts.cancelled) and nil or "succeeded",
		metadata = {
			terminal_graph = {
				node_ids = terminal_nodes,
			},
		},
		started_at = "2026-10-13T10:00:00Z",
		completed_at = opts.running and nil or (opts.cancelled and "2026-10-13T10:00:10Z" or "2026-10-13T10:10:00Z"),
		last_activity_at = (opts.running or opts.cancelled) and "2026-10-13T10:00:10Z" or "2026-10-13T10:10:00Z",
		repository = repository,
		default_cwd = default_cwd,
		output_root = output_root,
		events = events,
		extra_codebases = extra_codebases,
		extra_runs = extra_runs,
	})

	return {
		home = home,
		output_root = output_root,
		repository = repository,
		invocation_cwd = invocation_cwd,
		report_path = vim.fs.joinpath(artifact_root, "report.html"),
		latest_report_path = opts.multiple_codebases
				and vim.fs.joinpath(output_root, "artifacts/runs/local-b/report.html")
			or vim.fs.joinpath(artifact_root, "report.html"),
		foreign_report_path = foreign_report_path,
		archon = archon,
		archon_log = archon_log,
		merge_commit = merge_commit,
		hostile_values = hostile_values,
	}
end

---@param fixture test.ReportFixture
---@param run_id? string
---@return test.SystemResult
local function run_report(fixture, run_id)
	local command = { "make", "-s", "loop-report" }
	if run_id then
		table.insert(command, "RUN=" .. run_id)
	end
	return H.system(child, command, fixture.invocation_cwd or H.root, {
		HOME = fixture.home,
		PATH = child.lua_get("vim.env.PATH"),
		MAKEFLAGS = "",
		MAKELEVEL = "",
	})
end

---@param path string
---@return boolean
local function file_exists(path)
	return child.lua_get("vim.uv.fs_stat(...) ~= nil", { path })
end

---@param path string
---@return string[]
local function read_lines(path)
	return child.lua_get("vim.fn.filereadable(...) == 1 and vim.fn.readfile(...) or {}", { path })
end

---@param fixture test.ReportFixture
---@return test.SystemResult
local function run_status(fixture)
	return H.system(child, { "make", "-s", "loop-status", "ARCHON=" .. fixture.archon }, fixture.invocation_cwd, {
		HOME = fixture.home,
		PATH = child.lua_get("vim.env.PATH"),
		ARCHON_LOG = fixture.archon_log,
		MAKEFLAGS = "",
		MAKELEVEL = "",
	})
end

---@param fixture test.ReportFixture
---@param run_id string
---@return string
local function read_report(fixture, run_id)
	local path = vim.fs.joinpath(fixture.output_root, "artifacts/runs", run_id, "report.html")
	return child.lua_get(
		"vim.fn.filereadable(...) == 1 and table.concat(vim.fn.readfile(...), string.char(10)) or ''",
		{ path }
	)
end

---@param report string
---@param values string[]
local function expect_all_escaped(report, values)
	for _, value in ipairs(values) do
		eq(report:find(value, 1, true), nil, { fail_reason = "unescaped value: " .. value })
		expect_contains(report, html_escape(value))
	end
end

T["loop: Named run report contains the complete run history"] = function()
	local fixture = make_fixture({ completed = true, missing_terminal_evidence = true })
	local result = run_report(fixture, "run-complete")
	local report = read_report(fixture, "run-complete")

	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	expect_contains(result.stdout, "run-complete")
	expect_contains(result.stdout, "completed")
	expect_contains(result.stdout, vim.uri_from_fname(fixture.report_path))
	eq(count(report, "deliver__build.implement"), 1)
	expect_contains(report, "2 invocations")
	expect_contains(report, "<td>repeat-failed</td><td>failed</td><td>2 invocations</td>")
	expect_contains(report, "<td>preview</td><td>skipped</td><td>0 invocations</td>")
	expect_contains(report, "approved by operator")
	expect_contains(report, "rejected by operator")
	expect_contains(report, "Attempt 1")
	expect_contains(report, "tasks.md has unchecked tasks")
	expect_contains(report, "Attempt 2")
	expect_contains(report, "root-cause.md")
	expect_contains(report, fixture.merge_commit)
	expect_contains(report, "changed.txt")
	expect_contains(report, "Unavailable")
	expect_all_escaped(report, fixture.hostile_values)
	eq(report:find("<script", 1, true), nil)
	eq(report:find("http://", 1, true), nil)
	eq(report:find("https://", 1, true), nil)

	local unknown = run_report(fixture, "missing-run")
	eq(unknown.code, 2)
	expect_contains(unknown.stderr, "Unknown Archon run: missing-run")
	eq(unknown.stderr:find("Traceback", 1, true), nil)
end

T["loop: Running run report tolerates incomplete evidence"] = function()
	local fixture = make_fixture({ running = true })
	local result = run_report(fixture, "run-live")
	local report = read_report(fixture, "run-live")

	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	expect_contains(report, "running")
	expect_match(report, "running</td><td>1 invocation</td><td>[1-9]%d*%.%ds")
	expect_contains(report, "waiting")
	eq(count(report, "Pending") >= 2, true)
	eq(report:find("completed", 1, true), nil)
	eq(report:find("Unavailable", 1, true), nil)

	local cancelled = make_fixture({ cancelled = true })
	local cancelled_result = run_report(cancelled, "run-cancelled")
	local cancelled_report = read_report(cancelled, "run-cancelled")
	eq(cancelled_result.code, 0, { fail_reason = cancelled_result.stdout .. cancelled_result.stderr })
	expect_contains(cancelled_report, "<td>live-node</td><td>cancelled</td><td>1 invocation</td><td>10.0s</td>")

	local pending = make_fixture({ running = true, pending_gate = true })
	local pending_result = run_report(pending, "run-live")
	local pending_report = read_report(pending, "run-live")
	eq(pending_result.code, 0, { fail_reason = pending_result.stdout .. pending_result.stderr })
	expect_contains(pending_report, "pending-gate")
	expect_contains(pending_report, "Waiting for operator")
end

T["loop: Report without a run selects the latest run for this codebase"] = function()
	local fixture = make_fixture({ multiple_codebases = true, equal_local_times = true })
	local result = run_report(fixture)

	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	expect_contains(result.stdout, "local-b")
	expect_contains(result.stdout, vim.uri_from_fname(fixture.latest_report_path))
	eq(file_exists(fixture.latest_report_path), true)
	eq(file_exists(fixture.foreign_report_path), false)

	local stale = make_fixture({ stale_registration = true })
	local missing = run_report(stale)
	eq(missing.code, 2)
	expect_contains(missing.stderr, "No Archon codebase matches")
	eq(missing.stderr:find("Traceback", 1, true), nil)
end

T["loop: Loop status prints a usable report link"] = function()
	local fixture = make_fixture({ archon_stub = true })
	local result = run_status(fixture)

	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read_lines(fixture.archon_log), {
		"workflow status",
		"workflow runs --limit 10",
	})
	eq(file_exists(fixture.latest_report_path), true)
	expect_contains(result.stdout, vim.uri_from_fname(fixture.latest_report_path))
end

return T
