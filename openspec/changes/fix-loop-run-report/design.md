# Design

## Context

See `proposal.md` — Why. Archon persists run identity in `remote_agent_workflow_runs` and ordered lifecycle, approval and node-output events in `remote_agent_workflow_events`. The loop separately writes human artifacts under each run's `output_root/artifacts/runs/<id>/`; a successful ship event records the merge commit, from which Git can derive the final stat. Runs may still be active, may be resumed, and may lack any later artifact.

The report is visible UI, but it is a generated local browser page rather than Neovim UI. Color is not an acceptance criterion, so the renders have no highlight mask.

## Goals / Non-Goals

**Goals:**

- Produce the same useful summary for completed, failed, cancelled, rejected and running runs.
- Preserve enough source evidence to understand a run without switching among the console, files and Git.
- Keep generation local, deterministic, dependency-free and safe for arbitrary text captured from tools or users.

**Non-Goals:**

- Reimplement Archon's console, event engine or retention.
- Change the database schema or workflow output contracts.
- Serve the page, refresh it live, or create a cross-project dashboard.
- Guess evidence that is absent or recover files that were deleted.

## Current render

**Current**: `100x14`, terminal, completed run `89c1ec95`, fragmented status and evidence

```text
$ make loop-status
Active workflows (0)

Recent runs (10 of 66):
  89c1ec95  completed  fix-bug

$ ls ~/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/89c1ec95-*/
attempts  check-1.log  check-2.log  escalation.md  root-cause.md  validate-1.log

$ sqlite3 ~/.archon/archon.db ...
$ git show --stat 394b7c7
```

The current view names the run, but nodes, gates, attempts, artifacts and merge evidence remain separate.

## Proposed render

**Proposed A (picked)**: `100x28`, browser page, completed run `89c1ec95`

```text
Archon run 89c1ec95                                      COMPLETED · 12m 04s
fix-bug · loop/fix-20261013-124046

Nodes
NODE                              STATUS           INVOCATIONS       DURATION
skills-check                      completed                  1          0.9s
explore                           completed                  1         48.1s
deliver__build.implement          completed                  2       5m 34.0s
deliver__build.gate               completed                  2       1m 17.8s
deliver__ship                     completed                  1          0.7s

Gates
┌ Design gate ───────────────────────────────────────────────────────────────────────┐
│ Not required                                                                      │
└───────────────────────────────────────────────────────────────────────────────────┘

Attempts
┌ Attempt 1 · failed: tasks ─────────────────────────────────────────────────────────┐
│ openspec/changes/fix-loop-codex-provider/tasks.md has unchecked tasks             │
├ Attempt 2 · passed ────────────────────────────────────────────────────────────────┤
│ check: ok (39.1 s) · validate: valid                                              │
└───────────────────────────────────────────────────────────────────────────────────┘

Artifacts                         Ship
▸ root-cause.md                    Merge 394b7c7
▸ escalation.md                    23 files changed, 1034 insertions(+), 87 deletions(-)
▸ check-1.log
```

A terminal-only report was rejected because gate comments and logs are too large to scan there. Extending the Archon console was rejected because it couples this repository to upstream UI/server work. Proposed A is a static page: it is easy to generate, archive and open from `loop-status`.

## Decisions

### One standard-library Python generator

Add `.archon/scripts/loop_report.py`, organized as small load, fold and render functions. It uses `sqlite3`, `json`, `html`, `pathlib` and `subprocess`; SQL is parameterized, Git runs with argument arrays, and every external string is HTML-escaped. SQLite opens in read-only mode, while the output is written through a temporary file and atomically replaced so regenerating a report for a live run never leaves half a page.

Alternative: generate HTML in Make or the SQLite CLI. Rejected because event JSON folding, escaping, artifact reading and active-run states need real control flow and focused tests.

### Named selection is direct; implicit selection is project-scoped

`RUN=<id>` resolves the named database row and uses that row's `output_root`, including when invoked outside the run's worktree. Without `RUN`, the generator resolves the current registered codebase by comparing the checkout's Git common directory with `remote_agent_codebases.default_cwd`, then chooses its newest run by `started_at` and id. It never chooses a newer run belonging to another registered codebase.

The output is `<output_root>/artifacts/runs/<id>/report.html`. Stdout is two short lines: run/workflow/status with counts and merge state, then `Report: <file URI>`. `make loop-status` keeps its current two Archon calls and invokes `loop-report` last, making that URI the link.

Alternative: choose the newest database row globally. Rejected because one Archon installation contains unrelated codebases.

### Fold lifecycle events into one row per workflow node

Seed pending top-level nodes from `metadata.terminal_graph.node_ids`, then add observed nested loop nodes in first-event order. Fold invocations by canonical step name: show the count and sum completed durations. For an invocation without a terminal event, show `running` or `waiting` and its elapsed duration. A resume's `node_skipped_prior_success` preserves the earlier completed state instead of replacing or double-counting it.

Alternative: one row per event or invocation. Rejected because retries would dominate the table; attempts have their own section.

### Treat structured events as the index and artifacts as evidence

Pair each `approval_requested` event with the next `approval_received` event in order; the latter's comment is `comment` for approval and `reason` for rejection. Attempt number and exact failure text come first from completed gate/verdict structured output, with `attempts`, `check-N.log`, `validate-N.log` and `archive-N.log` as supporting evidence. Root cause, escalation and recognized attempt logs are embedded as escaped collapsible text, excluding `report.html` and Archon's internal `.archon/` directory.

Missing sources render `Pending` for a live result or `Unavailable` for terminal history; they do not fail the whole report. This makes partial and historical runs useful without inventing an outcome.

Alternative: parse human logs as the primary model. Rejected because structured event outputs identify attempts and failures more reliably; logs remain valuable supporting detail.

### Derive the final stat from the recorded merge

Use the final successful `shipped`/`ship` structured output as the merge source, resolve its hash in the run's repository, and render `git diff --stat <commit>^1 <commit>`. If the run did not merge or Git no longer has the commit, say so explicitly and keep the rest of the report.

## Risks / Trade-offs

- [Archon adds event fields or lifecycle variants] → Parse only required keys, tolerate unknown fields and cover resumed/prior-success events with fixtures.
- [The database changes while a running report is generated] → Use one read transaction and atomic output replacement; a later invocation refreshes the snapshot.
- [Captured text contains markup or scripts] → Escape every database, artifact and Git string and emit no external script or asset.
- [A report becomes large because logs are large] → Keep logs collapsed by default; completeness is preferred over a second external file.
- [The recorded merge commit or an artifact has been removed] → Render `Unavailable` without failing other sections.
- [Project registration points at a worktree that was cleaned up] → Match existing registrations by Git common directory and return a concise diagnostic when none resolves.

## Migration Plan

Add the generator and Make wiring without changing existing run data. Existing retained runs become reportable immediately because generation is read-only and on demand. Rollback removes the target/script and leaves the generated, standalone `report.html` files harmlessly in their artifact directories.
