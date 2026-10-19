## Why

Kind: bug
Adopt: loop/fix-file-tree-live-flakes

Two file-tree cases fail in every full `make check` on auto since file-tree-ignored shipped (2 of 2 runs,
2026-10-18, load average 22–31), and pass alone:

```
FAIL in tests/integration/file-tree/test_ignored.lua | file-tree: First paint waits for ignored status | omits ignored entries from the first frame:
  Left:  true
  Right: false
    tests/integration/file-tree/test_ignored.lua:334
FAIL in tests/integration/file-tree/test_project_live.lua | file-tree: A compact chain splits when a folder gains an entry:
  Left:  false
  Right: true
    tests/integration/file-tree/test_project_live.lua:344
```

## What Changes

- For each case, log with a headless probe under parallel load (`make test CAPS=file-tree`) what the case observes
  at the failing line and when the tree's async work (git ignored status, the filesystem watch, the redraw) lands.
- Fix the cause: the code paints before the ignored status is known, or misses the watch event; or the test reads
  before an event it can await (a real redraw or status signal, never a sleep). The assertions stay as they are.

## Impact

- lua/gleb/file_tree/ (view, watch or git status) or the two test files' waits.
- `file-tree: First paint waits for ignored status` and `file-tree: A compact chain splits when a folder gains an entry`
  still hold, now under a full parallel run.

## Rejected run
Run on `loop/fix-file-tree-live-flakes` was rejected by the judge:
- fix loop exhausted with gates still red: tasks,review,stuck
- stuck: tasks.md `## Stuck` (earlier attempts, kept on the branch: not quoted here)
- last failures:
  openspec/changes/fix-file-tree-live-flakes/tasks.md has unchecked tasks
- review findings:
  [must-fix] openspec/changes/fix-file-tree-live-flakes/tasks.md:13 + proposal.md:25-27: the settled user decision (Blocked option (a): a Darwin kqueue `EVFILT_VNODE` backend through LuaJIT FFI, drained from `vim.uv.new_poll`) is still unimplemented. Task 2.7 is unticked. lua/gleb/file_tree/watch.lua:70 and :101 still create `vim.uv.new_fs_event()` for both the folder handles and the git-dir handle, and there is no Darwin branch, kqueue code or `RLIMIT_NOFILE`-bounded cap. The `## Stuck` probes show FSEvents dropping events under load, so the test waits added in 2.2–2.6 cannot make the six "within 1000 ms" live scenarios, the tab-isolation update or the staging recolour reliable. check-7 was green only by chance. Implement 2.7 as written: keep watch.lua's per-folder start/stop interface, debounce, cap and git-dir watch; swap only the handle type on Darwin; keep `fs_event` elsewhere; keep the cap below the soft `RLIMIT_NOFILE`. Earlier passes did not miss this: the decision was only settled in e598c1f4.
  [minor] openspec/changes/fix-file-tree-live-flakes/proposal.md:25: the settle commit records the user's answer only as a What Changes bullet and an Agent decisions line (tasks.md:34). The project CLAUDE.md says user decisions live in a proposal `## Decision` section. fix-scope.md flags this proposal edit; it records the settled answer rather than scope creep.
  [minor] lua/gleb/file_tree/view.lua:804-809: the deferred-deadline `result_pending` branch still has no case of its own, a result that arrives late or fails at the deadline (carried over from passes 1–2).
  Checked and fine: the tests are not weakened. The fake git now answers synchronously and the `status` index is fixed, with assertions unchanged. The load-scaled waits in tab-isolation and the git highlight cases have no time bound in the spec. The quit `jobwait` load-scaled bound keeps the exit-code-0 assertion. `go.sum` keeps the cursor assertion. The VimLeavePre watch stop (autocommands/init.lua:22-36) and `rename_unformatted` (ops.lua:135-149) are covered by tasks 3.1 and 3.2 and reuse the existing `vim.g.format_on_save_disabled` flag.
- note: flaky test cases (failed, then passed on rerun): tests/integration/file-tree/test_project_lsp_rename.lua | file-tree: Project tree rename waits for servers at most one second | continues after the deadline: tests/integration/file-tree/test_project_lsp_rename.lua:210: rename took 2329 ms, tests/integration/git/test_changes_stage.lua | git: Changes panel A stages everything, tests/integration/lsp/test_typecheck.lua | lsp: Type-check toggle reattaches every Python buffer without reloading, e2e: Error: VM 'nvim-e2e' is not running
