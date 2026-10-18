## 1. Make child waits reject RPC nil
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree Enter toggles a folder`, `file-tree: za toggles a nest`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree Enter toggles a folder"`, and `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see them pass, change `tests/helpers.lua` so `child.wait` treats nil, `vim.NIL`, and false as not ready, then run them again; record the resulting `Project Open action did not match` failure for the first case and the passing results for the other two

## 2. Match multi-word queries across category and title
Scenarios: `find-action: Multi-word query spans category and title`
- [x] 2.1 Write the test `find-action: Multi-word query spans category and title` in `tests/unit/find-action/test_items.lua`, driving `require("gleb.find_action.items").match` with populated actions; cover the `project open` hit, reverse-order miss, and unchanged single-word title, category, and alias matches, then run `make test FILE=tests/unit/find-action/test_items.lua CASE="Multi-word query spans category and title"` and see it fail
- [x] 2.2 Change `lua/gleb/find_action/items.lua` so a multi-word query also fuzzy-matches the combined `Category Title` value in that order while preserving separate title, category, and alias matching
- [x] 2.3 Run `make test FILE=tests/unit/find-action/test_items.lua CASE="Multi-word query spans category and title"` and see it pass

## 3. Restore the real Find Action picker regression
Scenarios: `file-tree: Project tree keys come from the keymap file`
- [x] 3.1 Restore `project open` in `tests/integration/file-tree/test_project_tree.lua` and remove the `open` plus `<C-n><C-n>` workaround while keeping the existing assertions; with a temporary fault that disables combined category-title matching, run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, see `Project Open action did not match`, record the failure, then remove the fault
- [x] 3.2 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"` and see it pass

## Agent decisions

- Complete the first project-tree draw when the initial Git request finishes, because a fixed fallback deadline can render ignored rows under load.
- Should combined `Category Title` matching become a Find Action requirement? Choose option 1 and add its own scenario and regression test, because `project open` cannot uniquely reach `file_tree.open` through its separate title, category, or absent aliases.
