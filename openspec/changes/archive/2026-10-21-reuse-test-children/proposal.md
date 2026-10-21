## Why

Kind: feature
Adopt: loop/reuse-test-children-20261020-205042
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

## Capabilities

- `loop`: extend the test harness with an opt-in reusable child lifecycle and require cached Lua loading before
  configuration modules load.

## Impact

- Architecture: `init.lua` enables cached Lua loading before configuration modules are required.
- Test tooling: `tests/helpers.lua` gains the reusable lifecycle; safe files under `tests/integration/actions/`,
  `tests/integration/find-action/`, `tests/integration/keymaps/`, `tests/integration/picker/`, and
  `tests/integration/statusline/` opt in after isolation checks.
- No plugin dependency is added, removed, or upgraded. Core keymaps do not change.
- Out of scope: reusing children in tests that touch sessions, shada, filesystem watchers, or whose state cannot be
  reset reliably; changing product behavior or UI.

## Rejected run
Run on `loop/reuse-test-children-20261020-205042` was rejected by the judge:
- fix loop exhausted with gates still red: full
- last failures:
  full make check E2E=1 is red:
  full log: /Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/7a5eae91-6660-4f53-a03f-0d00f487efc7/full-4.log
  check: waiting for the check lock held by pid 43217 (/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/worktrees/loop/deterministic-perf-tests) at /Users/hlebbeladzed/.cache/nvim-check-lock
  ok   e2e             36.0 s
  ok   trace            0.4 s
  ok   lint             1.9 s
  ok   types            3.5 s
  ok   specs            5.0 s
  ok   chain            6.5 s
  ok   smoke-health    14.2 s
  FAIL stack           29.7 s
  ok   test           302.5 s
- review findings:
  Pass 4: no code changes since the Pass 3 approval. Merge 5cdbd732 only brought in the queued fix-remaining-flaky-tests proposal from auto, which is outside this change's diff. The scope matches proposal.md and tasks.md. The init.lua loader move and tests/integration/loop/test_startup.lua implement the ADDED requirement. No tests or scenarios were weakened. Each new case name matches its scenario title and appears in only one place under tests/. The Agent decisions are consistent with the delta, where reuse is a MAY and only safe files opt in.
  
  [minor] check-4.log:1103 and :1111 report failures in file-tree/test_project_live.lua:408 and git/test_changes_diff.lua:168. Neither file is in this diff or opted into reuse. Both passed on rerun (check-4.log tail), so they are flakes this change did not cause.
  
  [minor] tests/helpers.lua:433 restores the cwd with `lcd`, which sets only the window-local cwd. The global `cd` at test_paste.lua:18 is not undone. Still open from earlier passes.
  
  [minor] The reset restores `vim` by reference, so the `vim.system` wrapper from test_pr.lua:66-67 carries over into later cases. It is harmless today.
  
  [minor] test_dashboard.lua:12 has a single case, so `reuse = true` there does nothing.
  
  [minor] The speed goal in proposal.md Why is not met. Child starts went 759 → 757 and time went 247.09 s → 252.30 s (tasks.md Agent decisions), because tests/parallel.lua shards the run per case.
- note: flaky test cases (failed, then passed on rerun): tests/integration/file-tree/test_project_live.lua | file-tree: Every compact chain member is watched, tests/integration/git/test_changes_diff.lua | git: Changes panel shows an untracked file as added
- note: loop: tests/unit/loop/test_loop_clean_py.lua | loop: Loop clean skips a branch that is already gone: x
- note: loop: ERROR: test_check_past_the_timeout_is_infra_with_its_log (test_gate_timeout.GateTimeout.test_check_past_the_timeout_is_infra_with_its_log)
