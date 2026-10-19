## 1. Bound scanning, redraw and expansion work
Scenarios: `file-tree: Project tree redraw meets the large-tree bound`, `file-tree: Project tree expansion meets the large-tree bound`
- [x] 1.1 Write the integration tests in `tests/integration/file-tree/test_performance.lua`, driving `require("gleb.file_tree.view").redraw_all()` and normal-mode `<CR>` on populated generated fixtures, and see each case fail its load-scaled bound or single-buffer-replacement assertion
- [x] 1.2 Resolve real paths only for roots and symlink entries, retain scan identity for loop detection, make compact-directory traversal reuse the scan, and pass one prepared row set from expansion to drawing
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree redraw meets the large-tree bound"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree expansion meets the large-tree bound"` and see them pass

## Agent decisions

- Store scan identity on cached entries so cached ordinary directories need no realpath call while symlink targets remain available for loop detection.

## 2. Coalesce watcher, write and git refreshes
Scenarios: `file-tree: Project tree coalesces a save burst`, `file-tree: Unchanged git status does not redraw the project tree`, `file-tree: Project tree save leaves the main path promptly`
- [ ] 2.1 Write the integration tests in `tests/integration/file-tree/test_performance.lua`, driving a real `:write`, `BufWritePost`, populated git data and the real watcher callback, and see the redraw count, git-run count, unchanged-map or load-scaled timing assertions fail
- [ ] 2.2 Add one per-view dirty scheduler with a 50 ms window, route watcher, write, follow and git invalidations through it, keep one git request per burst, and suppress invalidation when both returned git maps are unchanged
- [ ] 2.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree coalesces a save burst"`, `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Unchanged git status does not redraw the project tree"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree save leaves the main path promptly"` and see them pass

## Stuck

- Task 2 probe: after a real tracked-file write the scheduler quiesced with `dirty=false`, `dirty_timer=false`, `git_pending=false`, `git_in_flight=false`, `git_timer=false`, one replacement and one Git run; the small probe's collapsed target had no listed row status.
- Attempt 1: held each view's 50 ms dirty draw behind one pending Git request and compared both returned maps; the first task run missed final state, while the diagnostic rerun and all three isolated scenarios then passed.
- Attempt 2: preserved nest preparation for scheduled follow, avoided waiting on Git outside repositories, and reset scheduler state on re-root; a normal task rerun produced one replacement and one Git run but the listed tracked row remained `status = nil` after the Git result.
- Saved production diff: `artifacts/runs/d79215f6-6e22-4aff-8cd9-f3ec27f6a6b1/stuck-attempt-2.diff`.

## 3. Follow an existing row without drawing
Scenarios: `file-tree: Project tree follows an already listed row promptly`
- [ ] 3.1 Write the integration test in `tests/integration/file-tree/test_performance.lua`, driving real `:edit`/`BufEnter` with a populated 5000-row tree, and see the load-scaled timing or tree-buffer-replacement assertion fail
- [ ] 3.2 Index prepared rows by normalized path and move the tree cursor directly when follow targets an already listed row, scheduling reconstruction only when ancestors must be expanded
- [ ] 3.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree follows an already listed row promptly"` and see it pass

## 4. Defer repository, watch and persistence maintenance
Scenarios: `file-tree: Project tree re-roots without waiting for repository discovery`, `file-tree: Project tree persists folds off the action path`
- [ ] 4.1 Write the integration tests in `tests/integration/file-tree/test_performance.lua`, driving global `DirChanged` between populated git worktrees and normal-mode `za`, and see the action-path bounds or eventual-state assertions fail
- [ ] 4.2 Make repository discovery asynchronous, reconcile watch handles in deferred bounded batches, and persist expansion state with sequenced asynchronous `vim.uv` reads, writes and atomic replacement
- [ ] 4.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree re-roots without waiting for repository discovery"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree persists folds off the action path"` and see them pass

## 5. Make unfold-all linear
Scenarios: `file-tree: Project tree unfold all meets the large-tree bound`
- [ ] 5.1 Write the integration test in `tests/integration/file-tree/test_performance.lua`, driving normal-mode `zR` on the generated 60-by-100 fixture with real ignore and nesting settings, and see the load-scaled 500 ms bound fail
- [ ] 5.2 Replace repeated row rebuilding with one traversal that updates expansion state, counts listed and nested rows, preserves the ignored-folder gate, stops at the existing cap, and builds final rows once
- [ ] 5.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"` and see it pass
- [ ] 5.4 Run `make probe SCRIPT=openspec/changes/file-tree-performance/probe.lua` on the same disposable config fixture before and after implementation and record the post-change values beside the baseline below
- [ ] 5.5 Run `make quick`, then run `make check`, and fix implementation defects without weakening any scenario

## Measurements

Refreshed 2026-10-19 baseline on a disposable clone of this config:

| Operation | Rows | Before | After |
|---|---:|---:|---:|
| redraw with 400 expanded directories | 1,227 | 148.96 ms | pending task 5.4 |
| write (`BufWritePost` + watcher + git) | 1,227 | 358.02 ms, 2 draws | pending task 5.4 |
| already-listed `BufEnter` follow | 1,227 | 97.22 ms, 1 draw | pending task 5.4 |
| `unfold_all` | 2,207 | 43,337.38 ms, 632 row builds | pending task 5.4 |
