# file-tree Specification

## Purpose
Configures neo-tree as the file explorer with a `filesystem` source and a `git_status` source, where the `git_status` source previews each changed file in a reusable side-by-side diff tab and supports staging, committing and pushing (`lua/gleb/file_tree/`).

## Requirements

### Requirement: Tree sources and window
The config SHALL set up neo-tree with exactly the sources `filesystem` and `git_status`, no source selector in winbar or statusline, a left-docked window 35 columns wide, and SHALL close Neovim's last window when only the tree remains (`close_if_last_window`). If neo-tree cannot be required, `lua/gleb/file_tree` SHALL return without error.

#### Scenario: Filesystem tree opens on the left at width 35
- **WHEN** `:Neotree filesystem` is executed
- **THEN** a window with filetype `neo-tree` is the leftmost window of the current tab and its width is 35

#### Scenario: Git status tree opens on the left at width 35
- **WHEN** `:Neotree git_status` is executed inside a git repository
- **THEN** a window with filetype `neo-tree` showing the `git_status` source is the leftmost window and its width is 35

#### Scenario: Tree closes with last window
- **WHEN** `:Neotree filesystem` is open next to one file window and that file window is closed with `:q`
- **THEN** Neovim exits (no window with filetype `neo-tree` remains alone)

#### Scenario: Missing neo-tree is tolerated
- **WHEN** `require("gleb.file_tree")` is called with neo-tree not on the runtimepath
- **THEN** no error is raised

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

### Requirement: Common tree edit mappings
In normal mode in any neo-tree window the config SHALL map `a` to add a node (prompt shows a relative path), `d` delete, `r` rename, `c` copy, `x` cut to clipboard, `p` paste from clipboard and `R` refresh.

#### Scenario: a creates a file
- **WHEN** `a` is pressed in normal mode in the `filesystem` tree on the root node and `new.txt<CR>` is typed
- **THEN** `new.txt` exists on disk in that directory and appears in the tree buffer

#### Scenario: r renames a file
- **WHEN** `r` is pressed in normal mode on file node `old.txt` and the prompt is replaced with `renamed.txt<CR>`
- **THEN** `renamed.txt` exists on disk and `old.txt` does not

### Requirement: Filesystem source behaviour
The `filesystem` source SHALL follow the current file, use the libuv file watcher, hijack netrw by opening in the current window, show dotfiles and gitignored files, and map `H` in normal mode to toggle hidden items.

#### Scenario: Dotfiles and gitignored files are listed
- **WHEN** `:Neotree filesystem` is opened in a directory containing `.hidden` and a gitignored file
- **THEN** both entries appear as lines in the tree buffer

#### Scenario: Directory argument opens tree in current window
- **WHEN** `:edit <directory>` is executed
- **THEN** the current window shows a buffer with filetype `neo-tree` for that directory instead of netrw

#### Scenario: Current file is followed
- **WHEN** `:Neotree filesystem` is open and another file is opened with `:edit <file>` in the editing window
- **THEN** the tree cursor line is on the node for `<file>`

### Requirement: Git status navigation previews diffs
In the `git_status` tree, normal-mode `j` and `k` SHALL move the cursor down/up repeatedly, skipping directory nodes, until a file node or the last/first line is reached, and SHALL then call `diff_preview.open_diff(path)` for the file under the cursor if it is a readable file.

#### Scenario: j skips directories and previews next file
- **WHEN** the cursor is on a file node followed by a directory node and a file node, and `j` is pressed in normal mode
- **THEN** the cursor lands on the next file node and `require("gleb.file_tree.diff_preview").state.current_file` equals that file's absolute path

#### Scenario: k skips directories and previews previous file
- **WHEN** the cursor is on a file node preceded by a directory node and a file node, and `k` is pressed in normal mode
- **THEN** the cursor lands on the previous file node and `diff_preview.state.current_file` equals that file's absolute path

#### Scenario: Deleted file is not previewed
- **WHEN** `j` moves the cursor onto a file node whose path is not readable on disk
- **THEN** `diff_preview.state.current_file` is unchanged

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

### Requirement: Git status push
In the `git_status` tree, normal-mode `P` SHALL notify `Pushing...` (INFO), run `git push` asynchronously, then notify `Pushed successfully` (INFO) on exit 0 or `Push failed` (ERROR).

#### Scenario: P pushes successfully
- **WHEN** `P` is pressed in normal mode in the `git_status` tree and `git push` exits 0
- **THEN** notifications `Pushing...` (INFO) then `Pushed successfully` (INFO) are emitted

#### Scenario: P reports push failure
- **WHEN** `P` is pressed in normal mode in the `git_status` tree and `git push` exits non-zero
- **THEN** notifications `Pushing...` (INFO) then `Push failed` (ERROR) are emitted

### Requirement: Diff preview state
`require("gleb.file_tree.diff_preview")` SHALL expose `state` with fields `original_tab`, `diff_tab`, `current_file` (all nil initially) and `navigating_until` (0 initially), and `reset()` SHALL close any diff tab, clear the focus-guard autocmds and restore that initial state.

#### Scenario: State starts empty
- **WHEN** `diff_preview.reset()` is called
- **THEN** `state.original_tab`, `state.diff_tab` and `state.current_file` are nil and `state.navigating_until` is 0

#### Scenario: Reset clears populated state
- **WHEN** `state.current_file`, `state.original_tab`, `state.diff_tab` and `state.navigating_until` are set to non-default values and `diff_preview.reset()` is called
- **THEN** `state.current_file`, `state.original_tab` and `state.diff_tab` are nil and `state.navigating_until` is 0

### Requirement: Diff preview opening
`diff_preview.open_diff(path)` SHALL do nothing when `path` is nil or equals `state.current_file`; otherwise it SHALL set `state.current_file = path` and `state.navigating_until` to now + 300 ms immediately, then after a 50 ms debounce (restarted per call), if `path` is still current, record `state.original_tab` (first time only), replace any previous diff tab with one new tab diffing `HEAD` vs the working tree for `path`, and store it in `state.diff_tab`.

#### Scenario: Nil path is ignored
- **WHEN** `diff_preview.open_diff(nil)` is called
- **THEN** `state.current_file` stays nil and the tab page count is unchanged

#### Scenario: Same file is ignored
- **WHEN** `state.current_file` is `/test/file.lua` and `diff_preview.open_diff("/test/file.lua")` is called
- **THEN** the tab page count is unchanged

#### Scenario: Current file is tracked immediately
- **WHEN** `diff_preview.open_diff(p)` is called for a git-tracked readable file `p`
- **THEN** `state.current_file` equals `p` before any wait

#### Scenario: Original tab is saved
- **WHEN** `diff_preview.open_diff(p)` is called from tab T for a git-tracked file and the async work completes
- **THEN** `state.original_tab` equals T

#### Scenario: Diff tab is created
- **WHEN** `diff_preview.open_diff(p)` is called for a git-tracked file and the async work completes
- **THEN** the tab page count is one higher than before and `state.diff_tab` is the current tab

#### Scenario: Diff tab is reused across files
- **WHEN** `diff_preview.open_diff(a)` completes and then `diff_preview.open_diff(b)` completes
- **THEN** exactly one diff tab exists besides the original tab and `state.current_file` is `b`

#### Scenario: Rapid calls are debounced
- **WHEN** `diff_preview.open_diff(a)` and then `diff_preview.open_diff(b)` are called within 50 ms
- **THEN** only one diff tab is created and it shows `b`

### Requirement: Diff preview tree in diff tab
After creating a diff tab, `open_diff(path)` SHALL run `:Neotree git_status reveal_file=<path>` in that tab and focus the neo-tree window.

#### Scenario: Neo-tree is opened and focused in diff tab
- **WHEN** `diff_preview.open_diff(p)` is called for a git-tracked file and the async work completes
- **THEN** the diff tab contains a window with filetype `neo-tree` and the current window's filetype is `neo-tree`

### Requirement: Diff preview git errors
When resolving the git root or `HEAD` for `open_diff(path)` fails, the config SHALL notify `Git root error: <err>` or `Git resolve error: <err>` at ERROR level and SHALL NOT create a diff tab.

#### Scenario: File outside a repository
- **WHEN** `diff_preview.open_diff(p)` is called for a readable file `p` outside any git repository and 100 ms pass
- **THEN** a notification starting with `Git root error:` at ERROR is emitted and the tab page count is unchanged

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

### Requirement: Tree icons
The tree SHALL draw a Nerd Font glyph in every icon slot: expanders U+F460 (collapsed) and U+F47C (expanded); folder icons U+E5FF (closed), U+E5FE (open) and U+F0256 (empty); the git conflict symbol U+E727; and, for a file with diagnostics, the diagnostic sign glyph of its most severe diagnostic (the same glyphs as the `lsp` sign column). No icon slot SHALL be drawn as a blank cell.

#### Scenario: Collapsed directory shows expander and folder icon
- **WHEN** `:Neotree filesystem` is executed in a directory containing the subdirectory `docs`
- **THEN** the tree row of `docs` shows U+F460, then U+E5FF, then `docs`

#### Scenario: Expanded directory shows open expander and folder icon
- **WHEN** the cursor is on the `docs` row of the `filesystem` tree and `<cr>` is pressed in normal mode
- **THEN** the tree row of `docs` shows U+F47C, then U+E5FE, then `docs`

#### Scenario: Empty directory shows empty folder icon
- **WHEN** the cursor is on the row of a subdirectory `empty` that has no entries and `<cr>` is pressed twice in normal mode (expand, then collapse)
- **THEN** the tree row of `empty` shows U+F0256 before `empty`

#### Scenario: Tree shows diagnostic glyph of a file
- **WHEN** `:Neotree filesystem` shows file `sample.lua`, the buffer of `sample.lua` gets one error via `vim.diagnostic.set`, and the tree refreshes
- **THEN** the tree row of `sample.lua` contains U+F057

#### Scenario: Conflicted file shows conflict symbol
- **WHEN** `:Neotree git_status` is executed in a git repository where `conflict.txt` is unmerged after a failed `git merge`
- **THEN** the tree row of `conflict.txt` contains U+E727

#### Scenario: filesystem tree matches reference screenshot
- **WHEN** `:Neotree filesystem` is executed in a fixture directory with subdirectories `docs` (containing `workflow.md`), `empty` (no entries) and `lua` (containing `gleb/`) and file `init.lua`, `<cr>` is pressed on `docs` and twice on `empty`, and a screenshot of the tree rows below the root row is taken
- **THEN** it matches the stored reference screenshot, with an expander and a folder glyph on every directory row

### Requirement: Neo-tree mapping ownership
Neo-tree SHALL disable its default mappings and build common, filesystem, and git-status mapping tables from registered file-tree actions and current `settings/keymap.json` assignments whenever setup runs.

#### Scenario: Tree mappings come from the shortcut file
- **WHEN** a populated filesystem or git-status tree is opened after `VeryLazy`
- **THEN** every configured tree lhs invokes the file-tree action assigned by `settings/keymap.json`

#### Scenario: Neo-tree defaults stay disabled
- **WHEN** a populated tree is opened and its buffer-local normal mappings are enumerated
- **THEN** an unconfigured neo-tree default lhs is absent

### Requirement: Filesystem tree toggle
The normal-mode filesystem tree toggle SHALL reveal an existing current buffer file and SHALL focus the filesystem tree without requesting a reveal when the current buffer path does not exist on disk.

#### Scenario: Toggle tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised and the focused tree uses the `filesystem` source without trying to reveal the deleted path
