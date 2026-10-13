# Loop Run Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a safe, self-contained HTML summary of one persisted Archon run and link the latest project report from `make loop-status`.

**Architecture:** A dependency-free Python script reads one SQLite snapshot, folds ordered lifecycle events into report models, joins retained artifact and Git evidence, and atomically replaces `report.html`. Make remains a thin command wrapper; mini.test drives disposable databases, artifact trees and Git repositories through `vim.system`.

**Tech Stack:** Python 3 standard library (`argparse`, `dataclasses`, `datetime`, `html`, `json`, `pathlib`, `sqlite3`, `subprocess`, `tempfile`), GNU Make, Git, Neovim Lua, mini.test, OpenSpec.

**Spec:** `openspec/changes/fix-loop-run-report/` (`proposal.md`, `design.md`, and `specs/loop/spec.md`), with approval feedback: "Approved per policy: no visible Neovim UI or core keymap change."

## Global Constraints

- Add, remove or upgrade no plugin or package dependency; the generator uses only the Python standard library and existing Git.
- Change no Neovim UI and no core keymap.
- Open `~/.archon/archon.db` with SQLite URI read-only mode and use parameterized SQL inside one read transaction.
- Treat every database, artifact and Git value as untrusted text and HTML-escape it; emit inline CSS only, with no external asset dependency.
- Write `<output_root>/artifacts/runs/<id>/report.html` through a temporary sibling followed by atomic replacement.
- Explicit `RUN=<id>` uses that run's `output_root`; implicit selection is scoped by Git common directory and ordered by `started_at`, then id.
- Preserve the existing `loop-status` calls to `workflow status` and `workflow runs --limit 10`, then generate the report.
- Missing evidence is `Pending` for a live run and `Unavailable` for terminal history; never infer an outcome.
- Embed only `root-cause.md`, `escalation.md`, `check-N.log`, `validate-N.log` and `archive-N.log`; exclude `report.html` and internal `.archon/` content.
- Do not serve, auto-refresh or build a cross-project dashboard, change Archon's schema/contracts, or reconstruct deleted evidence.
- Never delete or weaken a test or scenario to get green; `make check` is the final gate.

## Review Focus

- HTML/script text in run fields, gate comments, failures, artifacts or Git output → Task 1 asserts escaped text and the absence of executable/external markup.
- Repeated loop invocations and `node_skipped_prior_success` after resume → Task 1 asserts one canonical row, the correct invocation count and no lost/double-counted completion.
- Deleted artifact or unavailable recorded merge commit in terminal history → Task 1 asserts `Unavailable` while the rest of the report still renders.
- Started-but-unfinished node and absent gate/check/ship data → Task 2 asserts an elapsed `running` row and `Pending`, with no invented terminal result.
- Equal timestamps, a newer foreign run, or a stale registered worktree → Task 3 asserts deterministic local selection by common Git directory and a concise diagnostic when no registration resolves.

## File Structure

- Create `.archon/scripts/loop_report.py`: CLI, read-only SQLite loading, event folding, evidence collection, HTML rendering and atomic output.
- Create `tests/unit/loop/test_report.lua`: shared disposable fixture builders and the four scenario-named mini.test cases.
- Modify `Makefile`: add `loop-report`; append it to `loop-status` without changing the two existing Archon invocations.
- Modify `docs/workflow.md`: document the operator commands and generated artifact only; do not duplicate parser logic.

---

### Task 1: Named completed run report

Scenarios: "loop: Named run report contains the complete run history".

**Files:**
- Create: `tests/unit/loop/test_report.lua`
- Create: `.archon/scripts/loop_report.py`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `H.new_child()`, `H.child_set(child, child.start_bare)`, `H.tempdir(child)`, `H.system(child, cmd, cwd, env)` and `H.GIT_ENV` from `tests/helpers.lua`; Archon columns in `remote_agent_codebases`, `remote_agent_workflow_runs` and `remote_agent_workflow_events` (`data` JSON ordered by `event_order`).
- Produces: test helpers `make_fixture(opts) -> test.ReportFixture`, `run_report(fixture, run_id?) -> test.SystemResult`, `read_report(fixture, run_id) -> string`, and `expect_all_escaped(report, values)`; Python models `RunRecord`, `EventRecord`, `NodeRow`, `GateRecord`, `AttemptRecord`, `ArtifactRecord`, `ShipRecord`, `Report`; CLI `main(argv: Sequence[str] | None = None) -> int` and `--run ID`.

- [x] **Step 1: Write the failing mini.test case `loop: Named run report contains the complete run history`**

  In a bare child, build a temporary `HOME/.archon/archon.db` (chmod `0444` after seeding), `<output_root>/artifacts/runs/run-complete/`, and Git repository with a real two-parent merge. Seed terminal-graph nodes plus completed, failed, repeated and `node_skipped_prior_success` lifecycle events; FIFO approval/rejection pairs using `comment` and `reason`; two structured gate/verdict attempts; recognized artifacts; a final successful `shipped` output; and a distinct hostile HTML value in every external source class.

  ```lua
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
  ```

  Run: `make test FILE=tests/unit/loop/test_report.lua CASE="loop: Named run report contains the complete run history" JOBS=1`

  Expected: FAIL because `make loop-report` does not exist.

- [x] **Step 2: Add the read-only loader and named-run CLI**

  In `.archon/scripts/loop_report.py`, add typed small functions `database_path(home: Path) -> Path`, `open_database(path: Path) -> sqlite3.Connection`, `load_named_run(connection, run_id: str) -> RunRecord`, `load_events(connection, run_id: str) -> list[EventRecord]`, and `parse_json_object(raw: str) -> dict[str, object]`. Open with `file:<quoted-path>?mode=ro`, start one read transaction, order events by `event_order`, tolerate unknown JSON fields, and return concise stderr/exit-2 diagnostics for a missing database or unknown id without traceback.

  Add `loop-report` to `.PHONY` and invoke `python3 .archon/scripts/loop_report.py --run "$(RUN)"` when `RUN` is non-empty. Do not modify `loop-status` yet.

  Run the focused case. Expected: it advances past target/selection failure and fails on missing report content.

- [x] **Step 3: Fold nodes, gates and attempts**

  Add `fold_nodes(run: RunRecord, events: Sequence[EventRecord], now: datetime) -> list[NodeRow]`, `fold_gates(events) -> list[GateRecord]`, and `fold_attempts(events) -> list[AttemptRecord]`. Seed terminal-graph ids, append observed nested ids in first-event order, key invocations by their event `invocation.id`, sum terminal `duration_ms`, preserve completed state on `node_skipped_prior_success`, pair each approval request with the next approval response, and take attempt number/exact failures from completed gate/verdict `structured_output` before consulting logs.

  Run the focused case. Expected: it reaches artifact/ship/render assertions; repeated nodes already produce one row with the expected count.

- [x] **Step 4: Collect retained evidence and render atomically**

  Add `load_artifacts(run: RunRecord) -> list[ArtifactRecord]`, `load_ship(run: RunRecord, events: Sequence[EventRecord]) -> ShipRecord`, `build_report(run, events, now) -> Report`, `render_html(report: Report) -> str`, `write_atomic(path: Path, content: str) -> None`, and `summary_lines(report, report_path) -> tuple[str, str]`. Resolve the final successful `shipped`/`ship` merge hash in the registered repository and run `git diff --stat <commit>^1 <commit>` with an argument list. Escape at final rendering boundaries; use semantic tables plus collapsed `<details>` artifacts, inline CSS, no JavaScript, and print exactly one compact identity/counts/merge line followed by `Report: <file URI>`.

  Run the focused case. Expected: PASS, including missing terminal evidence rendered as `Unavailable` and hostile source text rendered inert.

- [x] **Step 5: Commit the named-report slice**

  ```bash
  git add .archon/scripts/loop_report.py tests/unit/loop/test_report.lua Makefile
  git commit -m "feat(loop): report completed run evidence"
  ```

### Task 2: Running run with incomplete evidence

Scenarios: "loop: Running run report tolerates incomplete evidence".

**Files:**
- Modify: `tests/unit/loop/test_report.lua`
- Modify: `.archon/scripts/loop_report.py`

**Interfaces:**
- Consumes: Task 1's fixture helpers and `fold_nodes`, `build_report`, `render_html`, `write_atomic` interfaces.
- Produces: live-node states `running` and `waiting`; outcome-sensitive evidence state helper `missing_label(run: RunRecord) -> Literal["Pending", "Unavailable"]`.

- [ ] **Step 1: Write the failing mini.test case `loop: Running run report tolerates incomplete evidence`**

  Seed a running run with one `node_started` event whose `timing.startedAt` has no terminal event, one seeded-but-not-started terminal-graph node, and no approvals, attempts, artifacts or ship output.

  ```lua
  T["loop: Running run report tolerates incomplete evidence"] = function()
  	local fixture = make_fixture({ running = true })
  	local result = run_report(fixture, "run-live")
  	local report = read_report(fixture, "run-live")

  	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
  	expect_contains(report, "running")
  	expect_match(report, "%d+%.%d+s")
  	expect_contains(report, "waiting")
  	eq(count(report, "Pending") >= 2, true)
  	eq(report:find("completed", 1, true), nil)
  	eq(report:find("Unavailable", 1, true), nil)
  end
  ```

  Run: `make test FILE=tests/unit/loop/test_report.lua CASE="loop: Running run report tolerates incomplete evidence" JOBS=1`

  Expected: FAIL because Task 1 renders missing evidence as terminal `Unavailable` and does not calculate live elapsed state.

- [ ] **Step 2: Add live-state folding without inventing results**

  Make `fold_nodes` calculate elapsed milliseconds from `timing.startedAt` to the captured `now` for an unterminated invocation and label seeded unstarted nodes `waiting`. Use `missing_label` in gate/attempt/ship sections so live absence is `Pending`; keep terminal absence `Unavailable`. Capture `now` once per report so all durations use one snapshot.

  Run the focused case. Expected: PASS.

- [ ] **Step 3: Verify both named-run cases and commit**

  Run: `make test FILE=tests/unit/loop/test_report.lua CASE="loop: (Named run report|Running run report)" JOBS=1`

  Expected: 2 PASS.

  ```bash
  git add .archon/scripts/loop_report.py tests/unit/loop/test_report.lua
  git commit -m "fix(loop): report incomplete running state"
  ```

### Task 3: Project-scoped latest-run selection

Scenarios: "loop: Report without a run selects the latest run for this codebase".

**Files:**
- Modify: `tests/unit/loop/test_report.lua`
- Modify: `.archon/scripts/loop_report.py`
- Modify: `Makefile`

**Interfaces:**
- Consumes: Task 1's `RunRecord`, report pipeline and fixture helpers; Git `rev-parse --path-format=absolute --git-common-dir`.
- Produces: `git_common_dir(path: Path) -> Path`, `resolve_codebase(connection, cwd: Path) -> str`, and `load_latest_run(connection, codebase_id: str) -> RunRecord`.

- [ ] **Step 1: Write the failing mini.test case `loop: Report without a run selects the latest run for this codebase`**

  Register the fixture's main checkout and a linked worktree through the same absolute common Git directory. Seed older `local-old`, equal-time `local-a`/`local-b`, and later `foreign-new` runs; make `local-b` the deterministic local winner by id. Use a second fixture whose registered `default_cwd` was removed to exercise the diagnostic path.

  ```lua
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
  ```

  Run: `make test FILE=tests/unit/loop/test_report.lua CASE="loop: Report without a run selects the latest run for this codebase" JOBS=1`

  Expected: FAIL because the Make target always passes an empty `--run` and the script has no implicit selector.

- [ ] **Step 2: Resolve the registered codebase and select its latest run**

  For the invocation cwd and every registered `default_cwd`, call Git with argument arrays and normalize the absolute common directory; do not require the worktree path itself to match. Select only that `codebase_id`, ordered `started_at DESC, id DESC`. Add concise exit-2 diagnostics for no matching registration and no run. Update `loop-report` so it omits `--run` when `RUN` is empty.

  Run the focused case. Expected: PASS.

- [ ] **Step 3: Verify all report-selection cases and commit**

  Run: `make test FILE=tests/unit/loop/test_report.lua JOBS=1`

  Expected: the first three scenario cases PASS.

  ```bash
  git add .archon/scripts/loop_report.py tests/unit/loop/test_report.lua Makefile
  git commit -m "feat(loop): select latest project run"
  ```

### Task 4: Loop status report link and operator docs

Scenarios: "loop: Loop status prints a usable report link".

**Files:**
- Modify: `tests/unit/loop/test_report.lua`
- Modify: `Makefile`
- Modify: `docs/workflow.md`

**Interfaces:**
- Consumes: Task 3's no-argument `loop-report` target and fixture; existing `ARCHON ?= archon` Make interface.
- Produces: `loop-status` output ending in Task 1's `Report: <file URI>` line; operator documentation for `make loop-report [RUN=<id>]` and `make loop-status`.

- [ ] **Step 1: Write the failing mini.test case `loop: Loop status prints a usable report link`**

  Put an executable `ARCHON` logging stub in the fixture, run `make loop-status` with the fixture `HOME`, and assert exact preserved argument order plus the generated file URI.

  ```lua
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
  ```

  Run: `make test FILE=tests/unit/loop/test_report.lua CASE="loop: Loop status prints a usable report link" JOBS=1`

  Expected: FAIL because `loop-status` does not invoke `loop-report` and no report file/link exists.

- [ ] **Step 2: Append report generation to `loop-status`**

  Keep `$(ARCHON) workflow status` and `$(ARCHON) workflow runs --limit 10` unchanged and ordered, then call the existing `loop-report` recipe through `$(MAKE) -s loop-report` so its two summary lines remain visible.

  Run the focused case. Expected: PASS.

- [ ] **Step 3: Document the operator surface**

  In the existing loop command/observability sections of `docs/workflow.md`, add `make loop-report [RUN=<id>]`, its `<output_root>/artifacts/runs/<id>/report.html` output, and that `make loop-status` prints the latest report's local URI. Do not document internal SQL, event fields or rendering functions.

  Run: `rg -n 'loop-report|report\.html' docs/workflow.md Makefile`

  Expected: both operator entry points and the generated artifact are found.

- [ ] **Step 4: Run focused and project gates**

  Run in order:

  ```bash
  make fmt
  make test FILE=tests/unit/loop/test_report.lua JOBS=1
  openspec validate fix-loop-run-report --strict --no-interactive
  make quick
  make check
  ```

  Expected: all four scenario cases PASS, OpenSpec reports the change valid, trace has no orphan, and every project gate is green.

- [ ] **Step 5: Commit the status/docs slice**

  ```bash
  git add Makefile docs/workflow.md tests/unit/loop/test_report.lua
  git commit -m "feat(loop): link reports from loop status"
  ```
