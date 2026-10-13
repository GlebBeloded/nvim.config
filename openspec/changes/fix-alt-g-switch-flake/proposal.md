## Why
`keymaps: Alt-G switches tree to git status` failed once under full parallel `make check` load (round23, 2026-10-14) and passed alone and on rerun; `keymaps: Alt-e closes focused filesystem tree` failed again under load in run 123f41a0 gate 3 (2026-10-14) despite fix-alt-e-close-flake. fix-alt-e-close-flake scaled one neo-tree wait with `H.load_factor()`; other neo-tree waits in the keymaps integration tests may still use a fixed budget.

Kind: bug

## Root Cause
To be confirmed: find every neo-tree wait in `tests/integration/keymaps/test_keymaps.lua` that does not scale with `H.load_factor()` (or that sleeps instead of polling), and reproduce the Alt-G case under CPU load.

## What Changes
- Every async neo-tree wait in the keymaps integration tests polls the observable condition with a load-scaled budget. Assertions unchanged.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none. Core keymaps: unchanged.
