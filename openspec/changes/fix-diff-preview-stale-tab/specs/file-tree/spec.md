## MODIFIED Requirements

### Requirement: Git status open, close and staging actions
In the `git_status` tree, normal-mode mappings SHALL be: `<cr>` closes any diff preview, reveals the file in the `filesystem` source, moves one window right and edits the file; `q` returns to the original tab via `diff_preview.return_to_original()` then runs `:Neotree close`; `<space>` toggles staging of the node's path; `A` stages all (`git_add_all`); `gr` reverts the file (`git_revert_file`).

#### Scenario: Enter opens file and switches to filesystem tree
- **WHEN** the cursor is on a file node in the `git_status` tree and `<cr>` is pressed in normal mode
- **THEN** no diff preview tab remains, the tree shows the `filesystem` source with the file revealed, and a non-tree window's buffer is that file

#### Scenario: q closes preview and tree
- **WHEN** a diff preview tab was opened from the `git_status` tree while tab T was current, and `q` is pressed in normal mode in the tree
- **THEN** the current tab is T, the diff tab is closed, `diff_preview.state.current_file` and `diff_preview.state.original_tab` are nil, and no `neo-tree` window is open in the current tab

#### Scenario: Space stages an unstaged file
- **WHEN** the cursor is on a file node whose cwd-relative path is not in `git diff --cached --name-only` and `<space>` is pressed in normal mode
- **THEN** `git add <path>` is run, the path appears in `git diff --cached --name-only`, and the `git_status` source is refreshed

#### Scenario: Space unstages a staged file
- **WHEN** the cursor is on a file node whose cwd-relative path is in `git diff --cached --name-only` and `<space>` is pressed in normal mode
- **THEN** `git reset -- <path>` is run and the path no longer appears in `git diff --cached --name-only`

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
- **THEN** `state.original_tab` and `state.diff_tab` are nil, `state.navigating_until` is 0, and `vim.api.nvim_get_autocmds({ group = "DiffPreviewFocusGuard" })` is empty

#### Scenario: Next preview records the new original tab
- **WHEN** `diff_preview.open_diff(a)` completed from tab T1, `diff_preview.return_to_original()` was called, `:tabnew` makes tab T2 current, and `diff_preview.open_diff(b)` completes
- **THEN** `state.original_tab` equals T2 and `diff_preview.return_to_original()` makes T2 the current tab
