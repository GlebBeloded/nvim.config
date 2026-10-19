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

## What Changes


- Watch every expanded (listed) directory, or, when a handle limit is needed, choose the watched set by what is
  visible and near the cursor, not alphabetically, and fall back to a cheap periodic rescan of unwatched expanded
  directories so no listed directory goes stale. Probe the actual per-process limit of `vim.uv.new_fs_event` on macOS
  before choosing.
- Make compact-chain member watches arrive reliably (the cause the probe shows), so both cases pass in repeated whole-file
  runs under load.
- Add a scenario: with more expanded directories than the old limit, a file created outside Neovim in the last one
  appears in the tree.

## Impact

- `lua/gleb/file_tree/watch.lua` (and `view.lua` if the watched set follows visibility).
- Runs after `file-tree-performance`, which touches the same file.
