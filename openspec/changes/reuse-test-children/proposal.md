## Why

Kind: feature
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
