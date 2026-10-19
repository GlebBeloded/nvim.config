## 1. Bound scanning, redraw and expansion work
Scenarios: `file-tree: Project tree redraw meets the large-tree bound`, `file-tree: Project tree expansion meets the large-tree bound`
- [x] 1.1 Write the integration tests in `tests/integration/file-tree/test_performance.lua`, driving `require("gleb.file_tree.view").redraw_all()` and normal-mode `<CR>` on populated generated fixtures, and see each case fail its load-scaled bound or single-buffer-replacement assertion
- [x] 1.2 Resolve real paths only for roots and symlink entries, retain scan identity for loop detection, make compact-directory traversal reuse the scan, and pass one prepared row set from expansion to drawing
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree redraw meets the large-tree bound"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree expansion meets the large-tree bound"` and see them pass

## Agent decisions

- Store scan identity on cached entries so cached ordinary directories need no realpath call while symlink targets remain available for loop detection.
- Store prepared row indices on each view so visible-path follow can select directly while absent paths retain reconstruction behavior.
- Reconcile at most 16 watch handles per scheduled batch so large ownership changes yield between libuv operations.
- Serialize asynchronous expansion-state replacements and discard callbacks from reset state so only the newest in-memory state can commit.
- Count and expand each file nest when its parent is visited so the row cap matches the final render without a second traversal.
- Hold a dirty draw behind its burst's Git result so one replacement renders the final filesystem and status snapshots together.
- Notify views when asynchronous repository discovery completes so the ignored-status deadline starts from repository readiness.
- Merge loaded expansion keys into the live view so user expansion state survives asynchronous state reads.
- Leave ignored-directory children unprepared so expanding a visible ignored folder performs its first scan.

## 2. Coalesce watcher, write and git refreshes
Scenarios: `file-tree: Project tree coalesces a save burst`, `file-tree: Unchanged git status does not redraw the project tree`, `file-tree: Project tree save leaves the main path promptly`
- [x] 2.1 Write the integration tests in `tests/integration/file-tree/test_performance.lua`, driving a real `:write`, `BufWritePost`, populated git data and the real watcher callback, and see the redraw count, git-run count, unchanged-map or load-scaled timing assertions fail
- [x] 2.2 Add one per-view dirty scheduler with a 50 ms window, route watcher, write, follow and git invalidations through it, keep one git request per burst, and suppress invalidation when both returned git maps are unchanged
- [x] 2.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree coalesces a save burst"`, `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Unchanged git status does not redraw the project tree"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree save leaves the main path promptly"` and see them pass

## 3. Follow an existing row without drawing
Scenarios: `file-tree: Project tree follows an already listed row promptly`
- [x] 3.1 Write the integration test in `tests/integration/file-tree/test_performance.lua`, driving real `:edit`/`BufEnter` with a populated 5000-row tree, and see the load-scaled timing or tree-buffer-replacement assertion fail
- [x] 3.2 Index prepared rows by normalized path and move the tree cursor directly when follow targets an already listed row, scheduling reconstruction only when ancestors must be expanded
- [x] 3.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree follows an already listed row promptly"` and see it pass

## 4. Defer repository, watch and persistence maintenance
Scenarios: `file-tree: Project tree re-roots without waiting for repository discovery`, `file-tree: Project tree persists folds off the action path`
- [x] 4.1 Write the integration tests in `tests/integration/file-tree/test_performance.lua`, driving global `DirChanged` between populated git worktrees and normal-mode `za`, and see the action-path bounds or eventual-state assertions fail
- [x] 4.2 Make repository discovery asynchronous, reconcile watch handles in deferred bounded batches, and persist expansion state with sequenced asynchronous `vim.uv` reads, writes and atomic replacement
- [x] 4.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree re-roots without waiting for repository discovery"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree persists folds off the action path"` and see them pass

## 5. Make unfold-all linear
Scenarios: `file-tree: Project tree unfold all meets the large-tree bound`
- [x] 5.1 Write the integration test in `tests/integration/file-tree/test_performance.lua`, driving normal-mode `zR` on the generated 60-by-100 fixture with real ignore and nesting settings, and see the load-scaled 500 ms bound fail
- [x] 5.2 Replace repeated row rebuilding with one traversal that updates expansion state, counts listed and nested rows, preserves the ignored-folder gate, stops at the existing cap, and builds final rows once
- [x] 5.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"` and see it pass
- [x] 5.4 Run `make probe SCRIPT=openspec/changes/file-tree-performance/probe.lua` on the same disposable config fixture before and after implementation and record the post-change values beside the baseline below
- [x] 5.5 Run `make quick`, then run `make check`, and fix implementation defects without weakening any scenario

## Measurements

Refreshed 2026-10-19 baseline on a disposable clone of this config:

| Operation | Rows | Before | After |
|---|---:|---:|---:|
| redraw with 400 expanded directories | 1,227 | 148.96 ms | pending task 5.4 |
| write (`BufWritePost` + watcher + git) | 1,227 | 358.02 ms, 2 draws | pending task 5.4 |
| already-listed `BufEnter` follow | 1,227 | 97.22 ms, 1 draw | pending task 5.4 |
| `unfold_all` | 2,207 | 43,337.38 ms, 632 row builds | 451.17 ms, 1 row build (same 2,216-row fixture: 18,463.60 ms and 634 row builds before) |
