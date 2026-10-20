## Why

Kind: feature
Adopt: loop/reuse-test-children
Priority: high

Loop audit (2026-10-20): the test layer is the gate's critical path (~290 s at 12 workers). Independent profiling:
~1100 full-config child starts at ~0.35 s each (40–50% of a typical integration case's time is child startup), and one
file run serially took 44 s versus 200 s inside a loaded gate. Many files never change global state between cases.

## What Changes

- Test files can opt in to one child per file (`pre_once`) with a light per-case reset (buffers, tabs, cwd, test
  globals) instead of a fresh child per case; files touching sessions, shada or fs watchers keep a fresh child.
- `vim.loader.enable()` runs before the first `require` of the config, so every start loads cached bytecode.
- Opt in the files where it is safe (keymaps, actions, find-action, statusline, picker and similar) and measure the
  layer before and after.

## Impact

- `tests/helpers.lua` (`H.child_set` / reuse mode), `init.lua` (loader order), the opted-in test files.

## Rejected run
Run on `loop/reuse-test-children` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] The gate still fails because of the stale-MiniPick reuse leak.
  - check-3.log:1110 shows FAIL on tests/integration/find-action/test_hidden.lua:54, "Show hidden reveals a separate tier", with `mini/pick.lua:3689: Invalid buffer id: 2`. The case passes on rerun in a fresh child (rerun-3-2.log).
  - Cause: "Hidden and unavailable actions start absent" (test_hidden.lua:66-70) ends with the palette still open. The reset at tests/helpers.lua:430-431 (`tabonly!` + `%bwipeout!`) wipes the picker's buffer without stopping the picker, so the next case in the same child hits a stale MiniPick.
  - tests/integration/find-action/test_assign.lua:95 and :108 also end with the picker active, so the file has the same exposure.
  - Pass 2 asked for this fix in the reset itself. Fix pass b8e0381c only moved test_input back to fresh children, so every other opted-in file that leaves a picker open still leaks.
  - Fix: in `tests.case_reset`, stop any active picker and drain it before the wipe, e.g. `if _G.MiniPick and MiniPick.is_picker_active() then MiniPick.stop(); vim.wait(1000, function() return not MiniPick.is_picker_active() end) end`. This satisfies the delta scenario "Reusable child resets case state" (one clean buffer, no state left by the first case).
  
  [must-fix] The reset still restores globals by reference, so a test table one case mutates carries over to later cases. This contradicts the scenario "no globals left by the first case".
  - Where: tests/helpers.lua:422-426 snapshots `_G` after `start()`, and tests/helpers.lua:439-441 puts back the same table objects.
  - Live instances among the opted-in files:
    - test_assign.lua:42-45 creates `Notifications = {}`. "Adapter assignment reports deferred application" (:187-191) waits for `#Notifications > 0` and checks `Notifications[#Notifications]`. Both checks are satisfied by a notification an earlier case left, so the case can pass or fail on stale data.
    - test_hidden.lua:12 creates `HiddenRuns = {}`, and :94 expects exactly `{ "zulu" }`.
  - Pass 2 flagged this. The fix pass isolated only test_input and left the reset unchanged.
  - Fix: re-run each file's per-case fixture setup (the globals and tables `start` creates) before every case in reuse mode. One way is to split `start` into a once-only part and a per-case part. Alternatively, keep test_assign and test_hidden on fresh children.
  
  [minor] tests/helpers.lua:432 restores the cwd with `lcd`. That sets only a window-local directory, so the child's global cwd stays wherever an earlier `:cd` or `chdir` left it; test_paste.lua:18 calls `cd`. Using `cd` would restore the global state the scenario describes. This was raised in passes 1 and 2.
  
  [minor] Reuse saves almost no child starts. The measurement under tasks.md `## Agent decisions` shows 759 → 757 starts and 247.09 s → 252.30 s. The cause is that tests/parallel.lua shards case by case, so a reused file starts one child per worker it lands on. The proposal's Why (speed) is not met.
  
  [minor] check-3.log:1102 also fails tests/integration/file-tree/test_project_live.lua, "Every compact chain member is watched". That file is not in this diff and not opted into reuse. It passed on rerun (rerun-3-1.log), so it looks like a pre-existing flake and is not attributable to this change.
- note: flaky test cases (failed, then passed on rerun): tests/integration/file-tree/test_project_live.lua | file-tree: Every compact chain member is watched, tests/integration/find-action/test_hidden.lua | find-action: Show hidden reveals a separate tier: tests/integration/find-action/test_hidden.lua:54: E5108: Lua: ...ed/QtYcIL/256/data/nvim/lazy/mini.nvim/lua/mini/pick.lua:1762: ...ed/QtYcIL/256/data/nvim/lazy/mini.nvim/lua/mini/pick.lua:3689: Invalid buffer id: 2
- note: loop: No test cases matched
- note: loop: FAIL in tests/integration/file-tree/test_performance.lua | file-tree: Project tree re-roots without waiting for repository discovery: tests/integration/file-tree/test_performance.lua:525: re-root took 395.94 ms
- note: loop: FAIL in tests/integration/lsp/test_readiness.lua | lsp: lua_ls ready in this config: lua_ls not ready after 15439 ms, bound 10000 ms (last error: vim.NIL)
