# Proposal

## Why

Archon records a run's useful history across SQLite events, run artifacts and Git, but the current console and `make loop-status` leave those sources separate. Understanding what ran, why a gate stopped, which checks failed and what finally merged therefore requires manual correlation.

## What Changes

- Add `make loop-report [RUN=<id>]`, selecting the latest project run when `RUN` is omitted, printing a concise terminal summary and writing `artifacts/runs/<id>/report.html`.
- Make the generated HTML self-contained and show run identity/outcome, one row per node with status and duration, gate prompts plus approve/reject comments, each build attempt's failing checks, artifact evidence, and the final diff stat and merge commit when present.
- Make `make loop-status` print the latest report path after the existing active/recent run status.
- Add focused headless tests with an isolated SQLite database, artifact directory and Git repository, covering a named run, latest-run selection, active/incomplete data, escaping, attempts, gates and shipped diff metadata.
- Add no plugin dependency and remove or upgrade none.
- Change no core keymap.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `loop`: add the operator-facing per-run report and its link from loop status.

## Impact

- Code: a small report generator under `.archon/scripts/` and the `loop-report` / `loop-status` Make targets.
- Tests: focused cases under `tests/unit/loop/`, run in a headless child Neovim against disposable fixtures.
- UI: a generated local HTML report plus a short terminal summary; no Neovim UI changes.
- Dependencies: Python standard library, the existing Archon SQLite database/artifact layout and local Git data; no new plugin or package.
- Out of scope: changing Archon or its console, adding live auto-refresh or a server, changing the Archon database schema, retaining deleted artifacts, or reconstructing information that neither the database, artifacts nor Git contain.
