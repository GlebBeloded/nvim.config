## Why
`keymaps: Alt-G switches tree to git status` failed under full parallel `make check` load and passed alone and on rerun; `keymaps: Alt-e closes focused filesystem tree` previously had the same shape. Sampling `H.load_factor()` at file load or once when a wait starts can leave a stale budget when gate load rises during the poll.

Kind: bug

## Root Cause
The neo-tree cases poll observable state with one fixed timeout. Even after moving `H.load_factor()` sampling from file load to poll start, the parallel gate's CPU load can rise during the poll and leave its deadline stale. The Alt-G failure timed out waiting for `git_status` focus and passed alone and on rerun.

## What Changes
- Every async neo-tree wait in the keymaps integration tests polls the observable condition with a budget that can grow as host load rises. The 3000 ms idle-host budget and assertions stay unchanged.
- Out of scope: neo-tree configuration, runtime toggle behavior, core keymaps, and plugin dependencies.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none. Core keymaps: unchanged.
