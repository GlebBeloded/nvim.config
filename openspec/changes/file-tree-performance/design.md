## Context

The project tree rebuilds all rows for every refresh. Cached scans still resolve every directory realpath, expansion builds rows twice, independent watcher and git callbacks each draw, and follow redraws even when the target row already exists. Repository discovery, watch reconciliation and expansion-state writes also perform synchronous work on the editor thread.

## Goals / Non-Goals

- Keep a 5000-row tree responsive under redraw, save, follow, expansion and unfold-all operations.
- Preserve every existing row, selection, ignore, nesting, git-colour and safety-cap behavior.
- Keep the current owned file-tree modules and dependencies.
- Do not introduce incremental rendering, change the tree's appearance, or change keys.

## Decisions

### Cache filesystem identity with scan results

Resolve roots and symlink entries for loop detection, but reuse scan identity for ordinary directories and compact-directory traversal. This removes repeated `fs_realpath` calls without weakening normalization or symlink-loop handling.

### Give each view one invalidation scheduler

Watcher, write, follow and git sources mark a view dirty and enter one 50 ms scheduling window. The scheduled work takes one filesystem snapshot, builds one row set and hands it to drawing. Git keeps one request per burst and compares both status maps before invalidating a view.

### Separate selection from reconstruction

Follow first indexes the current prepared rows. A visible target changes only the tree-window cursor; a missing target expands the required ancestors and schedules reconstruction. Expansion validates the row cap against the row set that drawing will consume.

### Move maintenance behind asynchronous boundaries

Repository discovery uses the existing asynchronous process callback. Watch handles are reconciled in bounded deferred batches, and expansion state uses `vim.uv` asynchronous file operations with sequence checks so an older completion cannot replace newer state.

### Traverse unfold-all once

Unfold-all walks eligible directories depth-first, updates the expanded set and counts visible plain and nested rows during that traversal. It stops at the existing cap and performs one final row build and draw.

## Risks / Trade-offs

- Coalescing delays visible updates by up to 50 ms; the existing 1000 ms live-update contract leaves ample margin.
- Deferred callbacks can outlive a view or root; each callback must validate view ownership and its generation before applying state.
- Asynchronous persistence can complete out of order; sequence checks and atomic replacement must preserve the newest expansion set.
- Timing tests can flake on loaded hosts; every tight bound scales with `H.load_factor()` and uses generated deterministic fixtures.

## Migration Plan

No user migration is required. Keep the expansion-state format and all public actions unchanged. Land behind the existing tests, compare the retained probe before and after, then run the full gate.
