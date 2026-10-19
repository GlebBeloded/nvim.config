## Why

Kind: refactor

Depends: refactor-tree-shared-core, refactor-references-kind

Oversized modules mixing responsibilities (2026-10-19 inventory):

- `lua/gleb/file_tree/view.lua` (1151 lines, 61 functions, 13 autocmds): editor-window tracking, drawing, folding,
  opening, directory hijack, teardown, migration.
- `lua/gleb/file_tree/ops.lua` (823 lines, 42 functions): move/rename, copy/paste, delete/trash.
- `lua/gleb/diff/view/init.lua` (765 lines): mappings, redraw scheduling, sync, autocmds and the public API.
- `lua/gleb/references/view.lua` (727 lines): segment formatting, preview, layout; `references/kind.lua` (649 lines):
  LSP request flow plus rules (a review asked to split `append_origin_writes`, `kind.lua:168`).

## What Changes

- Split each by responsibility (e.g. file tree: `editor.lua`, `lifecycle.lua` for autocmds/hijack/quit, `folds.lua`;
  ops: `ops/move.lua`, `ops/clipboard.lua`, `ops/delete.lua`; diff view: mappings and autocmds out of `init.lua`;
  references: formatting and preview out of `view.lua`, request flow out of `kind.lua`), following docs/architecture.md
  Conventions §1 and §9. Public module entry points stay where callers require them.
- Pure moves: no behaviour change, every test unchanged except `require` paths.

## Impact

- The modules above and their requirers.
