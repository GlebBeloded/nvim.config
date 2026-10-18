## 1. Make child waits reject RPC nil without racing picker input
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree Enter toggles a folder`, `file-tree: za toggles a nest`
- [ ] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree keys come from the keymap file"`, `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree Enter toggles a folder"`, and `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see them pass; change `tests/helpers.lua` so `child.wait` treats nil, `vim.NIL`, and false as not ready, synchronize the existing keymap case's typing with the real Find Action picker's main window in `tests/integration/file-tree/test_project_tree.lua` without changing its assertions, then run the same commands again and see them pass

## Stuck

- Saved the second attempt in `/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/1202d6e0-ffef-46c7-ac08-e16859f2bea7/stuck-attempt.diff`.
- Probe: when the picker main window was current (`current_win = main_win = 1002`), MiniPick had 48 items and Neovim remained in normal mode; executing queued `project open` keys selected `find_action.open` at index 2 and ended with `E353: Nothing in register "`.
- Attempt 1 waited for MiniPick to be active with its real main window current before typing; the case still failed with `Project Open action did not match`.
- Attempt 2 additionally waited for `child.is_blocked()` before typing; the case failed with `Find Action picker did not await input`.
