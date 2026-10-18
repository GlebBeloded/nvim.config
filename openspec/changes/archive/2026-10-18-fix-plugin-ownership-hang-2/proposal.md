## Why

Kind: bug
Adopt: loop/fix-plugin-ownership-hang-2

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
- Stop every live subprocess before stopping a blocked Neovim child, and share the blocked-`:Differ` regression helper
  between the affected scenarios while preserving teardown when the open returns before its deadline.
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

- `tests/helpers.lua`, `tests/integration/actions/test_plugin_ownership.lua`, `tests/integration/git/test_git.lua`,
  `tests/integration/file-tree/test_project_live.lua`, and `tests/screen/file-tree/test_project_ops.lua`.
- `actions: Plugin-window mappings are action-owned` and `git: Differ opens panel on the left` still hold, and neither hangs a worker under load.

## Decision (auditor, 2026-10-18, after the task loop)

- The fail-fast deadline with diagnostics is accepted as this change's fix: a stalled surface fails in seconds instead of
  hanging a worker for 300 s.
- The blocked-`:Differ` regression case asserts the diagnostics' phase is `opening` (the stubbed git call was hit, not a
  slow start) and always stops its blocked child (also when the open returns before the deadline), so it leaks no
  process.
- The stall diagnostics also list the child's live subprocesses (`vim.api.nvim_get_proc_children` with each command
  line), so the next real stall names the git command it waited on.
- (gate 6, captured stall) check-5 and check-6 failed on this change's own case, not a flake:
  `lazy surface open failed (phase: scheduled; elapsed: 10155 ms; … subprocesses: 20430: git status --porcelain=v1 -z -uall, …)`.
  The child's main loop was blocked by a synchronous `git status -uall`, which differ.nvim runs
  (`differ/git/init.lua:574`, `vim.system(...):wait()` without a timeout) when `:Differ` opened earlier in the case.
  Probe which directory it ran in (the case's cwd); open the Differ surface (in both cases) in a small fixture repo,
  and make sure no Differ git job is still running when the next surface opens (wait for Differ's open to finish, or
  close Differ before the next surface). A pass that leaves this case red without a commit is not a fix.

## Rejected run
Run on `loop/fix-plugin-ownership-hang-2` was rejected by the judge:
- rewrites the user's ## Decision in openspec/changes/fix-plugin-ownership-hang-2/proposal.md
- review findings:
  Pass 4's must-fix is resolved. `child_subprocesses` (tests/helpers.lua:331-344) now reads each child's argv with `ps -o args=`, and both regression cases assert `sleep 30`. The dead copy inside the child is gone. check-7 is green; its only flake is the e2e VM not running.
  
  1. [minor] SIGKILL leaves grandchildren running. `stop_blocked_child` (tests/helpers.lua:318-319) kills only the nvim pid. The stubbed `/bin/sleep 30` (or, in a real stall, the git child) is orphaned and keeps running until it exits on its own. The Decision says "leaks no process". Fix: kill each pid from `nvim_get_proc_children` before killing nvim.
  2. [minor] Duplicated helper, still open from pass 4. `expect_blocked_differ_diagnostic`, including its `vim.system` stub, is copied in tests/integration/actions/test_plugin_ownership.lua:49 and tests/integration/git/test_git.lua:231.
  3. [minor] Out-of-scope edits the gate needed. tests/integration/file-tree/test_project_live.lua:123,146 and tests/screen/file-tree/test_project_ops.lua:124-130 are outside the proposal, but check-1 needed them to go green. They are not weakened: timeouts scale with load and the wait condition is stricter.
  
  No findings in these checks:
  - Both agent decisions match the spec and the Decision.
  - Test names match the scenario titles.
  - No assertion was dropped.
  - Delta requirements are under 500 characters.
  - No test reads files under openspec/changes/.
- note: flaky test cases (failed, then passed on rerun): e2e: Error: VM 'nvim-e2e' is not running
- note: loop: sandbox: Lume still reports nvim-e2e unknown while its lume run process is alive, after one restart; giving up (/Users/hlebbeladzed/.cache/nvim-e2e-sandbox/vm.log)
- note: loop: No test cases matched
