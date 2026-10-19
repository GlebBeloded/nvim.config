## Why

Kind: feature

The project tree lags: every redraw rebuilds the whole tree, and its cost grows with the visible rows. Measured with
`make probe` on the full config (headless, module fields monkey-patched, `jit.profile`; probe kept as
`openspec/changes/file-tree-performance/probe.lua`, run it the same way before and after), on copies of
this config (1,227 visible rows, refreshed 2026-10-19) and a 9.8k-file repo (4.7k visible rows):

| visible rows | `draw` (view.lua:275) | `model.rows` | `render.draw` |
|---|---|---|---|
| 50–100 | 6–20 ms | 5–17 ms | 0.5–2 ms |
| 1,227 | 149 ms | 112 ms | 6.5 ms |
| 4.7k | 310–420 ms | 290–570 ms | 16–46 ms |

Cursor movement and scrolling are fine (~0.03 ms per key, no redraw). The refreshed first paint takes 309–337 ms
(`toggle()` blocks 29–33 ms, then waits for git status or the 300 ms fallback).

## Evidence

1. `vim.uv.fs_realpath` on every directory scan, cached scans included (`lua/gleb/file_tree/fs.lua:104`): 83 % of
   profile samples (491/588 on the large repo, 148/179 on the refreshed config run), 40–60 µs per call vs 2.5 µs for `fs_stat`;
   `compact_directory` (`model.lua:398`) rescans the same directories.
2. No redraw reuse or coalescing: one redraw is a full `fs.tree` + `model.rows` + namespace clear +
   `set_lines(0, -1)` + ~2.3 extmarks per row (11k at 4.7k rows, `render.lua:144-162`). Expanding a folder builds rows
   twice (`view.lua:421` for the 5000-row cap, then `draw` at `view.lua:299`): 924 ms per expand at 4.7k rows.
3. Every git callback redraws (`git.lua:163`) even when the status did not change: 81 ms on the refreshed clean
   config repo and 355–420 ms on the large repo.
4. A file save causes 2 full redraws and 2 `git status` runs (the watcher redraw at `watch.lua:55` and the git callback
   at `git.lua:164` do not coalesce; BufWritePost's `git.request` and the watcher's `refresh_git` re-queue through the
   `dirty` flag): 358 ms of blocking in the refreshed config run and 180–500 ms across the earlier runs.
5. Every BufEnter redraws the whole tree (`view.lua:715` → `select_path` → `draw`) even when the row is already
   listed: 312 ms (large repo), 97 ms (refreshed config).
6. Other synchronous main-thread work: `git rev-parse` with `:wait()` at `watch.lua:95-99` (85–96 ms per open or
   re-root); `watch.sync` → `sync_handles` opens and closes watch handles synchronously (68–237 ms after a large
   expand, 206 ms after a collapse, `watch.lua:168-200`); `expanded.flush` (`expanded.lua:51`) blocks 6–48 ms every
   500 ms after changes.
7. `unfold_all` is quadratic (`view.lua:580-627`: `model.rows` per folder, 632 calls, 7.95M `is_ignored` calls):
   43.3 s for 2,207 rows in the refreshed config run.

Not a problem: the `git status` process (async, parse < 1.1 ms), nesting rules (3.5–17 ms per rebuild, cached), devicons
(~1 ms).

## What Changes

- Resolve real paths only for symlink entries (or cache them with the scan); no per-scan `fs_realpath` of every
  directory; `compact_directory` reuses the scan.
- One coalesced redraw per view: watcher, git callback, follow and BufWritePost mark the view dirty and schedule a
  single draw (16–50 ms debounce); one `git status` per burst.
- Skip the redraw when a git result's status map equals the last one.
- BufEnter / follow moves the cursor to an already listed row instead of redrawing.
- Expand builds the rows once and hands them to `draw`.
- `git rev-parse` at open/re-root runs async; watch-handle sync runs in deferred batches; `expanded.flush` writes off
  the main path (async `vim.uv` file I/O).
- `unfold_all` builds the expanded set in one pass, counting rows as it goes (linear).
- Add spec requirements with time bounds measured by the probe on the fixture repos the tests use (a redraw of
  N rows, a save, a BufEnter, unfold all), so the gains stay; keep every existing project-tree scenario.

## Impact

- `lua/gleb/file_tree/{fs,model,view,git,watch,expanded,render}.lua`.
- Capability: `file-tree` gains responsiveness, coalescing and deferred-maintenance requirements.
- Tests: integration timing cases on a generated large fixture (thousands of files) under `H.load_factor()`, plus the
  existing project-tree cases unchanged.
- Expected: a 4.7k-row redraw from ~400 ms to well under 100 ms; a save and a BufEnter no longer block for hundreds of
  ms (measure before and after with the probe and record both in tasks.md).
- No plugin dependency is added, removed or upgraded.
- Core keymaps do not change.
- Out of scope: changing tree rows, colours, layout, keys, the 5000-row safety cap, ignore semantics, nesting semantics,
  or git-status classification.
- `file-tree: Requirement: Project tree folds` still holds because the fold actions and 5000-row warning are unchanged.
- `file-tree: Requirement: Project tree path normalization` still holds because roots and symlinks remain normalized;
  only redundant resolution during scans is removed.
- `file-tree: Requirement: Project tree keys` still holds because no action or mapping changes.
- `file-tree: Requirement: File tree nest actions` still holds because fold, unfold, follow and reveal keep their effects.
- `file-tree: Ignored folders do not compact or consume unfold budget` still holds because the linear walk preserves the
  ignored-folder gate and counts only listed rows.
- `shortcuts: The load factor is 1 on an idle host` still holds and supplies the timing-test multiplier.
- `shortcuts: The load factor is the load per CPU on a busy host` still holds and supplies the timing-test multiplier.
- `shortcuts: The stack harness wait stretches with host load` still holds because stack deadlines are untouched.
- `shortcuts: The stack harness wait keeps its timeout on an idle host` still holds because stack deadlines are untouched.
- `statusline: stale task is removed` still holds because statusline progress state is untouched.
- `statusline: report keeps a task fresh` still holds because statusline progress state is untouched.

## Decision (auditor, 2026-10-19, mid task loop)

- Task 2 (coalesced refresh): a git result that arrives after the coalesced draw must still update the rows' status (the
  stuck case: one replacement, one git run, row `status = nil`). One draw per burst, plus one when the git map changes;
  never zero after a status change.
- `expanded.flush` stays synchronous on `VimLeavePre` (async writes are fine during the session): expansion state set in
  the last 500 ms before quit must survive a restart. Add a scenario for it.
- Opening the tree draws once with the saved expansion already applied (no collapsed frame followed by the expanded
  one), and a re-root draws once; assert the buffer replacement count in both.
- The new timing cases' fixed setup waits (`start()`'s 3000 ms git settle, `wait_for_save_result`'s 1000 ms) scale with
  `H.load_factor()` like the bounds do; the bounds themselves stay as the spec states.
