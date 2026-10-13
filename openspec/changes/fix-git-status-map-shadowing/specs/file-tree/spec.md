## MODIFIED Requirements

### Requirement: Git status open, close and staging actions
In the `git_status` tree, normal-mode mappings SHALL be: `<cr>` closes any diff preview, reveals the file in the `filesystem` source, moves one window right and edits the file; `q` returns to the original tab via `diff_preview.return_to_original()` then runs `:Neotree close`; `<space>` toggles staging of the node's path; `A` stages all (`git_add_all`).

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

## REMOVED Requirements

### Requirement: Git status commit and push
**Reason**: Commit moves from `c` to `gc` (Decision 2026-10-12: no shadowing of the common `c` copy map), so the scenarios keyed on `c` no longer describe the key; a MODIFIED block cannot rename a scenario.
**Migration**: Replaced by "Git status AI commit" and "Git status push". "c commits confirmed message" becomes "gc commits confirmed message" and "c reports commit failure" becomes "gc reports commit failure", with the same assertions; the `P` scenarios keep their titles.

## ADDED Requirements

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
- **THEN** the result is the global mapping (`buffer` is 0) whose callback is Telescope `lsp_references`

#### Scenario: c is copy in git status tree
- **WHEN** the `git_status` tree buffer is current and the buffer-local normal-mode mapping for `c` is read with `nvim_buf_get_keymap(0, "n")`
- **THEN** its `desc` is `copy`

### Requirement: Git status AI commit
In the `git_status` tree, normal-mode `gc` SHALL open the AI commit popup (`gleb.git.ai_commit`) and run `git commit -m <message>` as an argument list for a confirmed message; on exit 0 it SHALL refresh the `git_status` source and notify `Committed: <first line of message>` at INFO, otherwise notify `Commit failed: <git stderr>` at ERROR. `?` help SHALL label `gc` `commit (AI)`.

#### Scenario: gc commits confirmed message
- **WHEN** `gc` is pressed in normal mode in the `git_status` tree and the popup is confirmed with message `feat: x`, then a new change is staged and `gc` is confirmed with message `fix: it's $HOME`
- **THEN** after the first commit `git log -1 --format=%s` is `feat: x` and exactly one notification `Committed: feat: x` at INFO is emitted, and after the second `git log -1 --format=%s` is `fix: it's $HOME` (passed verbatim, no shell expansion)

#### Scenario: gc reports commit failure
- **WHEN** `gc` is pressed in normal mode in the `git_status` tree, the popup is confirmed with message `feat: x`, and `git commit` exits non-zero (e.g. a failing `pre-commit` hook)
- **THEN** a notification starting with `Commit failed:` at ERROR is emitted, no notification starting with `Committed:` is emitted, and `git log -1 --format=%s` is unchanged

#### Scenario: Help lists the moved git status keys
- **WHEN** `?` is pressed in normal mode in the `git_status` tree with a 100x40 screen
- **THEN** the screen matches the reference screenshot: the Neotree Help lists `X -> git_revert_file`, `c -> copy` and `gc -> commit (AI)` and no `gr` row

### Requirement: Git status push
In the `git_status` tree, normal-mode `P` SHALL notify `Pushing...` (INFO), run `git push` asynchronously, then notify `Pushed successfully` (INFO) on exit 0 or `Push failed` (ERROR).

#### Scenario: P pushes successfully
- **WHEN** `P` is pressed in normal mode in the `git_status` tree and `git push` exits 0
- **THEN** notifications `Pushing...` (INFO) then `Pushed successfully` (INFO) are emitted

#### Scenario: P reports push failure
- **WHEN** `P` is pressed in normal mode in the `git_status` tree and `git push` exits non-zero
- **THEN** notifications `Pushing...` (INFO) then `Push failed` (ERROR) are emitted
