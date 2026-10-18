## 1. Make child waits reject RPC nil without racing picker input
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree Enter toggles a folder`, `file-tree: za toggles a nest`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree Enter toggles a folder"`, and `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see them pass; change `tests/helpers.lua` so `child.wait` treats nil, `vim.NIL`, and false as not ready, synchronize the existing keymap case's typing with the real Find Action picker's main window in `tests/integration/file-tree/test_project_tree.lua` without changing its assertions, then run the same commands again and see them pass
- [ ] 1.2 Implement combined category-then-title matching for multi-word Find Action queries and add a direct matcher test named after `Multi-word query spans category and title` that covers `project open` matching, reversed field order not matching, and existing single-word matching remaining unchanged

## Agent decisions

- Should Find Action add combined `Category Title` matching? Choose option 1 because it follows the existing `## Decision` and preserves the real-picker scenario's intentional `project open` query and assertions.
