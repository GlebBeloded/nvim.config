## 1. Make child waits reject RPC nil without racing picker input
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree Enter toggles a folder`, `file-tree: za toggles a nest`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree Enter toggles a folder"`, and `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see them pass; change `tests/helpers.lua` so `child.wait` treats nil, `vim.NIL`, and false as not ready, synchronize the existing keymap case's typing with the real Find Action picker's main window in `tests/integration/file-tree/test_project_tree.lua` without changing its assertions, then run the same commands again and see them pass

## Agent decisions

- Multi-word queries also match the combined category and title so natural phrases work without broadening single-token fuzzy results.
