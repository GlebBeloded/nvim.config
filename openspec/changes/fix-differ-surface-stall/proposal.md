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

- tests/integration/actions/test_plugin_ownership.lua, tests/integration/git/test_git.lua, tests/helpers.lua.
- `actions: Plugin-window mappings are action-owned` and `git: Differ opens panel on the left` still hold, and pass in
  full parallel runs without a stall.
