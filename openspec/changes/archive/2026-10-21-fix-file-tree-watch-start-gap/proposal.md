## Why

Kind: bug
Priority: high

Loop audit (2026-10-20), from the gates' rerun history (`.archon/scripts/flake_stats.py`): the most frequent flaky cases
are file-tree watcher cases — "Every compact chain member is watched" (15 runs), "Project tree isolates tabpage state"
(10), "A compact chain splits when a folder gains an entry" (6), "Project tree shows files created outside Neovim" (4),
"Renaming a folder migrates nest state in every view" (4), "Renaming a nest parent migrates its state".

Independent review: on macOS `uv_fs_event_start` only signals libuv's CoreFoundation thread and the FSEvents stream is
rebuilt later, so a change made right after a watch starts (or after `stop_root`) can be missed. The fallback in
`lua/gleb/tree/watch.lua` (`FALLBACK_SETTLE_PASSES=2` polls at `FALLBACK_RESCAN_MS=250`) is time-based, so under load
both polls can finish before the stream is live — a real missed-update bug on a busy machine, not only a test flake.
The tests also mutate the filesystem right after `handles[...] ~= nil`, which does not mean the stream is live.

## What Changes

- The watcher's settle logic counts passes from the first event confirmed after a (re)start, not by elapsed time, so a
  change made in the start gap is still picked up.
- The watcher tests wait for a canary event (touch a known file, wait for its redraw) before the mutation they assert,
  and the nesting cases wait for a copied file's row before renaming. No assertion is weakened.

## Evidence

- `lua/gleb/tree/watch.lua:133` starts a folder watch and `lua/gleb/tree/watch.lua:137` arms only two settle passes;
  starts of the git and recursive watches arm the same counter at `lua/gleb/tree/watch.lua:170` and
  `lua/gleb/tree/watch.lua:536`.
- `lua/gleb/tree/watch.lua:491` decrements those passes on fallback-timer ticks without observing a watch event, and
  `lua/gleb/tree/watch.lua:541` stops fallback coverage when the counter reaches zero.
- `tests/integration/file-tree/test_project_live.lua:395` accepts allocated handles as ready before the external
  mutation, while `tests/integration/file-tree/test_nesting.lua:436` copies a nested child and immediately renames its
  parent without first observing the copied row.

## Impact

- `lua/gleb/tree/watch.lua` and the file-tree watcher tests (`tests/integration/file-tree/test_project_live.lua`,
  `test_nesting.lua`, `test_project_ops.lua`).
- No plugin dependency is added, removed or upgraded, and no core keymap changes.
- Out of scope: changing the project-tree rendering, watch-handle cap, debounce interval, or filesystem backend.
