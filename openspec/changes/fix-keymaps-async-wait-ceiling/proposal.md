## Why
fix-alt-g-switch-flake (ab94f51) re-samples `H.load_factor()` during neo-tree waits, but the factor uses the 1-minute load average, which barely moves within a 3-5 s poll, so it behaves like the single sample that failed; its gate 3 likely passed on a quieter host. Differ and Telescope waits in `tests/integration/keymaps/test_keymaps.lua` (~601, ~609) still use one fixed sample. Condition waits cost nothing when they pass, so their ceiling can be generous.

Kind: bug

## Root Cause
Ceilings of condition waits in the keymaps integration tests are too tight for a loaded host (12 test workers plus e2e and loop-test on 14 CPUs): the cases poll the right condition but give up at ~3 s.

## What Changes
- One `async_ms()` helper in the keymaps integration tests with a 10000 ms base scaled by `H.load_factor()`, used by every async wait in the file (neo-tree, Differ, Telescope). Waits keep polling the observable condition; assertions unchanged.
- RED evidence: gate logs of runs dec37df2 check-1 and 123f41a0 check-3 (`FAIL in` lines); do not reproduce under artificial load.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none. Core keymaps: unchanged.
- Out of scope: keymap behaviour, plugin configuration, and production wait logic.
