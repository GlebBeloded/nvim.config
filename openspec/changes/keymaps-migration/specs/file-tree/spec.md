# file-tree Specification

## ADDED Requirements

### Requirement: Neo-tree mapping ownership
Neo-tree SHALL disable its default mappings and build common, filesystem, and git-status mapping tables from registered file-tree actions and current `settings/keymap.json` assignments whenever setup runs.

#### Scenario: Tree mappings come from the shortcut file
- **WHEN** a populated filesystem or git-status tree is opened after `VeryLazy`
- **THEN** every configured tree lhs invokes the file-tree action assigned by `settings/keymap.json`

#### Scenario: Neo-tree defaults stay disabled
- **WHEN** a populated tree is opened and its buffer-local normal mappings are enumerated
- **THEN** an unconfigured neo-tree default lhs is absent


## MODIFIED Requirements

### Requirement: Common tree open mappings
In normal mode in any neo-tree window the config SHALL map `<CR>`, `o`, and `l` to native open, `h`/`<BS>` to close node, `v`/`s` to vertical/horizontal split, `t` to new tab, `q` to close, `?` to help, and `<`/`>` to switch source. In `git_status`, only `<CR>` SHALL override native open to close the preview, reveal the file in `filesystem`, move right, and edit it.

#### Scenario: v opens file in vertical split
- **WHEN** the cursor is on a file node in the `filesystem` tree and `v` is pressed in normal mode
- **THEN** the file is shown in a new window that is a vertical split of the previous non-tree window

#### Scenario: t opens file in new tab
- **WHEN** the cursor is on a file node in the `filesystem` tree and `t` is pressed in normal mode
- **THEN** the tab page count increases by one and the current buffer of the new tab is that file

#### Scenario: Next source switches tree source
- **WHEN** `>` is pressed in normal mode in the `filesystem` tree
- **THEN** the tree window shows the `git_status` source

#### Scenario: o and l keep native open in git status tree
- **WHEN** the cursor is on a file node in the `git_status` tree and `o`, then in a fresh tree `l`, is pressed in normal mode
- **THEN** each key opens the node without replacing the `git_status` tree with the `filesystem` source or explicitly closing the diff preview

### Requirement: Git status revert and key ownership
In the `git_status` tree, normal-mode `X` SHALL ask `Are you sure you want to revert <name>?` and revert the file only when confirmed (`git_revert_file`). The tree SHALL set no buffer-local `gr` mapping, so the global `gr` applies, and `c` SHALL be the common copy action.

#### Scenario: X reverts a file after confirmation
- **WHEN** the cursor is on the file node `a.txt` with an unstaged change in the `git_status` tree, `X` is pressed in normal mode and the prompt `Are you sure you want to revert a.txt?` is answered yes
- **THEN** `a.txt` has its `HEAD` content and `git status --porcelain` no longer lists it

#### Scenario: X keeps a file when revert is declined
- **WHEN** the cursor is on the file node `a.txt` with an unstaged change in the `git_status` tree, `X` is pressed in normal mode and the prompt is answered no
- **THEN** `a.txt` keeps its working-tree content and `git status --porcelain` still lists it

#### Scenario: gr keeps its global meaning in git status tree
- **WHEN** the `git_status` tree buffer is current and `vim.fn.maparg("gr", "n", false, true)` is read
- **THEN** the result is the global mapping (`buffer` is 0) whose callback opens the shared mini.pick LSP references source with the current line included

#### Scenario: c is copy in git status tree
- **WHEN** the `git_status` tree buffer is current and the buffer-local normal-mode mapping for `c` is read with `nvim_buf_get_keymap(0, "n")`
- **THEN** its `desc` is `Tree: Copy`

### Requirement: Git status AI commit
In the `git_status` tree, normal-mode `gc` SHALL open the AI commit popup (`gleb.git.ai_commit`) and run `git commit -m <message>` as an argument list for a confirmed message; on exit 0 it SHALL refresh the `git_status` source and notify `Committed: <first line of message>` at INFO, otherwise notify `Commit failed: <git stderr>` at ERROR. `?` help SHALL label `gc` `Tree: Commit (AI)`.

#### Scenario: gc commits confirmed message
- **WHEN** `gc` is pressed in normal mode in the `git_status` tree and the popup is confirmed with message `feat: x`, then a new change is staged and `gc` is confirmed with message `fix: it's $HOME`
- **THEN** after the first commit `git log -1 --format=%s` is `feat: x` and exactly one notification `Committed: feat: x` at INFO is emitted, and after the second `git log -1 --format=%s` is `fix: it's $HOME` (passed verbatim, no shell expansion)

#### Scenario: gc reports commit failure
- **WHEN** `gc` is pressed in normal mode in the `git_status` tree, the popup is confirmed with message `feat: x`, and `git commit` exits non-zero (e.g. a failing `pre-commit` hook)
- **THEN** a notification starting with `Commit failed:` at ERROR is emitted, no notification starting with `Committed:` is emitted, and `git log -1 --format=%s` is unchanged

#### Scenario: Help lists the moved git status keys
- **WHEN** `?` is pressed in normal mode in the `git_status` tree with a 100x40 screen
- **THEN** the screen matches the reference screenshot: the Neotree Help lists only configured keys, including `X -> Tree: Revert`, `c -> Tree: Copy` and `gc -> Tree: Commit (AI)`, and no `gr` row
