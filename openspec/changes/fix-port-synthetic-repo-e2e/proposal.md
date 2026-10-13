# Proposal

Kind: bug

## Why

`add-synthetic-repo-e2e` was approved and archived on `loop/feat-20261012-232024`, but its pre-reconcile ship workflow failed on conflicts with `auto`. Current `auto` therefore lacks the approved fixture infrastructure and five end-to-end LSP and Git workflow scenarios even though the change appears archived.

## What Changes

- Merge `loop/feat-20261012-232024` into the current branch and resolve all conflicts by preserving the behavior, tests, and scenarios from both histories.
- Add the archived Go/gopls fixture workflow to the current `lsp` capability without losing its diagnostic-sign requirements or tests.
- Add the archived dirty-repository Differ workflows to the current `git` capability.
- Preserve current `auto` improvements to the stack harness, sandbox locking/restoration, load-scaled deadlines, type annotations, testing documentation, and all later scenarios.
- Preserve the archived fixture builder, e2e cases, quick-test routing, sandbox Go/gopls provisioning, documentation, and queued `fix-lsp-references-current-line` change.
- Run the full merge gate, including sandbox e2e, after reconciliation.

## Decision

The archived proposal contains no `## Decision` section. The recorded user ship-gate decision approved the new xfail because it exposes the real config bug queued as `fix-lsp-references-current-line`; this port SHALL preserve both that xfail and the queued change rather than weakening the LSP scenario.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lsp`: add the approved Go references workflow and its real-key e2e scenarios alongside the existing diagnostic-sign requirements.
- `git`: add the approved Differ dirty-repository review workflow and its real-key e2e scenarios.

## Impact

- Code and tests: the existing archived branch changes under `tests/fixtures/`, `tests/fixtures.lua`, `tests/e2e/`, `tests/shortcuts/stack.lua`, `tests/sandbox/sandbox.sh`, and `tests/quick.sh`, reconciled with current `auto`.
- Specs and planning: merge the archived `lsp` and `git` deltas into their current capability specs; retain the archived change record and `fix-lsp-references-current-line` queue entry.
- Documentation: reconcile `docs/testing.md` so it describes both current sandbox concurrency/restoration behavior and synthetic fixtures.
- Plugin dependencies: none added, removed, or upgraded. Go and gopls remain test-only sandbox tools pinned by the archived change.
- Core keymaps: unchanged.
- Visible UI: unchanged; tests exercise existing Telescope and Differ UI.
- Out of scope: fixing `fix-lsp-references-current-line`; synthetic e2e part 2; new languages or workflows; Differ staging/conflicts; neo-tree/codediff, diffview, or PR-review workflows; screenshots; unrelated cleanup or refactoring.
