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

A second case hangs the same way in another full run (loop round106 check, 2026-10-18 19:40):

```
FAIL in tests/integration/git/test_git.lua | git: Differ opens panel on the left: hung: no progress for 300 s (waiting for input or a never-met condition?)
```

Both hanging cases open `:Differ`, so probe that surface first.

The plugin-ownership case opens 10 plugin surfaces in turn through `open_surface` (neo-tree, dap-ui, Diffview, Differ, CodeDiff,
neotest summary, Mason, Lazy, 99). Which one blocks is not known.

## What Changes

- Add a process-level deadline around plugin-surface opens so a blocked child is stopped within 10 seconds and the
  failure names the surface and includes its last recorded mode, pending-input state, messages, and elapsed phase.
- Drive both affected scenarios through that bounded path, including the real `:Differ` command and populated Git
  data. Keep every surface and every existing assertion.
- This change does not add, remove, or upgrade a plugin dependency, and it does not change core keymaps.
- Out of scope: changing Differ's layout or mappings, skipping a plugin surface, and reproducing the flake with
  artificial host load.

## Evidence

- `tests/integration/actions/test_plugin_ownership.lua:41-57` schedules each open but polls with blocking child RPC,
  so its 10-second `child.wait` deadline cannot advance while the child is blocked.
- `tests/helpers.lua:208-212` implements `child.wait` by repeatedly calling `child.lua_get`; mini.test implements that
  call with synchronous `vim.rpcrequest` in
  `/Users/hlebbeladzed/.local/share/nvim/lazy/mini.nvim/lua/mini/test.lua:1391-1395`.
- `/Users/hlebbeladzed/.local/share/nvim/lazy/differ.nvim/lua/differ/git/init.lua:39-58` runs Git with unbounded
  `vim.system(...):wait()` calls, and `:Differ` reaches them through `M.panel` at lines 834-904. A stalled Git child
  therefore blocks Neovim's RPC handler and bypasses the test's local timeout until the 300-second worker watchdog.
- Gate evidence: `FAIL in tests/integration/actions/test_plugin_ownership.lua | actions: Plugin-window mappings are action-owned: hung: no progress for 300 s (waiting for input or a never-met condition?)`
- Gate evidence: `FAIL in tests/integration/git/test_git.lua | git: Differ opens panel on the left: hung: no progress for 300 s (waiting for input or a never-met condition?)`

## Impact

- `tests/helpers.lua`, `tests/integration/actions/test_plugin_ownership.lua`, and `tests/integration/git/test_git.lua`.
- `actions: Plugin-window mappings are action-owned` and `git: Differ opens panel on the left` still hold, and neither hangs a worker under load.
