# Spec Delta

## ADDED Requirements

### Requirement: Loop run report consolidates persisted run evidence
`make loop-report [RUN=<id>]` SHALL select the named run, or the latest run for this codebase when `RUN` is omitted, print a short text summary and write `artifacts/runs/<id>/report.html`. The self-contained report SHALL show run identity and outcome, one row per workflow node with status and duration, each approval gate's reason and decision comment, each attempt's failing checks, and the shipped merge commit with its final diff stat when present.

#### Scenario: Named run report contains the complete run history
- **WHEN** `make loop-report RUN=<id>` is called via `vim.system` against a fixture Archon database, artifact directory and Git repository containing completed, failed and retried nodes, approval gates with comments, two gate attempts with failing checks, and a shipped merge commit
- **THEN** it exits 0, stdout identifies the run, final status and report path, and `artifacts/runs/<id>/report.html` exists with no external asset dependency and contains exactly one row per workflow node with its status and duration (aggregating repeated loop invocations and showing their count), every gate reason and approve/reject comment, the failing checks grouped by attempt, the available run artifacts, and the merge commit and diff stat

#### Scenario: Report without a run selects the latest run for this codebase
- **WHEN** `make loop-report` is called via `vim.system` with no `RUN` against a fixture database containing an older and a newer run for this codebase and a still newer run for another codebase
- **THEN** it exits 0, writes `artifacts/runs/<newer-id>/report.html`, and stdout identifies `<newer-id>` and that report path

#### Scenario: Running run report tolerates incomplete evidence
- **WHEN** `make loop-report RUN=<id>` is called via `vim.system` for a running fixture run with a started but unfinished node and no gate, check or ship result yet
- **THEN** it exits 0, shows the node as running with its elapsed duration, marks unavailable attempt and merge evidence as pending, and writes a self-contained report without inventing a final outcome

### Requirement: Loop status links to the latest run report
`make loop-status` SHALL retain the Archon active-status and recent-run output, generate the latest report for this codebase, and print a local link to it.

#### Scenario: Loop status prints a usable report link
- **WHEN** `make loop-status` is called via `vim.system` with `ARCHON` set to a logging stub and fixture data for a latest run
- **THEN** the stub records `workflow status` and `workflow runs --limit 10`, `artifacts/runs/<latest-id>/report.html` exists, and stdout contains its `file://` link
