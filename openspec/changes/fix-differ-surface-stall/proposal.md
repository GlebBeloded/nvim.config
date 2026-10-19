## Why

Kind: bug

Depends: fix-plugin-ownership-hang-2, tree-diff-cutover

`fix-plugin-ownership-hang-2` made a stalled plugin surface fail in ~10 s with diagnostics instead of hanging a worker
for 300 s, but did not remove the stall. Its gates captured it (run 36516373, check-5 and check-6):

```
lazy surface open failed (phase: scheduled; elapsed: 10155 ms; mode: n; getchar: 0; messages: <none>;
subprocesses: 20430: /Library/Developer/CommandLineTools/usr/bin/git status --porcelain=v1 -z -uall, …)
```

The child's main loop was blocked by a synchronous `git status --porcelain=v1 -z -uall`, which differ.nvim runs with
`vim.system(...):wait()` and no timeout (`differ/git/init.lua:574`, `:981`) when `:Differ` opened earlier in
`actions: Plugin-window mappings are action-owned`; `git: Differ opens panel on the left` stalls the same way.
Also, `stop_blocked_child` (tests/helpers.lua) SIGKILLs only the child nvim, leaving its git or `sleep` subprocess
running.

`tree-diff-cutover` is now present: the active tests assert that the `Differ` command and `differ.nvim` plugin are
not registered. The Differ-specific work below therefore no longer applies; the process-tree cleanup remains.

## Evidence

- `/Users/hlebbeladzed/.local/share/nvim/lazy/differ.nvim/lua/differ/git/init.lua:42` waits synchronously for every
  local git command without a timeout; lines 574 and 981 invoke that helper for `git status --porcelain=v1 -z -uall`.
- `tests/integration/git/test_git.lua:244`-`261` asserts that the retired `Differ` command and `differ.nvim` plugin
  are absent.
- `tests/helpers.lua:336`-`347` records only the Neovim child's immediate subprocesses, and lines 320-325 kill only
  those pids before killing Neovim; grandchildren such as a shell's `sleep` process are not collected or killed.

## What Changes

- `tree-diff-cutover` removes differ.nvim: if `:Differ` and its surface cases are gone, the Differ items below no longer
  apply; keep only the `stop_blocked_child` process-tree item (it holds for any blocked surface).

- Probe the directory Differ's `git status -uall` runs in for both cases (the case's cwd) and how long it takes there
  under a full parallel `make test`; record the measurement.
- Open the Differ surface in a small fixture repo in both cases, and make sure no Differ git job is still running when
  the next surface opens (wait for Differ's open to finish, or close it first).
- `stop_blocked_child` kills the blocked child's whole process tree (its subprocesses first), so no git or `sleep`
  process is left behind.
- The cases' assertions stay as they are; no surface is skipped.

## Impact

- `tests/integration/actions/test_plugin_ownership.lua` and `tests/helpers.lua`.
- No plugin dependency or core keymap changes; no module layout, load-order, or plugin-wiring changes.
- Out of scope: restoring or changing retired Differ behavior, changing active surface assertions, or skipping a
  surface.
