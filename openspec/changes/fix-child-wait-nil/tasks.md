## 1. Make child waits reject RPC nil without racing picker input
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree Enter toggles a folder`, `file-tree: za toggles a nest`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree Enter toggles a folder"`, and `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see them pass; change `tests/helpers.lua` so `child.wait` treats nil, `vim.NIL`, and false as not ready, synchronize the existing keymap case's typing with the real Find Action picker's main window in `tests/integration/file-tree/test_project_tree.lua` without changing its assertions, then run the same commands again and see them pass

## Agent decisions

- Complete the first project-tree draw when the initial Git request finishes, because a fixed fallback deadline can render ignored rows under load.

## Blocked

- Should Find Action make combined `Category Title` text searchable? Option 1: require combined matching, restore the `Multi-word query spans category and title` scenario and regression case, and keep `project open` in the integration case. Option 2: keep title, category, and aliases as separate fields, retain explicit picker navigation for `open`, and leave the named combined-field scenario unsupported. Recommend option 1 because the proposal's existing `## Decision` already approves it and it is the only option that preserves the required named scenario.
