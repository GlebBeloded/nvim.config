## Why
`keymaps: Alt-G switches tree to git status` failed once under full parallel `make check` load (round23, 2026-10-14) and passed alone and on rerun; `keymaps: Alt-e closes focused filesystem tree` failed again under load in run 123f41a0 gate 3 (2026-10-14) despite fix-alt-e-close-flake. fix-alt-e-close-flake scaled one neo-tree wait with `H.load_factor()`; other neo-tree waits in the keymaps integration tests may still use a fixed budget.

Kind: bug

## Root Cause
The neo-tree cases poll observable state, but `ASYNC_MS` samples `H.load_factor()` once while the test file loads. The parallel gate's CPU load can rise after that snapshot, leaving later neo-tree waits at the 3000 ms idle budget even while the host is busy. The Alt-G failure timed out waiting for `git_status` focus and passed alone and on rerun; the later Alt-e recurrence has the same stale-budget shape. No neo-tree wait sleeps or bypasses the shared budget.

## What Changes
- Every async neo-tree wait in the keymaps integration tests polls the observable condition with a freshly load-scaled budget. The 3000 ms idle-host budget and assertions stay unchanged.
- Out of scope: neo-tree configuration, runtime toggle behavior, core keymaps, and plugin dependencies.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none. Core keymaps: unchanged.
