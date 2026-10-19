## Why

Kind: refactor

Depends: refactor-tree-shared-core, refactor-references-kind

Oversized modules mixing responsibilities (2026-10-19 inventory):

- `lua/gleb/file_tree/view.lua` (1309 lines, 67 functions, 13 autocmds): editor-window tracking, drawing, folding,
  opening, directory hijack, teardown, migration.
- `lua/gleb/file_tree/ops.lua` (823 lines, 42 functions): move/rename, copy/paste, delete/trash.
- `lua/gleb/diff/view/init.lua` (762 lines): mappings, redraw scheduling, sync, autocmds and the public API.
- `lua/gleb/references/view.lua` (727 lines): segment formatting, preview, layout; `references/kind.lua` (631 lines):
  LSP request flow plus rules (a review asked to split `append_origin_writes`, `kind.lua:168`).

## What Changes

- Split each by responsibility (e.g. file tree: `editor.lua`, `lifecycle.lua` for autocmds/hijack/quit, `folds.lua`;
  ops: `ops/move.lua`, `ops/clipboard.lua`, `ops/delete.lua`; diff view: mappings and autocmds out of `init.lua`;
  references: formatting and preview out of `view.lua`, request flow out of `kind.lua`), following docs/architecture.md
  Conventions §1 and §9. Public module entry points stay where callers require them.
- Pure moves: no behaviour change, every test unchanged except `require` paths.

## Impact

- Module layout changes in `lua/gleb/file_tree/view.lua`, with responsibilities moving to
  `lua/gleb/file_tree/editor.lua`, `lua/gleb/file_tree/lifecycle.lua`, and `lua/gleb/file_tree/folds.lua`.
- Module layout changes in `lua/gleb/file_tree/ops.lua`, with implementations moving to
  `lua/gleb/file_tree/ops/move.lua`, `lua/gleb/file_tree/ops/clipboard.lua`, and `lua/gleb/file_tree/ops/delete.lua`.
- Module layout changes in `lua/gleb/diff/view/init.lua`, with mappings and event handling moving to
  `lua/gleb/diff/view/mappings.lua` and `lua/gleb/diff/view/autocmds.lua`.
- Module layout changes in `lua/gleb/references/view.lua`, `lua/gleb/references/preview.lua`, and
  `lua/gleb/references/kind.lua`, with formatting/layout moving to `lua/gleb/references/format.lua` and
  `lua/gleb/references/layout.lua`, and kind-request orchestration moving to `lua/gleb/references/kind_request.lua`.
- Requirers keep using the existing public module entry points.
