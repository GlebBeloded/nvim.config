## Why

Kind: bug

`actions: Plugin-window mappings are action-owned` (`tests/integration/actions/test_plugin_ownership.lua`) hangs again
after `fix-plugin-ownership-hang` (archived 2026-10-18), and the hang kills its worker, so ~90 other cases of the full
run are reported "not run". It passes alone (2.0 s) and on the gate's serial rerun. Seen in 3 full `make check`
runs on 2026-10-18 under load average 10–30 (run 1202d6e0 check-4; loop round105 check):

```
FAIL in tests/integration/actions/test_plugin_ownership.lua | actions: Plugin-window mappings are action-owned: hung: no progress for 300 s (waiting for input or a never-met condition?)
FAIL in tests/integration/ai/test_prompt_keys.lua | ai: Menu shows prompt: not run: its worker was killed after a hung case
… (~90 more "not run")
```

The case opens 10 plugin surfaces in turn through `open_surface` (neo-tree, dap-ui, Diffview, Differ, CodeDiff,
neotest summary, Mason, Lazy, 99). Which one blocks is not known.

## What Changes

- Find the blocking surface: run the case under parallel load (`make test CAPS=actions,ai,diff,file-tree` or the
  full `make test`) with `open_surface` logging each surface's name and the elapsed time to a file before and after it
  opens, until one hang is captured; also log the child's mode, `vim.fn.getchar(1)` state and messages at the stall.
- Fix the cause in that surface's open path (a blocking prompt, a `vim.wait` or job waiting on the network or a lock,
  a modal `getchar`), or make `open_surface` fail fast with that surface's name and the child's state instead of
  hanging for 300 s. The case's assertions stay as they are; never skip a surface.

## Impact

- tests/integration/actions/test_plugin_ownership.lua; the blocking surface's config under lua/gleb/ if the cause is
  there.
- `actions: Plugin-window mappings are action-owned` still holds, and no longer hangs a worker under load.
