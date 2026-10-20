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

## Impact

- The test files above and whatever product code a real race lives in; the spec step works out the rest.
