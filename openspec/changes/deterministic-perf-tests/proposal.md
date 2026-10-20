## Why

Kind: feature
Adopt: loop/deterministic-perf-tests-20261020-230531
Priority: high

Loop audit (2026-10-20): wall-clock bounds flake under the gate's load (load average 25–60 on 14 cores):
`tests/integration/file-tree/test_performance.lua` — "re-roots without waiting for repository discovery" (8 runs),
"coalesces a save burst" (5), "unfold all meets the large-tree bound", "save leaves the main path promptly" — plus
`lsp: Type-check toggle reattaches every Python buffer without reloading`. Independent review: the bounds span several
RPC round trips, `H.load_factor()` uses the lagging 1-minute load average, the coalesce case races a 150 ms git debounce
against late fs events, and several waits (`child.wait` 2000 ms default, `ASYNC_MS=3000`, re-root's 1000 ms settle)
are not load-scaled.

## What Changes

- Performance assertions measure what they mean without RPC noise: time inside one `child.lua` call, CPU time
  (`vim.uv.getrusage`) or operation counts (scans, `set_lines`, synchronous `vim.system():wait()` calls) as the main
  assertion; structural assertions where the intent is "does not wait" (re-root: discovery not complete right after `cd`).
- Debounce-coalescing cases use an injected/manual debounce clock instead of real timers.
- Pure wall-time bounds move to a serial `make perf` layer that `make check` runs alone; the parallel layer keeps the
  correctness assertions. `child.wait`'s default timeout and the unscaled waits scale with load.
- No bound is loosened without a load-scaled reason.

## Impact

- `tests/integration/file-tree/test_performance.lua`, `tests/helpers.lua`, `lua/gleb/util/debounce.lua` (a test hook),
  `Makefile`/`tests/check.sh` (the `perf` layer).

## Rejected run
Run on `loop/deterministic-perf-tests-20261020-230531` was rejected by the judge:
- fix loop exhausted with gates still red: full
- last failures:
  full make check E2E=1 is red:
  full log: /Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/2ef37bd9-a7ca-4495-bf6e-61b704697a3e/full-3.log
  ok   e2e             35.1 s
  ok   trace            0.5 s
  ok   lint             1.4 s
  ok   types            2.6 s
  ok   specs            4.2 s
  ok   chain            6.3 s
  ok   smoke-health    13.9 s
  ok   stack           30.2 s
  ok   test           303.8 s
  FAIL loop-test      365.0 s
- review findings:
  Pass 3 review: the pass 2 must-fix is fixed in 8546bb33. tests/integration/file-tree/test_performance.lua:192-201 now starts the measurement, runs the real `zR` with `feedkeys "mx"` and finishes the measurement inside one `lua_get`. `zR` is synchronous (view.lua:588 → ui_tree.open_all → folds.expand_all_shared), so the 500 ms CPU and serial wall bounds now include prepare_draw and rebuild_tree (folds.lua:169-171) and no RPC round trips. The 5001-row ceiling and the exact WARN check through `notifications()` are kept. The narrowing agent decision was removed from tasks.md.
  [minor] openspec/changes/deterministic-perf-tests/tasks.md:75: the 13.1 rewrite dropped the red step ("temporarily capture after host poll … see it fail"). No make types/check/colorize step was removed, and 13.3 still runs the case.
  [minor] tests/integration/file-tree/test_performance.lua (save sentinel): `FileTreeWatchSentinel.handle` is never stopped or closed (carried over).
  [minor] tests/integration/lsp/test_typecheck.lua:7,78: when LOAD_FACTOR is 1 the expected deadline equals the unscaled TIMEOUT_MS (carried over).
  [minor] specs/file-tree/spec.md: the coalesce scenario's "advances by 50 ms" and "149+1" wording does not match the 150+50 advances and GIT_DEBOUNCE_MS=150 (carried over).
  Checked with no finding: scope against proposal Impact, the debounce hook callers, the child.wait default scaling, the serial `+perf` target, unique case names, and no bounds loosened. check-3.log is green.
