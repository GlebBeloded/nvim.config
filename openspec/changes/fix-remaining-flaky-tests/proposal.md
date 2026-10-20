## Why

Kind: bug
Priority: high

User (2026-10-20): "fix them to be non flaky. Make that a requirement. test must be robust/helping, not source of
problems" (docs/testing.md, Robust tests). These cases passed on rerun in 3+ recent gate runs
(`.archon/scripts/flake_stats.py`) and no other queued change covers them (the watcher, perf and git-lock cases are in
fix-file-tree-watch-start-gap, deterministic-perf-tests and the shipped fix-git-stage-lock-race):

- `tests/integration/actions/test_plugin_ownership.lua` | actions: Plugin-window mappings are action-owned (6 runs;
  also its "reaps a blocked surface's shell-owned descendant", 4, and a 300 s hang seen in gates)
- `tests/integration/references/test_preview.lua` | references: Preview highlighting matches a regular buffer (6)
- `tests/integration/file-tree/test_ignored.lua` | file-tree: First paint waits for ignored status | omits ignored
  entries from the first frame (6)
- `tests/integration/file-tree/test_project_git.lua` | file-tree: Project tree runs git status once per burst (4)
- `tests/screen/diff/test_view.lua` | diff: Diff view matches the approved render (4)
- `tests/integration/references/test_keys.lua` | references: UTF-16 usage columns are converted to byte columns (3)
- `tests/integration/git/test_git.lua` | git: Diffview file panel on the left (3)
- `tests/integration/keymaps/test_keymaps.lua` | keymaps: Toggle wins over pending filesystem render (3)

## What Changes

- Each case passes the same way on a loaded host: find its timing dependence (fixed sleep, bare wall-clock window,
  unscaled timeout, a race with a debounce, watcher or language-server readiness) and wait on the event or state
  instead, or fix the product race it exposes.
- A case whose intent cannot be tested deterministically is deleted together with its scenario, saying why.
- No assertion is loosened to make a case pass.

## Capabilities

- `loop`: require the named flaky cases to use deterministic readiness under gate load.

## Evidence

- `tests/helpers.lua:380` and `tests/helpers.lua:393` use an unscaled 10-second surface-open deadline;
  `tests/integration/actions/test_plugin_ownership.lua:175` also gives the blocked-descendant probe an unscaled 500 ms.
- `lua/gleb/references/preview.lua:56` starts Treesitter highlighting without exposing parse completion, while
  `tests/integration/references/test_preview.lua:103` treats an active highlighter as ready and reads captures at line 108.
- `tests/integration/file-tree/test_ignored.lua:321` and `tests/integration/file-tree/test_ignored.lua:325` schedule fake
  git callbacks, racing the fixed first-paint deadline at `lua/gleb/file_tree/view.lua:443` before inspecting frame one.
- `tests/integration/file-tree/test_project_git.lua:238` gives watcher and debounce work a bare 1000 ms wall-clock
  window before checking rows and run count.
- `tests/render/cases.lua:320` waits only for a diff view object; `tests/screen/diff/test_view.lua:18` captures the screen
  immediately, before asynchronous redraw and highlighting have an observed settled state.
- `tests/integration/references/test_keys.lua:153` rewrites the Go source immediately before opening references, while
  its helper at lines 24-29 waits for client attachment but not for gopls to observe the rewritten position.
- `tests/integration/git/test_git.lua:7` fixes all Diffview readiness waits at 5000 ms, and lines 139-140 observe windows
  before line 295 reads the final leftmost layout.
- `tests/integration/keymaps/test_keymaps.lua:805` waits a fixed 1000 ms before asserting that a pending tree refresh did
  not reopen the panel instead of observing the refresh settle after the toggle.

## Impact

- Tests: the eight files named above and shared synchronization in `tests/helpers.lua` and `tests/render/cases.lua`.
- Product code is changed only if deterministic hooks are needed in `lua/gleb/file_tree/` or
  `lua/gleb/references/`; feature behavior and approved renders remain unchanged.
- No plugin dependency is added, removed or upgraded; core keymaps do not change.
- No visible UI, module layout, load order, plugin wiring, `init.lua`, or `lazy-lock.json` change is intended.
- Out of scope: unrelated flaky cases, performance-bound migrations, watcher-start races covered by queued changes,
  and loosening any existing assertion or numeric product bound.
