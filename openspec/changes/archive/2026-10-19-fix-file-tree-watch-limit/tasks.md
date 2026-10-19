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
- Keep live watches whose folders stay listed ahead of the priority order and fill only free slots by visibility and cursor proximity: each macOS `fs_event` stop blocks the main loop, so a cursor jump swapping the whole capped set stalled the fold for seconds.
- Check unwatched folders by an asynchronous directory mtime stamp, taken before each scan, and rescan only changed folders asynchronously, so the fallback never scans on the main loop.
- On macOS and Windows, cover listed folders without their own handle by one recursive root watch (counted as watched for the fallback clause) and poll only where libuv lacks recursive watches: polling 1744 folders every 250 ms in parallel large-tree children slowed FSEvents delivery and git status in every other test.
- Poll every listed folder for two 250 ms passes after any watch start or stop: libuv rebuilds its single FSEvents stream then and drops events, which instrumented runs showed for compact-chain and beyond-limit changes.
- Report a stale cached scan once per cache entry, so a catch-up pass never repeats a watch event's redraw and git refresh while the view's redraw is still pending.
