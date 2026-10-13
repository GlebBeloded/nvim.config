## Why
`keymaps: Alt-e closes focused filesystem tree` failed once under full parallel `make check` load (round20, 2026-10-13) and passed alone and on rerun; the Alt-e neo-tree case also failed under load in run 81a9b684 check-1. A flaky case erodes the gate.

Kind: bug

## Root Cause
Not yet known: find where the case waits for neo-tree to open/close (likely a fixed sleep or a too-short `vim.wait` on async neo-tree rendering) and reproduce with the case run under CPU load.

## What Changes
- Make the case wait on the observable condition (tree window present/absent) with the helpers' timeout instead of fixed timing. Do not weaken the assertion.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: the keymaps integration test (and a helper wait if shared).
- Plugins: none. Core keymaps: unchanged.
