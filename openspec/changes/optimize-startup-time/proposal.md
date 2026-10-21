## Why

Kind: feature
Adopt: loop/optimize-startup-time-20261021-061156

Requested by the user (2026-10-20): "optimize startup time (should be snappy)".

## What Changes

- Neovim starts noticeably faster with the real config; the spec step measures the current startup and sets the
  target.

## Impact

- To be determined by the spec step (startup path, plugin loading).

## Rejected run
Run on `loop/optimize-startup-time-20261021-061156` was rejected by the judge:
- fix loop exhausted with gates still red: tests,stuck
- stuck: tasks.md `## Stuck` (earlier attempts, kept on the branch: not quoted here)
- last failures:
  make check is red:
  full log: /Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/694c1dc1-5061-460f-bab9-c598588b8951/check-3.log
  ok   lint             0.4 s
  ok   trace            0.6 s
  ok   types            2.0 s
  ok   specs            2.3 s
  FAIL test           650.1 s
  check: FAILED: test (650.3 s)
  ===== test (head) =====
  tests/integration/file-tree/test_performance.lua | file-tree: Project tree save leaves the main path promptly: x
  tests/integration/file-tree/test_performance.lua | file-tree: Project tree re-roots without waiting for repository discovery: x
  tests/integration/file-tree/test_performance.lua | file-tree: Project tree re-roots once with saved expansion: x
- note: loop: `FAIL in tests/integration/file-tree/test_performance.lua | file-tree: Project tree re-roots once with saved expansion: hung: no progress for 300 s (waiting for input or a never-met condition?)` and the file-tree watch cases fail on base `auto` too: the host's fseventsd is degraded (pegged CPU, multi-GB RSS), so every FSEvents stop blocks the main loop and events arrive late; restart fseventsd or reboot before the next gate. Orphaned test children from loop/pr-comments-view-20261020-141615 (ppid 1) are still running.
