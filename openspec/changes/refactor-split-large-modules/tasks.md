## 1. Extract file-tree editor lifecycle
Scenarios: `file-tree: Directory argument opens the project tree`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_hijack.lua CASE="Directory argument opens the project tree"` and see it pass, move editor-window tracking and directory hijack/teardown into `lua/gleb/file_tree/editor.lua` and `lua/gleb/file_tree/lifecycle.lua`, keep `lua/gleb/file_tree/view.lua` as the public entry point, run it again and see it pass

## Agent decisions

- Lifecycle receives view callbacks so teardown and hijacking move out without creating a module cycle.
- Folds receive drawing hooks so fold coordination moves out without creating a module cycle.
- The public ops module keeps thin move wrappers because clipboard paste also dispatches through `M.move`.
- The clipboard module owns the shared operation-state table so public state inspection stays stable across the extraction.
- The deletion module receives the public operation state so trash overrides keep following resets without duplicate state.
- Diff mappings receive the public window registry so they can preserve routing without creating a module cycle.
- Diff autocmds receive redraw and index-refresh callbacks so event ownership moves out without creating a module cycle.
- References layout receives render and preview callbacks so geometry moves out without creating a module cycle.
- References preview owns cursor-following autocmds and selection state so the view only supplies layout callbacks.

## 2. Extract file-tree folds
Scenarios: `file-tree: za toggles a nest`
- [x] 2.1 Run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see it pass, move fold and nest-opening coordination into `lua/gleb/file_tree/folds.lua`, preserve the public functions in `lua/gleb/file_tree/view.lua`, run it again and see it pass

## 3. Extract file-tree moves
Scenarios: `file-tree: Project tree r renames a file and its buffer`
- [x] 3.1 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree r renames a file and its buffer"` and see it pass, move rename and move implementation into `lua/gleb/file_tree/ops/move.lua` while preserving `lua/gleb/file_tree/ops.lua` as the public entry point, run it again and see it pass

## 4. Extract file-tree clipboard operations
Scenarios: `file-tree: Project tree c and p copy a file into another folder`
- [x] 4.1 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree c and p copy a file into another folder"` and see it pass, move copy, cut, paste, and create helpers into `lua/gleb/file_tree/ops/clipboard.lua`, run it again and see it pass

## 5. Extract file-tree deletion
Scenarios: `file-tree: Project tree d moves a file to the Trash after confirmation`
- [x] 5.1 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree d moves a file to the Trash after confirmation"` and see it pass, move trash, permanent-delete, and deleted-buffer cleanup into `lua/gleb/file_tree/ops/delete.lua`, run it again and see it pass

## 6. Extract diff-view mappings
Scenarios: `diff: Diff view mappings come from diff actions`
- [x] 6.1 Run `make test FILE=tests/integration/diff/test_view_close.lua CASE="Diff view mappings come from diff actions"` and see it pass, move mapping installation and restoration into `lua/gleb/diff/view/mappings.lua` while preserving `lua/gleb/diff/view/init.lua` as the public entry point, run it again and see it pass

## 7. Extract diff-view autocmds
Scenarios: `diff: Diff view re-diffs after an edit`
- [x] 7.1 Run `make test FILE=tests/integration/diff/test_view_keys.lua CASE="Diff view re-diffs after an edit"` and see it pass, move redraw scheduling, buffer attachment, window synchronization, and interaction autocmds into `lua/gleb/diff/view/autocmds.lua`, run it again and see it pass

## 8. Extract references formatting and layout
Scenarios: `references: Wide view matches reference screenshot`
- [x] 8.1 Run `make test FILE=tests/screen/references/test_view.lua CASE="Wide view matches reference screenshot"` and see it pass, move segment formatting into `lua/gleb/references/format.lua` and geometry/layout into `lua/gleb/references/layout.lua`, run it again and see it pass

## 9. Extract references preview coordination
Scenarios: `references: Preview follows the selection`
- [x] 9.1 Run `make test FILE=tests/integration/references/test_preview.lua CASE="Preview follows the selection"` and see it pass, move preview lifecycle and selection-following coordination from `lua/gleb/references/view.lua` into `lua/gleb/references/preview.lua`, run it again and see it pass

## 10. Extract reference-kind request flow
Scenarios: `references: The view opens before classification finishes`
- [ ] 10.1 Run `make test FILE=tests/integration/references/test_kind_view.lua CASE="The view opens before classification finishes"` and see it pass, move highlight, tsserver, target-kind, timeout, and completion request orchestration into `lua/gleb/references/kind_request.lua`, split `append_origin_writes` into small named helpers, and keep `lua/gleb/references/kind.lua` as the classification entry point, run it again and see it pass
