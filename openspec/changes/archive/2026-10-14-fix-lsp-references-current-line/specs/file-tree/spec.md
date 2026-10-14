# Spec Delta

## MODIFIED Requirements

### Requirement: Git status revert and key ownership
In the `git_status` tree, normal-mode `X` SHALL ask `Are you sure you want to revert <name>?` and revert the file only when confirmed (`git_revert_file`). The tree SHALL set no buffer-local `gr` mapping, so the global `gr` applies, and `c` SHALL be the common `copy` mapping.

#### Scenario: X reverts a file after confirmation
- **WHEN** the cursor is on the file node `a.txt` with an unstaged change in the `git_status` tree, `X` is pressed in normal mode and the prompt `Are you sure you want to revert a.txt?` is answered yes
- **THEN** `a.txt` has its `HEAD` content and `git status --porcelain` no longer lists it

#### Scenario: X keeps a file when revert is declined
- **WHEN** the cursor is on the file node `a.txt` with an unstaged change in the `git_status` tree, `X` is pressed in normal mode and the prompt is answered no
- **THEN** `a.txt` keeps its working-tree content and `git status --porcelain` still lists it

#### Scenario: gr keeps its global meaning in git status tree
- **WHEN** the `git_status` tree buffer is current and `vim.fn.maparg("gr", "n", false, true)` is read
- **THEN** the result is the global mapping (`buffer` is 0) whose callback invokes Telescope `lsp_references` with `include_current_line = true`

#### Scenario: c is copy in git status tree
- **WHEN** the `git_status` tree buffer is current and the buffer-local normal-mode mapping for `c` is read with `nvim_buf_get_keymap(0, "n")`
- **THEN** its `desc` is `copy`
