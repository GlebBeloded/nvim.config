## Why

Kind: bug
Depends: file-tree-performance

Only the first 256 directories (alphabetically) get a filesystem watch (`MAX_WATCH_HANDLES`,
`lua/gleb/file_tree/watch.lua:9`). With 1000 folders expanded in a 9.8k-file repo, writing a file or creating 200 files
in a directory past the first 256 (`domain/mocks`) produced no watcher redraw at all (probe from
`file-tree-performance`, 2026-10-19): the tree silently stops following outside changes.

Also intermittent on `auto` with working file events (2026-10-19 12:40, load ~20, fresh fseventsd): `file-tree: A
compact chain splits when a folder gains an entry` and `file-tree: Every compact chain member is watched`
(`tests/integration/file-tree/test_project_live.lua`) failed together in 1 of 2 whole-file runs and in the round120 full
check. Probe whether a compact chain's deeper members get a watch in time (and under the handle limit) before choosing
a fix; the cases' assertions and bounds stay.

## Evidence

- `lua/gleb/file_tree/watch.lua:225`: `wanted_paths()` sorts scan paths alphabetically and truncates them at
  `MAX_WATCH_HANDLES`; paths after that prefix have neither a watch nor a fallback refresh.
- `lua/gleb/file_tree/view.lua:325`: every scan feeding the rendered tree is requested, but the cached scans in
  `lua/gleb/file_tree/fs.lua:65` are invalidated only after a watch callback, so omitted paths remain stale.
- A macOS headless probe opened 4096 concurrent `vim.uv.new_fs_event` handles successfully on 2026-10-19; no
  per-process failure was observed at or near 256.
- `lua/gleb/file_tree/view.lua:359` renders before `watch.sync()` and `lua/gleb/file_tree/watch.lua:249` defers handle
  installation with `vim.schedule()`. A focused five-run probe reproduced the unchanged timing failure once:
  `FAIL in tests/integration/file-tree/test_project_live.lua | file-tree: A compact chain splits when a folder gains an entry`.
- The earlier whole-file and round120 evidence also recorded:
  `FAIL in tests/integration/file-tree/test_project_live.lua | file-tree: Every compact chain member is watched`.

## What Changes


- Watch every expanded (listed) directory, or, when a handle limit is needed, choose the watched set by what is
  visible and near the cursor, not alphabetically, and fall back to a cheap periodic rescan of unwatched expanded
  directories so no listed directory goes stale. Probe the actual per-process limit of `vim.uv.new_fs_event` on macOS
  before choosing.
- Make compact-chain member watches arrive reliably (the cause the probe shows), so both cases pass in repeated whole-file
  runs under load.
- Add a scenario: with more expanded directories than the old limit, a file created outside Neovim in the last one
  appears in the tree.
- Keep a configurable safety cap for tests or platforms that need one, prioritize watched paths by the rendered view,
  and periodically invalidate and rescan every unwatched listed directory. Make initial compact-chain watches settle
  before an external change can be missed, and retry failed watch starts through the same reconciliation path.

## Impact

- `lua/gleb/file_tree/watch.lua` and `lua/gleb/file_tree/view.lua` change watcher selection, fallback rescans, and initial
  watch reconciliation; this does not change module layout, load order, or plugin wiring.
- `tests/integration/file-tree/test_project_live.lua` adds the beyond-limit regression and keeps the compact-chain
  timing assertions unchanged.
- Runs after `file-tree-performance`, which touches the same file.
- No plugin dependency is added, removed, or upgraded. Core keymaps do not change.
- Out of scope: changing tree rows, icons, layout, the 1000 ms live-update bounds, or general file-tree performance work
  beyond preventing unwatched listed directories from becoming stale.
