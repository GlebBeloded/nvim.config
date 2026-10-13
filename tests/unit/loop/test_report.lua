local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

---@class test.ReportFixture
---@field home string
---@field output_root string
---@field repository string
---@field report_path string
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
  ("local", payload["codebase_name"], payload["repository"], "auto"),
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
	local run_id = opts.running and "run-live" or "run-complete"
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

	write_file(vim.fs.joinpath(artifact_root, "root-cause.md"), "root cause " .. hostile_values[6])
	write_file(vim.fs.joinpath(artifact_root, "check-1.log"), "check failed")
	write_file(vim.fs.joinpath(artifact_root, ".archon/secret.txt"), "must not render")
	write_file(vim.fs.joinpath(artifact_root, "ignored.txt"), "must not render")

	local events = {
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

	seed_database(vim.fs.joinpath(home, ".archon/archon.db"), {
		run_id = run_id,
		codebase_name = "project " .. hostile_values[1],
		workflow_name = "fix-bug " .. hostile_values[1],
		user_message = hostile_values[1],
		status = "completed",
		outcome = "succeeded",
		metadata = {
			terminal_graph = {
				node_ids = { "skills-check", "deliver__build.implement", "deliver__build.gate", "deliver__ship" },
			},
		},
		started_at = "2026-10-13T10:00:00Z",
		completed_at = "2026-10-13T10:10:00Z",
		last_activity_at = "2026-10-13T10:10:00Z",
		repository = repository,
		output_root = output_root,
		events = events,
	})

	return {
		home = home,
		output_root = output_root,
		repository = repository,
		report_path = vim.fs.joinpath(artifact_root, "report.html"),
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
	return H.system(child, command, H.root, {
		HOME = fixture.home,
		PATH = child.lua_get("vim.env.PATH"),
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

return T
