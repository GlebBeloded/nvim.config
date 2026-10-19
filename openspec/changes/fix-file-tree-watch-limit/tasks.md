## 1. Keep listed directories live beyond the watch cap
Scenarios: `file-tree: Project tree caps watched folders`, `file-tree: Project tree updates the last folder beyond the legacy watch limit`
- [x] 1.1 Add `file-tree: Project tree updates the last folder beyond the legacy watch limit` to `tests/integration/file-tree/test_project_live.lua`, drive `file_tree.toggle` against populated data with more than 256 expanded directories, create the file through the external process helper, and see the unchanged 1000 ms assertion fail
- [x] 1.2 In `lua/gleb/file_tree/watch.lua` and `lua/gleb/file_tree/view.lua`, prioritize watched paths by rendered visibility and cursor proximity, periodically invalidate and rescan every unwatched listed directory, and stop that fallback work with the root; retain the configurable cap and retry failed watch starts through reconciliation
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="Project tree updates the last folder beyond the legacy watch limit"` and `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="Project tree caps watched folders"` and see them pass

## 2. Make compact-chain watches reliable
Scenarios: `file-tree: A compact chain splits when a folder gains an entry`, `file-tree: Every compact chain member is watched`
- [x] 2.1 Use the captured failing evidence `FAIL in tests/integration/file-tree/test_project_live.lua | file-tree: A compact chain splits when a folder gains an entry` and `FAIL in tests/integration/file-tree/test_project_live.lua | file-tree: Every compact chain member is watched`; keep both existing tests and their bounds unchanged
- [x] 2.2 Reconcile the initial compact-chain member watches before an external change can be missed, without blocking later large-tree watch updates
- [x] 2.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="A compact chain splits when a folder gains an entry"` and `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="Every compact chain member is watched"` repeatedly and see them pass

## Agent decisions

- Rank scan paths with visible rows first, then by row distance from the cursor, so compact-chain ancestors inherit the rendered row's priority.
- Reconcile one 16-handle batch synchronously on first draw, then retain scheduled batches for larger trees.
- Rescan unwatched listed directories every 250 ms, leaving time for the existing coalesced redraw inside the 1000 ms contract.

## Stuck

- Probe evidence: an exact 4898-row Git-backed probe folded in 64.71 ms with 1746 asynchronous directory metadata checks, zero asynchronous rescans, zero synchronous cache misses, and a 0.04 ms maximum heartbeat gap, while the dedicated case took 922.63 ms and 2032.59 ms. The remaining delay occurs outside the measured fold action despite unchanged directories avoiding scans.
- Attempt 1 cached each scanned directory's mtime and replaced unchanged fallback scans with asynchronous metadata checks; the dedicated case remained red at 922.63 ms and 2032.59 ms on its required timing-bound rerun.
- Attempt 2 submitted all cheap metadata checks from one callback instead of chaining 16-path scheduled batches; the dedicated case remained red at 2232.86 ms.
- The second attempt is saved at `/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/f595f2d2-149b-4647-823a-8ac3e0469c96/stuck-attempt-1b.diff`; production edits were reverted and the existing red performance regression remains.
