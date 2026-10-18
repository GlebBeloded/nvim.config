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
The panel SHALL run `git --no-optional-locks status --porcelain=v2 -z --untracked-files=all` in the root and consume shared status records in one grouping pass. It SHALL draw `Changes <n> files` and an optional `Unversioned Files <n> files`, group by compacted directories, sort directories before files by name, and cap rows at the project tree's row limit.

#### Scenario: Changes panel lists the dirty fixture
- **WHEN** the changes panel is opened on a fresh copy of the `dirty` fixture
- **THEN** the panel rows, with icons and padding removed, are in order `Changes 4 files`, `lib 1`, `c.lua +1 -1`, `a.txt +1 -0`, `b.txt +2 -2`, `d.txt +2 -2`, `Unversioned Files 1 file`, `new.txt`

#### Scenario: Changes panel compacts single-child directories
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the directory rows read `internal/billing 4` and `web/src 1`, and no row reads `internal`, `billing`, `web` or `src` alone

#### Scenario: Changes panel hides an empty Unversioned Files root
- **WHEN** the changes panel is opened on a repository whose only change is a modified tracked file `a.txt`
- **THEN** the rows are `Changes 1 file` and `a.txt +1 -1`, and no row starts with `Unversioned Files`

#### Scenario: Changes panel keeps one path in both roots
- **WHEN** a repository reports the same path with a tracked worktree change and as an untracked path and the Changes panel opens
- **THEN** one row for that path is under `Changes` and a second row is under `Unversioned Files`

#### Scenario: Changes panel lists directory and submodule records
- **WHEN** porcelain status reports an untracked `vendor/` directory record and a tracked submodule whose sub field starts with `S`
- **THEN** each is a file row, selecting either opens no diff, `<CR>` opens no file, and an INFO notification explains that the row has no file content

#### Scenario: Changes panel status avoids optional locks
- **WHEN** the Changes panel refreshes in a repository
- **THEN** its status command starts with `git --no-optional-locks status --porcelain=v2 -z --untracked-files=all`

#### Scenario: Changes panel caps rows
- **WHEN** grouping status records would produce more rows than the project tree row limit
- **THEN** the Changes panel stops at that limit and notifies that the row limit was reached

### Requirement: Changes panel status colours
A file name SHALL be coloured by its status alone: modified `FileTreeGitModified`, added `FileTreeGitAdded`, untracked `FileTreeGitUntracked`, deleted `FileTreeGitDeleted`, renamed `FileTreeGitRenamed` (showing the new path), unmerged `FileTreeGitConflict`. Roots use `ChangesRoot`, counts `ChangesCount`, checkboxes `ChangesCheckbox`, directories `FileTreeFolderIcon`/`FileTreeFolderName`; colours come from the palette.

#### Scenario: Changes panel colours names by status
- **WHEN** the changes panel is opened on a repository where `m.txt` is modified, `n.txt` is staged as new, `d.txt` is deleted with `git rm`, `old.txt` is renamed to `moved.txt` with `git mv` and `u.txt` is untracked
- **THEN** the name extmarks of the rows are `m.txt` [FileTreeGitModified], `n.txt` [FileTreeGitAdded], `d.txt` [FileTreeGitDeleted], `moved.txt` [FileTreeGitRenamed] and `u.txt` [FileTreeGitUntracked], and no row shows `old.txt`

#### Scenario: Changes panel highlight colours
- **WHEN** the full config has loaded and the gruvbox-material colorscheme is active
- **THEN** `ChangesRoot` is bold with the palette `fg1`, `ChangesCount` uses `grey1`, `ChangesStatAdded` uses `green` and `ChangesStatRemoved` uses `red` as foreground

#### Scenario: Changes panel treats copies as renamed
- **WHEN** porcelain status contains a copied `2` record from `old.txt` to `copy.txt`
- **THEN** the panel shows `copy.txt` with `FileTreeGitRenamed` and keeps `old.txt` as the record's original path

### Requirement: Changes panel staging checkbox
Each file row and the `Changes` root SHALL carry a checkbox: checked when every change is staged, mixed when staged and unstaged changes coexist, empty when nothing is staged; untracked files and the `Unversioned Files` root are always empty. The state comes from the porcelain index and worktree columns of the exact path.

#### Scenario: Changes panel checkboxes follow the index
- **WHEN** the changes panel is opened on a fresh copy of the `dirty` fixture
- **THEN** the checkbox of `a.txt` is checked (U+F0132), of `d.txt` mixed (U+F0856), of `b.txt`, `c.lua` and `new.txt` empty (U+F0131), and of the `Changes` root mixed

### Requirement: Changes panel staging toggle
`<Space>` SHALL decide from one fresh porcelain-v2 status call for the selected file, directory or root, never row state or per-file processes. Every git call SHALL use `git --literal-pathspecs`. Above 100 paths it SHALL pass NUL paths through `--pathspec-from-file=- --pathspec-file-nul`. It SHALL stage unless every selected change is staged; renames unstage old and new paths. An unmerged file SHALL notify `Stage failed: resolve conflicts in the merge tool` and run no mutation.

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

#### Scenario: Changes panel stages literal metacharacter paths
- **WHEN** `[ab].txt` is modified, `a.txt` and `b.txt` are unchanged, and `<Space>` is pressed on `[ab].txt`
- **THEN** only `[ab].txt` is staged and every git command used for the action starts with `git --literal-pathspecs`

#### Scenario: Changes panel refuses to stage an unmerged file
- **WHEN** `<Space>` is pressed on an unmerged file row
- **THEN** `Stage failed: resolve conflicts in the merge tool` is notified and no staging command runs

#### Scenario: Changes panel unstages a rename literally
- **WHEN** `old.txt` is staged as renamed to `new.txt` and `<Space>` is pressed on `new.txt`
- **THEN** one literal-pathspec reset names both `new.txt` and `old.txt`, and the rename is no longer staged

### Requirement: Changes panel stage all
`A` in the panel SHALL run `git --literal-pathspecs add -A` in the root, including unmerged paths, notify `Stage failed: <stderr>` at ERROR on a non-zero exit, and refresh the panel and its diff view index.

#### Scenario: Changes panel A stages everything
- **WHEN** `A` is pressed in normal mode in the changes panel on the `dirty` fixture
- **THEN** `git diff --quiet` exits 0, `git ls-files --others --exclude-standard` is empty, every checkbox is checked and no row starts with `Unversioned Files`

### Requirement: Changes panel line stats
A changed tracked file SHALL show right-aligned `+<added> -<removed>` from `git diff --numstat -z HEAD`, keyed through its parsed status record and original path. A missing stat, untracked file, binary file or unborn `HEAD` SHALL show no stats. Names SHALL end with `…` when cut before stats.

#### Scenario: Changes panel shows line stats
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the rows end with `invoice.go` `+12 -3`, `invoice_test.go` `+20 -1`, `tax.go` `+41 -0`, `tax_test.go` `+33 -0` and `price.ts` `+4 -4`, and the `notes.md` row has no stats

#### Scenario: Changes panel cuts a long name before the stats
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the nested `invoice_test.go` row reads `invoice_test.…` followed by `+20 -1`, which ends in the panel's last column

#### Scenario: Changes panel omits unmatched numstat
- **WHEN** status contains `a.txt` and `b.txt` but numstat contains only `a.txt`
- **THEN** `a.txt` shows its line stats and `b.txt` shows no stats

#### Scenario: Changes panel on unborn HEAD has no stats
- **WHEN** the Changes panel opens in a repository with no commits and an added `a.txt`
- **THEN** the `a.txt` row has no line stats and no numstat error is notified

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
After a 50 ms debounce, the panel SHALL asynchronously build a full `gleb.diff.view.Spec` for the selected file, with normalized root, repo-relative path, filetype, final-newline state and left text from `HEAD:<orig or path>`. Root and selection generations SHALL drop stale results. One panel-owned view SHALL be reused without changing focus or tab; other rows keep the last diff.

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
- **THEN** columns 1-36 of screen rows 2-29 match design.md "Proposed B — changes panel with the diff view", text and colour mask, and columns 37-100 equal the same diff shown in a regular 64-column editor window

#### Scenario: Changes panel drops a stale diff result
- **WHEN** loading `a.txt` from HEAD is delayed, the panel cursor moves to `b.txt`, and both asynchronous loads finish
- **THEN** the diff view shows `b.txt` and is never replaced by the stale `a.txt` result

#### Scenario: Changes panel skips an unchanged selection
- **WHEN** the diff view already shows `a.txt` and refresh keeps the panel cursor on the same `a.txt` path
- **THEN** the diff view's show function is not called again

### Requirement: Changes panel non-actionable diffs
Added, untracked, deleted, binary, unmerged and submodule rows SHALL produce specs with `actionable = false`. Deleted and binary rows SHALL use read-only buffers without `bufadd`; untracked and added rows SHALL have empty left text. If `show` returns nil, the panel SHALL close only its own view and notify `No content changes: <name>`.

#### Scenario: Changes panel binary row uses a read-only diff
- **WHEN** the cursor moves onto a changed binary file row and 100 ms pass
- **THEN** the shown spec is not actionable, its right buffer is read-only, and `bufadd` was not called for the path

#### Scenario: Changes panel unmerged row uses a read-only diff
- **WHEN** the cursor moves onto an unmerged file row and 100 ms pass
- **THEN** the shown spec is not actionable and neither side is loaded into the file's editable buffer

#### Scenario: Changes panel submodule row has no diff
- **WHEN** the cursor moves onto a changed submodule row and 100 ms pass
- **THEN** no file buffer is loaded and the panel notifies that the row has no file content

#### Scenario: Changes panel closes a contentless diff
- **WHEN** the diff view's `show` returns nil for `mode.txt`
- **THEN** the panel closes its own previous view and notifies `No content changes: mode.txt`

### Requirement: Changes panel review
The `changes.review` action SHALL open the changes panel when it is closed (cursor on the current file's row, else the first file row), focus it when open, and show the diff of the row under the cursor at once.

#### Scenario: Changes panel review shows the current file's diff
- **WHEN** `internal/billing/invoice.go` of the `billing` fixture is edited and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current with its cursor on `invoice.go`, and within 100 ms the editor area shows the diff view of `internal/billing/invoice.go`

#### Scenario: Changes panel review without a changed current file
- **WHEN** `:enew` is current in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the panel cursor is on the `c.lua` row and the diff view shows `lib/c.lua`

### Requirement: Changes panel diff file navigation
While the diff view shows a panel file, `diff.next_file` SHALL move the panel cursor to the next file and show it immediately; the last stays. When invoked from a diff window, completion SHALL focus the new view's `right_win`.

#### Scenario: Changes panel ]f steps through every changed file
- **WHEN** `changes.review` shows `lib/c.lua` of the `dirty` fixture, focus moves to the right diff window and `]f` is pressed four times in normal mode
- **THEN** the diff view shows `a.txt`, `b.txt`, `d.txt` and `new.txt` in that order, once each, and the panel cursor ends on the `new.txt` row

#### Scenario: Changes panel ]f keeps diff focus
- **WHEN** focus is in the right diff window and `]f` shows the next panel file
- **THEN** focus moves to the new diff view's `right_win`, not to the panel or the replaced window

### Requirement: Changes panel open and close
`<CR>` on an actionable file row SHALL close the panel-owned diff view, edit the file in the editor window and focus it, keeping the panel open. `q` SHALL close the panel and only its view; editor restoration SHALL remain in `windows.restore`. Buffers loaded only by the panel SHALL be unloaded on close when unmodified.

#### Scenario: Changes panel Enter opens the file
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** no window with filetype `gleb-diff` remains, the current window edits `b.txt`, and the `gleb-changes` window is still open

#### Scenario: Changes panel q closes the panel and the diff view
- **WHEN** `a.txt` was edited, the changes panel was opened, the diff view shows `b.txt`, and `q` is pressed in normal mode in the panel
- **THEN** no `gleb-changes` or `gleb-diff` window remains, the tab page count is unchanged, and the current window edits `a.txt`

#### Scenario: Changes panel close preserves another diff view
- **WHEN** another diff view exists and `q` closes a Changes panel with its own diff view
- **THEN** the panel-owned view closes and the other diff view remains valid

#### Scenario: Changes panel unloads its clean file buffer
- **WHEN** the panel loaded an otherwise unloaded file for review, the file remains unmodified and `q` closes the panel
- **THEN** that file buffer is unloaded

### Requirement: Changes panel revert
`X` SHALL confirm before reverting with literal pathspecs. A tracked path SHALL use `checkout HEAD`; a rename SHALL restore the old path then remove the new index path; a path absent from HEAD SHALL use `rm --cached`, including on unborn HEAD. Untracked rows do nothing. Failures SHALL notify `Revert failed: <stderr>`.

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

#### Scenario: Changes panel X reverts a rename
- **WHEN** `old.txt` is staged as renamed to `new.txt`, `X` is pressed on `new.txt` and the prompt is answered `y`
- **THEN** literal-pathspec commands check out `old.txt` from HEAD and remove `new.txt` from the index, leaving no rename staged

#### Scenario: Changes panel X on unborn HEAD keeps the file
- **WHEN** `a.txt` is staged in a repository with no commits, `X` is pressed on it and the prompt is answered `y`
- **THEN** literal-pathspec `rm --cached` unstages `a.txt` and `a.txt` remains on disk

### Requirement: Changes panel commit
`gc` SHALL call `gleb.git.ai_commit.show_commit_input(on_commit, { root = root })`, so staged-diff generation and the confirmed literal-pathspec commit run in the panel repository. Success SHALL refresh and notify `Committed: <first line>`; failure SHALL notify `Commit failed: <stderr, else stdout, else exit code>`.

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
The panel SHALL refresh after its git commands, `BufWritePost` in the root, `FocusGained`, and the shared watch module's git-dir event. Buffer- or window-scoped autocmds, per-panel timers and generations SHALL isolate tabs. Refresh SHALL keep the selected path and call public `diff.view.refresh_index(view)` after every panel git command.

#### Scenario: Changes panel refreshes after a write
- **WHEN** the changes panel is open on the `dirty` fixture and `e.txt` is created in the editor window with `:edit e.txt`, `:call setline(1, "x")` and `:write`
- **THEN** within 500 ms the panel lists `e.txt` under `Unversioned Files 2 files` and the panel cursor row shows the same path as before

#### Scenario: Changes panel refreshes after hunk staging
- **WHEN** the Changes panel diff view is open and diff-view stages a hunk, changing the index without focusing another application
- **THEN** the git-dir event refreshes the panel and its open diff view has the new index from `refresh_index`

#### Scenario: Changes panels isolate two tabs
- **WHEN** two tabs have Changes panels for different repositories and both schedule refreshes
- **THEN** each tab keeps its own timer, generation, rows, selected path and diff view

### Requirement: Changes panel window isolation
Panel state SHALL be keyed by tab. Roots and buffer paths SHALL use `fs.normalize`. The panel SHALL use the project tree's exported eligible-editor helper with `gleb-changes` excluded and revalidate before each show. `QuitPre` and orphan-close SHALL follow the project tree. Closing one tab SHALL stop only its panel timers and generations.

#### Scenario: Changes panel normalizes a private-var root
- **WHEN** a panel opens through a `/private/var` symlink spelling of a repository root
- **THEN** its state root and file paths use the same normalized identity as the project tree

#### Scenario: Changes panel revalidates the editor window
- **WHEN** the remembered editor window closes before an asynchronous diff is ready
- **THEN** the panel selects another eligible editor window before calling show and never replaces a tool window

#### Scenario: Changes panel closes when orphaned
- **WHEN** the last eligible editor window closes while a Changes panel remains
- **THEN** the panel, its timers and its panel-owned diff view close

### Requirement: Changes panel keys
The panel keys SHALL come from `changes.*` actions scoped to `gleb-changes`: `<Space>`, `A`, `<CR>`, `X`, `gc`, `P`, `q`, `za`. Those actions SHALL set no `plugin`; the panel SHALL set no local `gr`. `changes.toggle` and `changes.review` SHALL be in Find Action's approved catalog list.

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
