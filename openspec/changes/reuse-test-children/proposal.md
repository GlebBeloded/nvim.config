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

## Impact

- `tests/helpers.lua` (`H.child_set` / reuse mode), `init.lua` (loader order), the opted-in test files.
