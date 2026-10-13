# Spec Delta

## MODIFIED Requirements

### Requirement: Diff preview focus and closing
`diff_preview.focus_neo_tree()` SHALL focus the first window with filetype `neo-tree` in the current tab and return true, or return false if none exists. While `state.navigating_until` is in the future, entering a window whose filetype is neither `neo-tree` nor empty SHALL refocus the tree. `close_all_diffs()` (alias `return_to_original()`) SHALL switch to `state.original_tab` if valid, close `state.diff_tab` if valid, clear the focus-guard autocmds and restore the initial state.

#### Scenario: Focus returns false without neo-tree
- **WHEN** no neo-tree window exists in the current tab and `diff_preview.focus_neo_tree()` is called
- **THEN** it returns false

#### Scenario: Focus moves to neo-tree
- **WHEN** `:Neotree filesystem` is open, `:wincmd l` moves focus away, and `diff_preview.focus_neo_tree()` is called
- **THEN** it returns true and the current window's filetype is `neo-tree`

#### Scenario: Focus guard pulls focus back during navigation
- **WHEN** a diff tab was opened by `open_diff` and, within 300 ms of the call, a diff window is entered
- **THEN** after the scheduled callback the current window's filetype is `neo-tree`

#### Scenario: Return to original tab
- **WHEN** `state.original_tab` is tab T, `:tabnew` creates tab D stored in `state.diff_tab`, and `diff_preview.return_to_original()` is called
- **THEN** the current tab is T

#### Scenario: Return clears current file
- **WHEN** `state.current_file` is `/some/file` and `diff_preview.return_to_original()` is called
- **THEN** `state.current_file` is nil

#### Scenario: Return clears tab state and focus guard
- **WHEN** `diff_preview.open_diff(p)` has completed for a git-tracked file and `diff_preview.return_to_original()` is called
- **THEN** `state.original_tab` and `state.diff_tab` are nil, `state.navigating_until` is 0, and `vim.api.nvim_get_autocmds({ group = "gleb_file_tree_focus_guard" })` is empty

#### Scenario: Next preview records the new original tab
- **WHEN** `diff_preview.open_diff(a)` completed from tab T1, `diff_preview.return_to_original()` was called, `:tabnew` makes tab T2 current, and `diff_preview.open_diff(b)` completes
- **THEN** `state.original_tab` equals T2 and `diff_preview.return_to_original()` makes T2 the current tab

#### Scenario: Return cancels a pending preview
- **WHEN** `diff_preview.open_diff(p)` is called and `diff_preview.return_to_original()` runs before the debounced open completes
- **THEN** no diff tab is created and `state.original_tab` stays nil
