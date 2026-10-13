## Why
`keymaps: Alt-e closes focused filesystem tree` failed once under full parallel `make check` load (round20, 2026-10-13) and passed alone and on rerun; the Alt-e neo-tree case also failed under load in run 81a9b684 check-1. A flaky case erodes the gate.

Kind: bug

## Root Cause
The case already polls the observable condition, but every neo-tree wait uses a fixed 3000 ms `ASYNC_MS`. Under the 12-worker `make check` load, the close callback can remain queued beyond that fixed budget: run 81a9b684 timed out at `wait_no_tree()` while the adjacent neo-tree cases passed, then the case passed on rerun. The shared test helper already exposes `H.load_factor()` for scaling timing waits under host load, but this test does not use it.

## What Changes
- Scale the keymaps integration test's async plugin wait budget with `H.load_factor()` while continuing to poll for the observable tree-window condition. Do not weaken the assertion.
- Keep the 3000 ms idle-host budget unchanged.
- Out of scope: neo-tree configuration, runtime toggle behavior, core keymaps, and plugin dependencies.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: the keymaps integration test (and a helper wait if shared).
- Plugins: none added, removed, or upgraded. Core keymaps: unchanged.
