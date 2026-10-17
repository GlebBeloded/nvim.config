## ADDED Requirements

### Requirement: Changes panel window
The `changes.toggle` action SHALL open a left sidebar 35 columns wide, filetype `gleb-changes`, for the git root of the current buffer's directory (else the cwd), focus it and put the cursor on the current file's row (else the first file row); the editor window keeps its buffer. Run in the focused panel it SHALL close it; with the panel open elsewhere it SHALL focus it. `require("gleb.git.changes").open({ root = dir })` SHALL open it for `dir`.

#### Scenario: Changes panel opens on the left at width 35
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing` fixture is edited and the `changes.toggle` action runs
- **THEN** the leftmost window of the current tab is the current window, its filetype is `gleb-changes`, its width is 35, the cursor row is the `invoice.go` row, and the other window still shows `invoice.go`

#### Scenario: Changes panel cursor starts on the first file
- **WHEN** `:enew` is current in a fresh copy of the `dirty` fixture and the `changes.toggle` action runs
- **THEN** the cursor row of the `gleb-changes` window is the first file row (`c.lua`)

#### Scenario: Changes panel toggle closes the focused panel
- **WHEN** the `gleb-changes` window is current and the `changes.toggle` action runs
- **THEN** no window with filetype `gleb-changes` remains and the current window is the editor window

#### Scenario: Changes panel toggle focuses an open panel
- **WHEN** the changes panel is open, `:wincmd l` has moved focus to the editor window and the `changes.toggle` action runs
- **THEN** the current window's filetype is `gleb-changes` and the window count is unchanged

### Requirement: Changes panel outside a repository
When no git root can be resolved, `changes.toggle` and `changes.review` SHALL notify `Git root error: <git stderr>` at ERROR and open no window.

#### Scenario: Changes panel outside a repository
- **WHEN** the cwd and the current buffer's directory are a temp directory outside any git repository and the `changes.toggle` action runs
- **THEN** a notification starting with `Git root error:` at ERROR is emitted and no window with filetype `gleb-changes` exists

### Requirement: Changes panel rows
The panel SHALL list `git status --porcelain=v2 -z --untracked-files=all` (argument list, run in the root) under the roots `Changes <n> files` and, when there are untracked files, `Unversioned Files <n> files` (`1 file` for one). Under a root, files are grouped by directory: directories first, then files, each sorted by name; a directory whose only child is a directory joins it as `a/b`; a directory row ends with its file count; root-level files sit under the root.

#### Scenario: Changes panel lists the dirty fixture
- **WHEN** the changes panel is opened on a fresh copy of the `dirty` fixture
- **THEN** the panel rows, with icons and padding removed, are in order `Changes 4 files`, `lib 1`, `c.lua +1 -1`, `a.txt +1 -0`, `b.txt +2 -2`, `d.txt +2 -2`, `Unversioned Files 1 file`, `new.txt`

#### Scenario: Changes panel compacts single-child directories
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the directory rows read `internal/billing 4` and `web/src 1`, and no row reads `internal`, `billing`, `web` or `src` alone

#### Scenario: Changes panel hides an empty Unversioned Files root
- **WHEN** the changes panel is opened on a repository whose only change is a modified tracked file `a.txt`
- **THEN** the rows are `Changes 1 file` and `a.txt +1 -1`, and no row starts with `Unversioned Files`

### Requirement: Changes panel status colours
A file name SHALL be coloured by its status alone: modified `FileTreeGitModified`, added `FileTreeGitAdded`, untracked `FileTreeGitUntracked`, deleted `FileTreeGitDeleted`, renamed `FileTreeGitRenamed` (showing the new path), unmerged `FileTreeGitConflict`. Roots use `ChangesRoot`, counts `ChangesCount`, checkboxes `ChangesCheckbox`, directories `FileTreeFolderIcon`/`FileTreeFolderName`; colours come from the palette.

#### Scenario: Changes panel colours names by status
- **WHEN** the changes panel is opened on a repository where `m.txt` is modified, `n.txt` is staged as new, `d.txt` is deleted with `git rm`, `old.txt` is renamed to `moved.txt` with `git mv` and `u.txt` is untracked
- **THEN** the name extmarks of the rows are `m.txt` [FileTreeGitModified], `n.txt` [FileTreeGitAdded], `d.txt` [FileTreeGitDeleted], `moved.txt` [FileTreeGitRenamed] and `u.txt` [FileTreeGitUntracked], and no row shows `old.txt`

#### Scenario: Changes panel highlight colours
- **WHEN** the full config has loaded and the gruvbox-material colorscheme is active
- **THEN** `ChangesRoot` is bold with the palette `fg1`, `ChangesCount` uses `grey1`, `ChangesStatAdded` uses `green` and `ChangesStatRemoved` uses `red` as foreground

### Requirement: Changes panel staging checkbox
Each file row and the `Changes` root SHALL carry a checkbox: checked when every change is staged, mixed when staged and unstaged changes coexist, empty when nothing is staged; untracked files and the `Unversioned Files` root are always empty. The state comes from the porcelain index and worktree columns of the exact path.

#### Scenario: Changes panel checkboxes follow the index
- **WHEN** the changes panel is opened on a fresh copy of the `dirty` fixture
- **THEN** the checkbox of `a.txt` is checked (U+F0132), of `d.txt` mixed (U+F0856), of `b.txt`, `c.lua` and `new.txt` empty (U+F0131), and of the `Changes` root mixed

### Requirement: Changes panel staging toggle
`<Space>` on a file row SHALL run `git reset -q -- <path>` when the exact path is fully staged (`git diff --cached --quiet -- <path>` exits 1 and `git diff --quiet -- <path>` exits 0, run in the root) and `git add -- <path>` otherwise, as argument lists with absolute paths, independent of the cwd. On a root or directory row it SHALL do the same for every file below in one call. A non-zero exit SHALL notify `Stage failed: <stderr>` or `Unstage failed: <stderr>` at ERROR.

#### Scenario: Changes panel Space stages an unstaged file
- **WHEN** the cursor is on the `b.txt` row of the changes panel on the `dirty` fixture and `<Space>` is pressed in normal mode
- **THEN** `git add -- <abs b.txt>` is run, `b.txt` appears in `git diff --cached --name-only` and its checkbox is checked

#### Scenario: Changes panel Space unstages a staged file
- **WHEN** the cursor is on the `a.txt` row of the changes panel on the `dirty` fixture and `<Space>` is pressed in normal mode
- **THEN** `git reset -q -- <abs a.txt>` is run, `a.txt` no longer appears in `git diff --cached --name-only` and its checkbox is empty

#### Scenario: Changes panel Space stages a partially staged file
- **WHEN** the cursor is on the mixed `d.txt` row of the changes panel on the `dirty` fixture and `<Space>` is pressed in normal mode
- **THEN** `git diff --quiet -- d.txt` exits 0, `d.txt` appears in `git diff --cached --name-only` and its checkbox is checked

#### Scenario: Changes panel Space stages an untracked file
- **WHEN** the cursor is on the `new.txt` row of the changes panel on the `dirty` fixture and `<Space>` is pressed in normal mode
- **THEN** `new.txt` appears in `git diff --cached --name-only`, its row moves under `Changes 5 files` with a checked checkbox, and no row starts with `Unversioned Files`

#### Scenario: Changes panel Space stages a file whose name is a suffix of a staged file
- **WHEN** `aa.lua` is staged, `a.lua` is modified and unstaged, the cursor is on the `a.lua` row of the changes panel and `<Space>` is pressed in normal mode
- **THEN** both `a.lua` and `aa.lua` appear in `git diff --cached --name-only`

#### Scenario: Changes panel stages when cwd is outside the repository
- **WHEN** the cwd is a directory outside the repository, the panel was opened with `require("gleb.git.changes").open({ root = repo })`, `a.lua` is modified and unstaged, the cursor is on its row and `<Space>` is pressed in normal mode
- **THEN** `a.lua` appears in `git diff --cached --name-only` run in the repository

#### Scenario: Changes panel unstages when cwd is outside the repository
- **WHEN** the cwd is a directory outside the repository, the panel was opened with `require("gleb.git.changes").open({ root = repo })`, `a.lua` is staged, the cursor is on its row and `<Space>` is pressed in normal mode
- **THEN** `a.lua` no longer appears in `git diff --cached --name-only` run in the repository

#### Scenario: Changes panel stages from a subdirectory cwd
- **WHEN** the cwd is the subdirectory `sub` of the repository, `sub/x.lua` is modified and unstaged, the cursor is on its row in the changes panel and `<Space>` is pressed in normal mode
- **THEN** `sub/x.lua` appears in `git diff --cached --name-only`

#### Scenario: Changes panel unstages from a subdirectory cwd
- **WHEN** the cwd is the subdirectory `sub` of the repository, `sub/x.lua` is staged, the cursor is on its row in the changes panel and `<Space>` is pressed in normal mode
- **THEN** `sub/x.lua` no longer appears in `git diff --cached --name-only`

#### Scenario: Changes panel reports a staging failure
- **WHEN** `.git/index.lock` exists, the cursor is on an unstaged file row of the changes panel and `<Space>` is pressed in normal mode
- **THEN** a notification starting with `Stage failed:` at ERROR is emitted

#### Scenario: Changes panel Space on the Changes root stages every tracked file
- **WHEN** the cursor is on the mixed `Changes` root row of the changes panel on the `dirty` fixture and `<Space>` is pressed in normal mode
- **THEN** one `git add --` call lists `a.txt`, `b.txt`, `d.txt` and `lib/c.lua`, `git diff --quiet` exits 0, `new.txt` stays untracked and the root checkbox is checked

### Requirement: Changes panel stage all
`A` in the panel SHALL run `git add -A` as an argument list in the root, notify `Stage failed: <stderr>` at ERROR on a non-zero exit, and refresh the panel.

#### Scenario: Changes panel A stages everything
- **WHEN** `A` is pressed in normal mode in the changes panel on the `dirty` fixture
- **THEN** `git diff --quiet` exits 0, `git ls-files --others --exclude-standard` is empty, every checkbox is checked and no row starts with `Unversioned Files`

### Requirement: Changes panel line stats
A changed tracked file's row SHALL end with right-aligned `+<added> -<removed>` from `git diff --numstat -z HEAD` (staged and unstaged together; argument list, run in the root) in `ChangesStatAdded` and `ChangesStatRemoved`. Untracked and binary files SHALL show none. A name that does not fit before the stats SHALL be cut and end with `…`.

#### Scenario: Changes panel shows line stats
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the rows end with `invoice.go` `+12 -3`, `invoice_test.go` `+20 -1`, `tax.go` `+41 -0`, `tax_test.go` `+33 -0` and `price.ts` `+4 -4`, and the `notes.md` row has no stats

#### Scenario: Changes panel cuts a long name before the stats
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the nested `invoice_test.go` row reads `invoice_test.…` followed by `+20 -1`, which ends in the panel's last column

### Requirement: Changes panel nesting
Under one root and directory, a changed file that the file-tree nesting rules (`settings/file_tree.json`) nest under another listed file SHALL be a child row of it, one level deeper; the parent gets an expander and the nest starts expanded. `za` and `<CR>` on a root, directory or nest parent row SHALL toggle its fold, kept across refreshes.

#### Scenario: Changes panel nests tests under their file
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the `invoice_test.go` row directly follows the `invoice.go` row one level deeper, `tax_test.go` follows `tax.go` the same way, and `invoice.go` and `tax.go` show the expanded expander U+F47C

#### Scenario: Changes panel keeps a lone test file flat
- **WHEN** the changes panel is opened on a repository where only `pkg/a_test.go` changed and `pkg/a.go` did not
- **THEN** `a_test.go` is a file row directly under the `pkg 1` directory row, without a parent row

#### Scenario: Changes panel za folds a nest
- **WHEN** the cursor is on the `invoice.go` row of the changes panel on the `billing` fixture and `za` is pressed in normal mode, then the panel refreshes after `:checktime`
- **THEN** no row shows `invoice_test.go`, `invoice.go` shows the collapsed expander U+F460, and the state holds after the refresh

#### Scenario: Changes panel Enter folds a directory
- **WHEN** the cursor is on the `web/src 1` row of the changes panel on the `billing` fixture and `<CR>` is pressed in normal mode
- **THEN** no row shows `price.ts` and no file is opened

### Requirement: Changes panel diff view
When the panel cursor moves onto a file row, the panel SHALL, after a 50 ms debounce restarted per move, show that file in the diff view in the editor window: `HEAD` on the left (empty for added and untracked files), the working tree on the right (empty for deleted files). Focus SHALL stay in the panel, one diff view SHALL be reused across files without a new tab page, a stale result SHALL be dropped, and other rows keep the last diff.

#### Scenario: Changes panel j shows the next file in the diff view
- **WHEN** the changes panel on the `billing` fixture has its cursor on `invoice.go`, `j` is pressed in normal mode and 100 ms pass
- **THEN** the editor area shows the diff view of `internal/billing/invoice_test.go` (left: its `HEAD` lines, right: its working-tree lines), the tab page count is unchanged and the current window's filetype is `gleb-changes`

#### Scenario: Changes panel debounces rapid moves
- **WHEN** the cursor is on `invoice.go` and `j` is pressed twice within 50 ms in normal mode in the changes panel on the `billing` fixture, and 100 ms pass
- **THEN** the diff view shows `internal/billing/tax.go` and was never shown for `invoice_test.go`

#### Scenario: Changes panel shows an untracked file as added
- **WHEN** the cursor moves onto the `new.txt` row of the changes panel on the `dirty` fixture and 100 ms pass
- **THEN** the diff view's left side is empty and its right side holds `new`, `untracked`, `file`

#### Scenario: Changes panel shows a deleted file
- **WHEN** in a repository whose committed `a.txt` holds `one`, `a.txt` is deleted from disk, the changes panel is opened, the cursor moves onto the `a.txt` row and 100 ms pass
- **THEN** the diff view's left side holds `one` and its right side is empty

#### Scenario: Changes panel keeps the diff on a directory row
- **WHEN** the diff view shows `lib/c.lua` of the `dirty` fixture and `k` moves the panel cursor onto the `lib 1` row
- **THEN** after 100 ms the diff view still shows `lib/c.lua`

#### Scenario: Changes panel with the diff view matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing` fixture and the `changes.review` action runs
- **THEN** screen rows 2-29 match design.md "Proposed B — changes panel with the diff view", text and colour mask

### Requirement: Changes panel review
The `changes.review` action SHALL open the changes panel when it is closed (cursor on the current file's row, else the first file row), focus it when open, and show the diff of the row under the cursor at once.

#### Scenario: Changes panel review shows the current file's diff
- **WHEN** `internal/billing/invoice.go` of the `billing` fixture is edited and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current with its cursor on `invoice.go`, and within 100 ms the editor area shows the diff view of `internal/billing/invoice.go`

#### Scenario: Changes panel review without a changed current file
- **WHEN** `:enew` is current in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the panel cursor is on the `c.lua` row and the diff view shows `lib/c.lua`

### Requirement: Changes panel diff file navigation
While the diff view shows a file chosen in the panel, `diff.next_file` in a diff window SHALL show the next file row of the panel (the last stays) and move the panel cursor to it.

#### Scenario: Changes panel ]f steps through every changed file
- **WHEN** `changes.review` shows `lib/c.lua` of the `dirty` fixture, focus moves to the right diff window and `]f` is pressed four times in normal mode
- **THEN** the diff view shows `a.txt`, `b.txt`, `d.txt` and `new.txt` in that order, once each, and the panel cursor ends on the `new.txt` row

### Requirement: Changes panel open and close
`<CR>` on a file row SHALL close the diff view, edit the file in the editor window and focus it, keeping the panel open. `q` SHALL close the panel and the diff view, restore the buffer the editor window showed before, and focus it.

#### Scenario: Changes panel Enter opens the file
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** no window with filetype `gleb-diff` remains, the current window edits `b.txt`, and the `gleb-changes` window is still open

#### Scenario: Changes panel q closes the panel and the diff view
- **WHEN** `a.txt` was edited, the changes panel was opened, the diff view shows `b.txt`, and `q` is pressed in normal mode in the panel
- **THEN** no `gleb-changes` or `gleb-diff` window remains, the tab page count is unchanged, and the current window edits `a.txt`

### Requirement: Changes panel revert
`X` on a tracked file row SHALL ask `Are you sure you want to revert <name>?` and, only on `y`, run `git checkout HEAD -- <path>` (a file absent from `HEAD`: `git rm --cached -q -- <path>`, keeping it on disk) as an argument list in the root, notify `Revert failed: <stderr>` at ERROR on a non-zero exit, and refresh. On an untracked file `X` SHALL do nothing.

#### Scenario: Changes panel X reverts a file after confirmation
- **WHEN** the cursor is on the `b.txt` row of the changes panel on the `dirty` fixture, `X` is pressed in normal mode and the prompt `Are you sure you want to revert b.txt?` is answered `y`
- **THEN** `b.txt` has its `HEAD` content and `git status --porcelain -- b.txt` is empty

#### Scenario: Changes panel X keeps a file when revert is declined
- **WHEN** the cursor is on the `b.txt` row of the changes panel on the `dirty` fixture, `X` is pressed in normal mode and the prompt is answered `n`
- **THEN** `b.txt` keeps its working-tree content and `git status --porcelain -- b.txt` still lists it

#### Scenario: Changes panel X unstages a new file and keeps it
- **WHEN** the cursor is on the staged new `tax.go` row of the changes panel on the `billing` fixture, `X` is pressed in normal mode and the prompt is answered `y`
- **THEN** `internal/billing/tax.go` still exists on disk with 41 lines and is listed by `git ls-files --others --exclude-standard`

#### Scenario: Changes panel X ignores an unversioned file
- **WHEN** the cursor is on the `new.txt` row of the changes panel on the `dirty` fixture and `X` is pressed in normal mode
- **THEN** no prompt is shown, `new.txt` still exists and no git command is run

### Requirement: Changes panel commit
`gc` in the panel SHALL open the AI commit popup (`gleb.git.ai_commit`) and run `git commit -m <message>` as an argument list in the root for a confirmed message; on exit 0 it SHALL refresh the panel and notify `Committed: <first line of message>` at INFO, otherwise notify `Commit failed: <stderr, else stdout, else exit code>` at ERROR.

#### Scenario: Changes panel gc commits confirmed message
- **WHEN** `gc` is pressed in normal mode in the changes panel and the popup is confirmed with `feat: x`, then a new change is staged and `gc` is confirmed with `fix: it's $HOME`
- **THEN** after the first commit `git log -1 --format=%s` is `feat: x` and exactly one notification `Committed: feat: x` at INFO is emitted, and after the second it is `fix: it's $HOME` (verbatim, no shell expansion)

#### Scenario: Changes panel gc reports commit failure
- **WHEN** `gc` is pressed in normal mode in the changes panel, the popup is confirmed with `feat: x` and `git commit` exits non-zero (a failing `pre-commit` hook)
- **THEN** a notification starting with `Commit failed:` at ERROR is emitted, none starting with `Committed:`, and `git log -1 --format=%s` is unchanged

### Requirement: Changes panel push
`P` in the panel SHALL notify `Pushing...` at INFO, run `git push` asynchronously as an argument list in the root, then notify `Pushed successfully` at INFO on exit 0 or `Push failed` at ERROR.

#### Scenario: Changes panel P pushes successfully
- **WHEN** `P` is pressed in normal mode in the changes panel and `git push` exits 0
- **THEN** notifications `Pushing...` (INFO) then `Pushed successfully` (INFO) are emitted

#### Scenario: Changes panel P reports push failure
- **WHEN** `P` is pressed in normal mode in the changes panel and `git push` exits non-zero
- **THEN** notifications `Pushing...` (INFO) then `Push failed` (ERROR) are emitted

### Requirement: Changes panel refresh
The panel SHALL re-read git after its own git commands, on `BufWritePost` of a file inside the root and on `FocusGained`, keeping the cursor on the same path while it is listed.

#### Scenario: Changes panel refreshes after a write
- **WHEN** the changes panel is open on the `dirty` fixture and `e.txt` is created in the editor window with `:edit e.txt`, `:call setline(1, "x")` and `:write`
- **THEN** within 500 ms the panel lists `e.txt` under `Unversioned Files 2 files` and the panel cursor row shows the same path as before

### Requirement: Changes panel keys
The panel keys SHALL come from registered `changes.*` actions scoped to filetype `gleb-changes` and their `settings/keymap.json` assignments: `<Space>` toggle_stage, `A` stage_all, `<CR>` open, `X` revert, `gc` commit, `P` push, `q` close, `za` toggle_fold. The panel SHALL set no buffer-local `gr`. `changes.toggle` and `changes.review` SHALL be registered for Find Action.

#### Scenario: Changes panel mappings come from the shortcut file
- **WHEN** the changes panel is opened after `VeryLazy` and its buffer-local normal mappings are enumerated
- **THEN** every mapping invokes the `changes.*` action assigned to its lhs by `settings/keymap.json`, with description `Changes: <Title>`, and no other mapping exists

#### Scenario: Changes panel leaves gr global
- **WHEN** the changes panel buffer is current and `vim.fn.maparg("gr", "n", false, true)` is read
- **THEN** the result is the global mapping (`buffer` is 0) whose callback opens the Find Usages view

#### Scenario: Changes panel entry points are actions
- **WHEN** the action catalog is read after startup
- **THEN** it contains `changes.toggle` titled `Toggle Changes` and `changes.review` titled `Review Changes`, both in category `View | Tool Windows`

### Requirement: Changes panel shares the left side
The changes panel and the project tree SHALL not be open together in one tab: opening the changes panel SHALL close a `gleb-file-tree` window, and opening the project tree SHALL close the changes panel and its diff view, restoring the editor window.

#### Scenario: Changes panel replaces the project tree
- **WHEN** the `file_tree.toggle` action has opened the project tree and the `changes.toggle` action runs
- **THEN** no `gleb-file-tree` window remains and the leftmost window is the focused `gleb-changes` window of width 35

#### Scenario: Project tree replaces the changes panel
- **WHEN** the changes panel shows the diff view of `b.txt` of the `dirty` fixture and the `file_tree.toggle` action runs
- **THEN** no `gleb-changes` or `gleb-diff` window remains and the leftmost window is the focused `gleb-file-tree` window

### Requirement: Changes panel screen
The changes panel SHALL match the approved IntelliJ commit-tree render.

#### Scenario: Changes panel matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing` fixture and the `changes.toggle` action runs
- **THEN** columns 1-36 of screen rows 2-12 match design.md "Proposed A — changes panel", text and colour mask
