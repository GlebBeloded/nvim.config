## 1. Make child waits reject RPC nil without racing picker input
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree Enter toggles a folder`, `file-tree: za toggles a nest`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree Enter toggles a folder"`, and `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see them pass; change `tests/helpers.lua` so `child.wait` treats nil, `vim.NIL`, and false as not ready, synchronize the existing keymap case's typing with the real Find Action picker's main window in `tests/integration/file-tree/test_project_tree.lua` without changing its assertions, then run the same commands again and see them pass
- [ ] 1.2 Make the Find Action matcher search a multi-word query against the combined `Category Title` value in that order while keeping independent title, category, and alias matching unchanged; add the unit scenario `find-action: Multi-word query spans category and title` covering the `project open` hit, reverse-order behavior, and unchanged single-word matching

## Agent decisions

- Complete the first project-tree draw when the initial Git request finishes, because a fixed fallback deadline can render ignored rows under load.
- Should combined `Category Title` matching become a Find Action requirement? Choose option 1 and add its own scenario and regression test, because `project open` cannot uniquely reach `file_tree.open` through its separate title, category, or absent aliases.
