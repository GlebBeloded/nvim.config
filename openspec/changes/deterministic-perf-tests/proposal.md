## Why

Kind: feature
Priority: high

Loop audit (2026-10-20): wall-clock bounds flake under the gate's load (load average 25–60 on 14 cores):
`tests/integration/file-tree/test_performance.lua` — "re-roots without waiting for repository discovery" (8 runs),
"coalesces a save burst" (5), "unfold all meets the large-tree bound", "save leaves the main path promptly" — plus
`lsp: Type-check toggle reattaches every Python buffer without reloading`. Independent review: the bounds span several
RPC round trips, `H.load_factor()` uses the lagging 1-minute load average, the coalesce case races a 150 ms git debounce
against late fs events, and several waits (`child.wait` 2000 ms default, `ASYNC_MS=3000`, re-root's 1000 ms settle)
are not load-scaled.

## What Changes

- Performance assertions measure what they mean without RPC noise: time inside one `child.lua` call, CPU time
  (`vim.uv.getrusage`) or operation counts (scans, `set_lines`, synchronous `vim.system():wait()` calls) as the main
  assertion; structural assertions where the intent is "does not wait" (re-root: discovery not complete right after `cd`).
- Debounce-coalescing cases use an injected/manual debounce clock instead of real timers.
- Pure wall-time bounds move to a serial `make perf` layer that `make check` runs alone; the parallel layer keeps the
  correctness assertions. `child.wait`'s default timeout and the unscaled waits scale with load.
- No bound is loosened without a load-scaled reason.

## Capabilities

- `file-tree`: make large-tree, coalescing and deferred-maintenance performance checks deterministic while preserving their bounds.
- `shortcuts`: extend the shared test-harness deadline policy to child-Neovim waits.

## Impact

- `tests/integration/file-tree/test_performance.lua`, `tests/helpers.lua`, `lua/gleb/util/debounce.lua` (a test hook),
  `Makefile`/`tests/check.sh` (the `perf` layer).
- `tests/integration/lsp/test_typecheck.lua`; `lsp: Type-check toggle reattaches every Python buffer without reloading` still holds because only its wait budget changes, not the command or attachment assertions.
- `file-tree: Expanded ignored folder lists ignored children` still holds because manual debounce control changes when the existing callback runs, not ignored-folder expansion, colouring or git calls.
- `statusline: Statusline pull request component runs nothing on redraw` still holds because the shared wait and performance-test changes do not touch statusline redraw code.
- No plugin dependency is added, removed or upgraded. Core keymaps do not change.
- Out of scope: changing project-tree behavior or its numeric performance bounds, changing LSP behavior, and changing editor UI.
