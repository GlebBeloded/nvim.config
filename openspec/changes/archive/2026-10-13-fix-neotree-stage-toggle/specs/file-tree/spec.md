## ADDED Requirements

### Requirement: Git status staging matches exact paths
In the `git_status` tree, `<space>` on a file node SHALL treat the file as staged only if git reports staged changes for the exact pathspec of its absolute path (`git diff --cached --quiet -- <path>` run in the tree root), independent of the current working directory. It SHALL run `git add` or `git reset` with an argument list (no shell) and, on a non-zero exit, notify `Stage failed: <stderr>` or `Unstage failed: <stderr>` at ERROR.

#### Scenario: Space stages a file whose name is a suffix of a staged file
- **WHEN** `aa.lua` is staged, `a.lua` is modified and unstaged, the cursor is on the `a.lua` file node and `<space>` is pressed in normal mode
- **THEN** both `a.lua` and `aa.lua` appear in `git diff --cached --name-only`

#### Scenario: Space stages when cwd is outside the repository
- **WHEN** the cwd is a directory outside the repository, the tree was opened with `:Neotree git_status dir=<repo>`, `a.lua` is modified and unstaged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `a.lua` appears in `git diff --cached --name-only` run in the repository

#### Scenario: Space unstages when cwd is outside the repository
- **WHEN** the cwd is a directory outside the repository, the tree was opened with `:Neotree git_status dir=<repo>`, `a.lua` is staged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `a.lua` no longer appears in `git diff --cached --name-only` run in the repository

#### Scenario: Space stages from a subdirectory cwd
- **WHEN** the cwd is the subdirectory `sub` of the repository, `sub/x.lua` is modified and unstaged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `sub/x.lua` appears in `git diff --cached --name-only`

#### Scenario: Space unstages from a subdirectory cwd
- **WHEN** the cwd is the subdirectory `sub` of the repository, `sub/x.lua` is staged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `sub/x.lua` no longer appears in `git diff --cached --name-only`

#### Scenario: Space reports a staging failure
- **WHEN** `.git/index.lock` exists, the cursor is on an unstaged file node and `<space>` is pressed in normal mode
- **THEN** a notification starting with `Stage failed:` at ERROR is emitted

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
- **WHEN** the cursor is on a file node whose repository path is not in `git diff --cached --name-only` and `<space>` is pressed in normal mode
- **THEN** `git add <path>` is run, the path appears in `git diff --cached --name-only`, and the `git_status` source is refreshed

#### Scenario: Space unstages a staged file
- **WHEN** the cursor is on a file node whose repository path is in `git diff --cached --name-only` and `<space>` is pressed in normal mode
- **THEN** `git reset -q -- <path>` is run and the path no longer appears in `git diff --cached --name-only`
