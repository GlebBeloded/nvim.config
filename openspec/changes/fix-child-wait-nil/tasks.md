## 1. Make child waits reject RPC nil without racing picker input
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree Enter toggles a folder`, `file-tree: za toggles a nest`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree Enter toggles a folder"`, and `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see them pass; change `tests/helpers.lua` so `child.wait` treats nil, `vim.NIL`, and false as not ready, synchronize the existing keymap case's typing with the real Find Action picker's main window in `tests/integration/file-tree/test_project_tree.lua` without changing its assertions, then run the same commands again and see them pass

## Blocked

- Should Find Action add combined `Category Title` matching? Option 1: add a find-action requirement, spec-delta scenario, and direct test so `project open` can select `file_tree.open`. Option 2: retain separate-field matching and change this file-tree scenario so it does not require an impossible query to select that action. Recommend option 1 because the existing case intentionally exercises that action through the real picker.
