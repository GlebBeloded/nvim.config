# git Specification

## Purpose
Git integration loaded from `lua/gleb/git/`: gutter signs, the changes panel with its owned diff view, diffview for merges and history, permalink copying via `:Gitlink`, and an AI-generated commit message popup.

## Requirements

### Requirement: Module loading
`require("gleb.git")` SHALL load, in order, the gitsigns, diffview and gitlink configurations and the changes panel. The gitsigns and diffview configurations SHALL return without error when their plugin cannot be required. differ.nvim and vscode-diff.nvim SHALL not be installed.

#### Scenario: Missing optional git plugins are tolerated
- **WHEN** `require("gleb.git.gitsigns")` and `require("gleb.git.diffview")` are called with those plugins absent from the runtimepath
- **THEN** no error is raised

#### Scenario: Git commands are available after startup
- **WHEN** Neovim starts with the full config
- **THEN** user commands `Gitsigns`, `DiffviewOpen` and `Gitlink` exist (`vim.fn.exists(":<cmd>") == 2`), and `Differ`, `CodeDiff` and `VscodeDiff` do not

#### Scenario: Removed diff plugins are not registered
- **WHEN** the lazy.nvim plugin list and `lazy-lock.json` are read after startup
- **THEN** neither names `differ.nvim`, `vscode-diff.nvim` or `neo-tree.nvim`, and `diffview.nvim`, `gitsigns.nvim` and `nui.nvim` are still listed

### Requirement: Gutter signs
The config SHALL show git hunk signs in the sign column using `┃` for added, untracked, changed and changed-deleted lines and `` for deleted and top-deleted lines, with number highlighting, line highlighting, word diff and current-line blame disabled by default. No other plugin SHALL draw hunk signs over them.

#### Scenario: Added line shows bar sign
- **WHEN** a tracked file is edited to add a new line and gitsigns has refreshed the buffer
- **THEN** the sign column on that line shows `┃`

#### Scenario: Added line has no competing hunk sign
- **WHEN** a tracked file is edited to add a new line and gitsigns has refreshed the buffer
- **THEN** gitsigns is the only configured hunk-sign source on that line, and `mini.diff` is neither loaded nor registered with lazy.nvim

#### Scenario: Blame is off by default
- **WHEN** a tracked file is opened and the cursor rests on a line for more than 300 ms
- **THEN** no blame virtual text is shown at end of line

#### Scenario: Added line sign matches reference screenshot
- **WHEN** Neovim starts with the full config at 60x8 and `:edit sample.lua` opens a committed file in a temp git repo whose working copy adds `M.x = 1` as line 2, and gitsigns has refreshed the buffer
- **THEN** screen rows 2-5 match the reference screenshot of design.md "Proposed": the sign column of line 2 draws `┃` in [GitSignsAdd] and no other line has a sign

### Requirement: Diffview viewer
The config SHALL set up diffview.nvim with enhanced diff highlighting, `diff2_horizontal` layout for diffs, `diff3_mixed` for merges, and a left file panel 35 columns wide with tree listing, flattened directories and folder statuses only when folded.

#### Scenario: Diffview file panel on the left
- **WHEN** `:DiffviewOpen` is executed in a repository with working-tree changes
- **THEN** the leftmost window of the new tab is the file panel with width 35

### Requirement: Diffview view mappings
In diffview diff windows the config SHALL map, in normal mode, `<tab>`/`<s-tab>` to next/previous entry and `gf` to edit the file, and SHALL retain the default `<leader>co`/`ct`/`cb`/`ca` conflict choices and `dx` choice of none.

#### Scenario: tab moves to next entry
- **WHEN** `:DiffviewOpen` shows two changed files, focus is in a diff window of the first, and `<tab>` is pressed in normal mode
- **THEN** the diff windows show the second file

#### Scenario: dx drops both conflict sides
- **WHEN** `:DiffviewOpen` is open on a file with a merge conflict, the cursor is inside a conflict in a diff window, and `dx` is pressed in normal mode
- **THEN** the conflict markers and both sides are removed from the working-file buffer

#### Scenario: <leader>co chooses ours
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<leader>co` is pressed in normal mode
- **THEN** the working-file buffer holds `ours` in place of the conflict and no conflict marker remains

#### Scenario: <leader>ct chooses theirs
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<leader>ct` is pressed in normal mode
- **THEN** the working-file buffer holds `theirs` in place of the conflict and no conflict marker remains

#### Scenario: <leader>cb chooses base
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<leader>cb` is pressed in normal mode
- **THEN** the working-file buffer holds `base` in place of the conflict and no conflict marker remains

#### Scenario: <leader>ca chooses all
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<leader>ca` is pressed in normal mode
- **THEN** the working-file buffer holds `ours`, `base`, `theirs` in that order in place of the conflict and no conflict marker remains

### Requirement: Diffview file panel mappings
In the diffview file panel, normal-mode `j`/`<Tab>` SHALL select and display the next entry, `k`/`<S-Tab>` the previous entry, `<CR>`/`o`/`l` the current entry, `h` close a fold, `s` toggle staging, `S` stage all, `U` unstage all, `R` refresh, and `q` run `:DiffviewClose`.

#### Scenario: j selects next entry from file panel
- **WHEN** `:DiffviewOpen` shows changed files `a.txt` and `b.txt`, focus is on `a.txt` in the file panel, and `j` is pressed in normal mode
- **THEN** `b.txt` becomes the selected entry and its diff is displayed

#### Scenario: k selects previous entry from file panel
- **WHEN** `:DiffviewOpen` shows changed files `a.txt` and `b.txt`, focus is on `b.txt` in the file panel, and `k` is pressed in normal mode
- **THEN** `a.txt` becomes the selected entry and its diff is displayed

#### Scenario: q closes diffview from file panel
- **WHEN** `:DiffviewOpen` is open, focus is in the file panel, and `q` is pressed in normal mode
- **THEN** the diffview tab is closed and the tab page count returns to its previous value

#### Scenario: s stages entry from file panel
- **WHEN** the cursor is on an unstaged file entry in the diffview file panel and `s` is pressed in normal mode
- **THEN** the file appears in `git diff --cached --name-only`

### Requirement: Gitlink permalink command
The config SHALL configure gitlinker with no default mappings, without printing the URL, and with host `pgw.dev` producing GitHub-style URLs. It SHALL define the `:Gitlink` command accepting a range: without a range it copies the URL for the current line, with a range it copies the URL for the inclusive line endpoints supplied to the command; the URL SHALL be copied to the `+` register. Ranged commands SHALL restore the cursor and visual marks, leave Normal mode, and propagate failures.

#### Scenario: Gitlink copies current line URL
- **WHEN** `:Gitlink` is executed in a tracked file of a repository with a GitHub remote, cursor on line 10
- **THEN** register `+` contains a blob URL for the current commit and file ending in `#L10`

#### Scenario: Gitlink copies range URL
- **WHEN** lines 3-5 are selected in visual mode and `:'<,'>Gitlink` is executed
- **THEN** register `+` contains a blob URL ending in `#L3-L5`
- **THEN** Normal mode is active and the cursor is restored to its pre-command position

#### Scenario: Gitlink range preserves editor state
- **WHEN** `:3,5Gitlink` is executed from Normal mode after a different visual selection was made
- **THEN** Normal mode is active and the cursor and `'<`/`'>` marks retain their pre-command positions

#### Scenario: Gitlink range failure restores editor state
- **WHEN** `:3,5Gitlink` fails while generating a permalink from Normal mode
- **THEN** Normal mode is active and the cursor and `'<`/`'>` marks retain their pre-command positions
- **THEN** the command reports the original failure

#### Scenario: pgw.dev remote uses GitHub URL format
- **WHEN** `:Gitlink` is executed in a repository whose `origin` remote is on host `pgw.dev`
- **THEN** register `+` contains a URL of the form `https://pgw.dev/<owner>/<repo>/blob/<sha>/<path>#L<n>`

### Requirement: AI commit message popup
`require("gleb.git.ai_commit").show_commit_input(on_commit)` SHALL open and focus a centered, rounded floating window (initially 60x3, filetype `gitcommit`, `wrap` on) titled ` 🦙 Generating... ` with footer ` <CR> ✓ │ i edit │ q ✗ `. If `git diff --cached` is empty it SHALL retitle to ` Commit Message `, set the buffer to `# No staged changes` and spawn nothing.

#### Scenario: No staged changes
- **WHEN** `show_commit_input(cb)` is called with nothing staged
- **THEN** the current window is a floating window whose buffer is `{"# No staged changes"}` with filetype `gitcommit`, its title is ` Commit Message `, and no `ollama` job is started

### Requirement: AI commit message generation
With staged changes, the popup SHALL spawn `ollama run tavernari/git-commit-message:sp_commit_mini`, write to its stdin a prompt asking for a `<type>(<scope>): <description>` message under 50 chars followed by the staged diff (first 200 lines plus `... (truncated)` when longer), and close stdin.

#### Scenario: Ollama is spawned with staged diff
- **WHEN** `show_commit_input(cb)` is called with staged changes
- **THEN** a job `ollama run tavernari/git-commit-message:sp_commit_mini` is started and its stdin receives a prompt containing the output of `git diff --cached`

#### Scenario: Long diff is truncated
- **WHEN** `show_commit_input(cb)` is called with a staged diff longer than 200 lines
- **THEN** the prompt sent to the job contains only the first 200 diff lines followed by `... (truncated)`

### Requirement: AI commit message result handling
When the job exits 0 with non-empty output, the config SHALL strip surrounding Markdown code fences and whitespace, put the result lines in the popup buffer and resize the popup to width min(72, 80% of `columns`) and the wrapped line count capped at 10. On exit 0 with empty output the buffer SHALL be `# Error: Ollama returned an empty message`; on a non-zero exit it SHALL be `# Error: Ollama exited with code <code>`. In all cases the title SHALL become ` Commit Message `.

#### Scenario: Generated message fills popup
- **WHEN** the spawned job prints "```\nfeat(git): add x\n```" and exits 0
- **THEN** the popup buffer is `{"feat(git): add x"}` and its title is ` Commit Message `

#### Scenario: Popup resizes to content
- **WHEN** the spawned job prints a one-line message and exits 0 with `columns` = 200
- **THEN** the popup window width is 72 and height is 1

#### Scenario: Ollama failure is shown
- **WHEN** the spawned job exits with code 1
- **THEN** the popup buffer is `{"# Error: Ollama exited with code 1"}` and its title is ` Commit Message `

#### Scenario: Empty Ollama output is shown
- **WHEN** the spawned job prints only whitespace or an empty code fence and exits 0
- **THEN** the popup buffer is `{"# Error: Ollama returned an empty message"}` and its title is ` Commit Message `

### Requirement: AI commit popup actions
In the popup, normal-mode `<CR>` SHALL drop every line starting with `#`, right-trim the remaining lines and trim the whole text; if that text is non-empty it SHALL close the popup and call `on_commit(text)`, otherwise the popup stays open and `on_commit` is not called. Normal-mode `q` and leaving the popup buffer (`BufLeave`) SHALL close the popup and stop a running AI job without calling `on_commit`.

#### Scenario: Enter confirms message
- **WHEN** the popup buffer contains `feat: x  ` and `<CR>` is pressed in normal mode
- **THEN** the popup window is closed and `on_commit` is called once with `feat: x`

#### Scenario: Enter on empty buffer does nothing
- **WHEN** the popup buffer is empty and `<CR>` is pressed in normal mode
- **THEN** the popup stays open and `on_commit` is not called

#### Scenario: Enter on placeholder does nothing
- **WHEN** the popup buffer is `{"# No staged changes"}` or `{"# Error: Ollama exited with code 1"}` and `<CR>` is pressed in normal mode
- **THEN** the popup stays open and `on_commit` is not called

#### Scenario: Enter drops comment lines
- **WHEN** the popup buffer is `{"feat: x", "# note"}` and `<CR>` is pressed in normal mode
- **THEN** the popup window is closed and `on_commit` is called once with `feat: x`

#### Scenario: q discards popup
- **WHEN** `q` is pressed in normal mode in the popup while the AI job is running
- **THEN** the popup window is closed, the job is stopped and `on_commit` is not called

#### Scenario: Leaving popup closes it
- **WHEN** focus leaves the popup buffer with `:wincmd p`
- **THEN** the popup window is closed and `on_commit` is not called

### Requirement: Git popup mapping ownership
The AI commit popup SHALL install its buffer-local `<CR>` and `q` mappings from registered git actions and their `settings/keymap.json` assignments while preserving the existing confirm, validation, cleanup, and discard behavior.

#### Scenario: Commit popup mappings come from git actions
- **WHEN** an AI commit popup is opened with a generated message
- **THEN** its buffer-local confirm and discard lhs values invoke the assigned registered git actions

#### Scenario: Popup confirm action ignores the placeholder
- **WHEN** an AI commit popup shows the `# No staged changes` placeholder and its configured confirm lhs is pressed in normal mode
- **THEN** the popup stays open and `on_commit` is not called

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
The `changes.review` action SHALL open the changes panel when it is closed (cursor on the current file's row, else the first file row), focus it when open, and show the diff of the row under the cursor at once. When run from the dashboard, the panel-owned diff SHALL replace the dashboard window.

#### Scenario: Changes panel review shows the current file's diff
- **WHEN** `internal/billing/invoice.go` of the `billing` fixture is edited and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current with its cursor on `invoice.go`, and within 100 ms the editor area shows the diff view of `internal/billing/invoice.go`

#### Scenario: Changes panel review without a changed current file
- **WHEN** `:enew` is current in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the panel cursor is on the `c.lua` row and the diff view shows `lib/c.lua`

#### Scenario: Changes panel review replaces the dashboard
- **WHEN** Neovim starts on the Alpha dashboard in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current, the diff view shows `lib/c.lua`, and no window displays an `alpha` buffer

### Requirement: Changes panel diff file navigation
While the diff view shows a panel file, `diff.next_file` SHALL move the panel cursor to the next file and show it immediately; the last stays. When invoked from a diff window, completion SHALL focus the new view's `right_win`.

#### Scenario: Changes panel ]f steps through every changed file
- **WHEN** `changes.review` shows `lib/c.lua` of the `dirty` fixture, focus moves to the right diff window and `]f` is pressed four times in normal mode
- **THEN** the diff view shows `a.txt`, `b.txt`, `d.txt` and `new.txt` in that order, once each, and the panel cursor ends on the `new.txt` row

#### Scenario: Changes panel ]f keeps diff focus
- **WHEN** focus is in the right diff window and `]f` shows the next panel file
- **THEN** focus moves to the new diff view's `right_win`, not to the panel or the replaced window

### Requirement: Changes panel open and close
`<CR>` on an actionable file row SHALL close the panel-owned diff view, edit the file in the editor window and focus it as a listed normal file buffer independent of the panel, keeping the panel open. `q` SHALL close the panel and only its view; editor restoration SHALL remain in `windows.restore`. Buffers loaded only by the panel SHALL be unloaded on close when unmodified.

#### Scenario: Changes panel Enter opens the file
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** no window with filetype `gleb-diff` remains, the current window edits `b.txt`, and the `gleb-changes` window is still open

#### Scenario: Changes panel file is an independent normal buffer
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** the current buffer is listed, has empty `buftype`, has the absolute path of `b.txt`, and remains a valid file buffer after the Changes panel closes

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
`gc` SHALL call `gleb.git.ai_commit.show_commit_input(on_commit, { root = root })`, so staged-diff generation and the confirmed literal-pathspec commit run in the panel repository. Its buffer-local mapping SHALL invoke the call without waiting for a longer global `gc` prefix. Success SHALL refresh and notify `Committed: <first line>`; failure SHALL notify `Commit failed: <stderr, else stdout, else exit code>`.

#### Scenario: Changes panel gc commits confirmed message
- **WHEN** `gc` is pressed in normal mode in the changes panel and the popup is confirmed with `feat: x`, then a new change is staged and `gc` is confirmed with `fix: it's $HOME`
- **THEN** after the first commit `git log -1 --format=%s` is `feat: x` and exactly one notification `Committed: feat: x` at INFO is emitted, and after the second it is `fix: it's $HOME` (verbatim, no shell expansion)

#### Scenario: Changes panel gc reports commit failure
- **WHEN** `gc` is pressed in normal mode in the changes panel, the popup is confirmed with `feat: x` and `git commit` exits non-zero (a failing `pre-commit` hook)
- **THEN** a notification starting with `Commit failed:` at ERROR is emitted, none starting with `Committed:`, and `git log -1 --format=%s` is unchanged

#### Scenario: Changes panel gc opens without mapping delay
- **WHEN** plain `gc` is pressed in normal mode in the changes panel while a longer global mapping starts with `gc`
- **THEN** the commit popup exists within 200 ms, before the 1000 ms mapping timeout

#### Scenario: Changes panel gc generates from the panel repository
- **WHEN** the process cwd is outside a panel repository with a staged change and plain `gc` is pressed while a real Ollama executable records its stdin
- **THEN** Ollama receives a prompt containing the staged diff from the panel repository

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
The panel keys SHALL come from `changes.*` actions scoped to `gleb-changes`: `<Space>`, `A`, `<CR>`, `X`, `gc`, `P`, `q`, `za`, `h`, `<Left>`, `zc`, `l`, `<Right>`, `zo`, `zM`, `zR`. Those actions SHALL set no `plugin`; the panel SHALL set no local `gr`. `changes.toggle` and `changes.review` SHALL be in Find Action's approved catalog list.

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
The changes panel and project tree SHALL not be open together in one tab. Opening either SHALL close the other and its owned views, restore or create an editor as needed, and focus the opened panel. Replacing a changes panel SHALL succeed when its window is the tab's last window.

#### Scenario: Changes panel replaces the project tree
- **WHEN** the `file_tree.toggle` action has opened the project tree and the `changes.toggle` action runs
- **THEN** no `gleb-file-tree` window remains and the leftmost window is the focused `gleb-changes` window of width 35

#### Scenario: Project tree replaces the changes panel
- **WHEN** the changes panel shows the diff view of `b.txt` of the `dirty` fixture and the `file_tree.toggle` action runs
- **THEN** no `gleb-changes` or `gleb-diff` window remains and the leftmost window is the focused `gleb-file-tree` window

#### Scenario: Project tree replaces a last-window changes panel
- **WHEN** the `dirty` fixture's changes panel is the tab's only window and the `file_tree.toggle` action runs
- **THEN** the action completes without error, no `gleb-changes` or `gleb-diff` window remains, and the focused window has filetype `gleb-file-tree`

### Requirement: Changes panel screen
The changes panel SHALL match the approved IntelliJ commit-tree render.

#### Scenario: Changes panel matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing` fixture and the `changes.toggle` action runs
- **THEN** columns 1-36 of screen rows 2-12 match design.md "Proposed A — changes panel", text and colour mask

### Requirement: Changes review workflow
In a repository with staged, unstaged and untracked changes, Cmd+G SHALL resolve the repository from a real directory for file and non-file buffers, then open the changes panel with the diff view of the selected file. In a diff window `]f` SHALL show the panel's next changed file and `]c` SHALL move the cursor to the next change of the current file.

#### Scenario: Cmd+G opens the changes review of a dirty repo
- **WHEN** Neovim runs in a fresh copy of the `dirty` fixture and Cmd+G is pressed as a real key press
- **THEN** the changes panel is the leftmost window of the current tab and lists exactly the fixture manifest's changed files: `a.txt` (staged), `b.txt` and `lib/c.lua` (unstaged), `d.txt` (staged and unstaged) and `new.txt` (untracked), and the editor area shows the diff view of `lib/c.lua`

#### Scenario: Cmd+G from a non-file buffer uses a real directory
- **WHEN** Neovim's working directory is the `dirty` fixture, the current named non-file buffer has no filesystem path, and Cmd+G is pressed
- **THEN** Git runs with an existing directory as its working directory, no `ENOENT` error is reported, and the changes review opens for the `dirty` fixture

#### Scenario: Cmd+G with the project tree open replaces it
- **WHEN** the project tree is open in a dirty repository and Cmd+G is pressed as a real key press
- **THEN** no project-tree window remains and the changes panel and its diff view are open

#### Scenario: ]f steps to the next changed file in the changes review
- **WHEN** the changes review shows a changed file of the `dirty` fixture with a diff window focused and `]` `f` is pressed as a real key press
- **THEN** the diff view shows the next file in the panel's order, and repeating `]` `f` visits every changed file of the manifest once

#### Scenario: ]c steps to the next change in the changes review
- **WHEN** the changes review shows `b.txt` of the `dirty` fixture with the cursor of the right diff window in its first change and `]` `c` is pressed as a real key press
- **THEN** the cursor is on the first changed line of the second hunk from the manifest

### Requirement: Diffview mapping ownership
Diffview SHALL disable its default mappings and derive configured window mappings from registered git actions and current `settings/keymap.json` assignments. Diffview's spec-retained `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca` conflict choices SHALL be registered as view-scoped `conflict_choose` actions with those current assignments. Opening a viewer after reassignment SHALL use only the new lhs.

#### Scenario: Diffview mappings come from git actions
- **WHEN** diffview opens a populated view and file panel after `VeryLazy`
- **THEN** every configured mapping invokes the git action assigned by `settings/keymap.json` and an unconfigured diffview default is absent

#### Scenario: Diffview conflict choices come from git actions
- **WHEN** diffview opens a populated conflict view after `VeryLazy`
- **THEN** `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca` invoke the registered `diffview.choose_ours`, `diffview.choose_theirs`, `diffview.choose_base`, and `diffview.choose_all` actions assigned by `settings/keymap.json`

### Requirement: Changes panel fold keys
`changes.close_node`, `changes.expand_node`, `changes.fold_all` and `changes.unfold_all` SHALL apply the shared tree fold verbs to root, directory and nest-parent rows, and `changes.toggle_fold` on a file row SHALL fold its parent and select it. Fold state SHALL survive refreshes, the panel SHALL stay open and focused, and no key SHALL raise an error.

#### Scenario: Changes panel h folds a directory and l unfolds it
- **WHEN** the changes panel is open on a fresh copy of the `billing` fixture, the cursor is on the `internal/billing 4` row, and `h` and then `l` are pressed in normal mode
- **THEN** after `h` no `invoice.go`, `invoice_test.go`, `tax.go` or `tax_test.go` row remains and `internal/billing 4` shows U+F460; after `l` all four are back and the cursor is on `internal/billing 4`

#### Scenario: Changes panel h on a file folds its directory
- **WHEN** the cursor is on the `price.ts` row of the changes panel on the `billing` fixture and `h` is pressed in normal mode
- **THEN** no `price.ts` row remains and the cursor is on the `web/src 1` row, which shows U+F460

#### Scenario: Changes panel l on an open group moves to its first child
- **WHEN** the cursor is on the `Changes 5 files` row of the changes panel on the `billing` fixture and `l` is pressed in normal mode
- **THEN** the rows are unchanged and the cursor is on the `internal/billing 4` row

#### Scenario: Changes panel l on a file does nothing
- **WHEN** the cursor is on the `notes.md` row of the changes panel on the `billing` fixture and `l` is pressed in normal mode
- **THEN** the rows and the cursor are unchanged and the current window's filetype is `gleb-changes`

#### Scenario: Changes panel za on a file folds its parent
- **WHEN** the cursor is on the nested `invoice_test.go` row of the changes panel on the `billing` fixture and `za` is pressed in normal mode
- **THEN** no `invoice_test.go` row remains and the cursor is on the `invoice.go` row, which shows U+F460

#### Scenario: Changes panel zM and zR fold every group
- **WHEN** the cursor is on the `tax_test.go` row of the changes panel on the `billing` fixture and `zM` and then `zR` are pressed in normal mode
- **THEN** after `zM` the rows are `Changes 5 files` and `Unversioned Files 1 file` with the cursor on `Changes 5 files`; after `zR` all ten rows are back in their order and the cursor is still on `Changes 5 files`

#### Scenario: Changes panel arrow keys and zc zo fold without an error
- **WHEN** `v:errmsg` is empty, the cursor is on the `web/src 1` row of the changes panel on the `billing` fixture, and `<Left>`, `<Right>`, `zc` and `zo` are pressed in turn in normal mode
- **THEN** the `price.ts` row is gone after `<Left>` and `zc` and back after `<Right>` and `zo`, and `v:errmsg` is still empty

### Requirement: Branch base resolution
`require("gleb.git.base").resolve(path, callback)` SHALL call back with the base of the repository holding `path`. The base is `origin/<baseRefName>` of the branch's open pull request, else `origin/<default>`, where default is the branch `refs/remotes/origin/HEAD` names, else `main`, else `master`. The result also carries the root, branch, HEAD and `git merge-base <base> HEAD`. The rules SHALL live in `gleb.git.base.rules`, testable without git.

#### Scenario: Branch base defaults to the remote default branch
- **WHEN** a fresh copy of the `prbranch` fixture is on `feat/tax`, the `gh` stub reports no pull request, and `resolve(<copy>/internal/billing/invoice.go, cb)` is called
- **THEN** `cb` receives `root` = the copy, `branch` = `feat/tax`, `head` = the full HEAD oid, `base_ref` = `origin/main`, `merge_base` = the manifest's `merge_base`, `source` = `default` and no `pr`

#### Scenario: Branch base follows the open pull request
- **WHEN** the `gh` stub prints the design.md "Canned pull request" JSON (`number` 482, `state` `OPEN`, `baseRefName` `release/1.4`) and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/release/1.4`, `merge_base` = the manifest's `pr_merge_base`, `source` = `pr`, and `pr.number` = 482 with `pr.url` = `https://pgw.dev/finteqhub/billing/pull/482`

#### Scenario: Branch base uses the pull request base commit when its ref is missing
- **WHEN** `refs/remotes/origin/release/1.4` is deleted from the `prbranch` copy and the `gh` stub prints the canned JSON, whose `baseRefOid` is still in the object store
- **THEN** `cb` receives `base_ref` = `release/1.4`, `base_oid` = the canned `baseRefOid` and `merge_base` = the manifest's `pr_merge_base`

#### Scenario: Branch base rules pick the default branch
- **WHEN** `rules.default_branch(origin_head, refs)` runs over the design.md "Default branch table"
- **THEN** every row returns its expected branch: `origin/develop` names `develop`; no `origin/HEAD` with `origin/main` gives `main`; only `origin/master` gives `master`; no origin refs gives nil

#### Scenario: Branch base rules parse remote hosts
- **WHEN** `rules.remote_host(url)` runs over the design.md "Remote host table"
- **THEN** `git@pgw.dev:finteqhub/billing.git`, `ssh://git@pgw.dev:2222/finteqhub/billing.git` and `https://user@pgw.dev/finteqhub/billing` give `pgw.dev`, `https://github.com/GlebBeloded/nvim.config.git` gives `github.com`, and `/tmp/origin.git`, `file:///tmp/origin.git` and `../origin.git` give nil

### Requirement: Branch base exceptions
There SHALL be no base, and `gh` SHALL not run, outside a repository, on a detached or unborn HEAD, on the remote default branch, on `main` or `master`, without a remote default branch, or when the base and HEAD share no commit. `resolve` then calls back with nil, and no message is shown.

#### Scenario: Branch base is absent on the default branch
- **WHEN** the `prbranch` copy runs `git checkout -q main` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent on master
- **WHEN** a temp repo whose `refs/remotes/origin/HEAD` points to `origin/develop` is on branch `master` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent on a detached HEAD
- **WHEN** the `prbranch` copy runs `git checkout -q --detach` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent outside a repository
- **WHEN** `resolve` is called on a file in a temp directory outside any repository
- **THEN** `cb` receives nil, the `gh` stub log is empty and `:messages` is unchanged

#### Scenario: Branch base is absent without a remote default branch
- **WHEN** a temp repo with commits on `main` and `feat/x` and no remote is on `feat/x` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent for unrelated histories
- **WHEN** a temp repo's branch and `origin/main` have no common commit and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base rules list the no-base cases
- **WHEN** `rules.skip_reason(branch, head, default)` runs over the design.md "No-base table"
- **THEN** detached (`branch` nil), unborn (`head` nil), the default branch, `main`, `master` and a missing default return their reason strings, and `feat/tax` with a head and default `main` returns nil

### Requirement: Branch base pull request lookup
The pull request lookup SHALL run `gh pr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid` in the root, with `GH_HOST` set to the `origin` host and prompts off, killed after `GH_TIMEOUT_MS`. Only an `OPEN` result counts. A missing `gh`, a failure or a timeout SHALL fall back silently to the default branch, keeping the last pull request found for that branch; "no pull requests found" clears it.

#### Scenario: Branch base passes the remote host to gh
- **WHEN** `resolve` is called on the `prbranch` copy, whose `origin` URL is `git@pgw.dev:finteqhub/billing.git`
- **THEN** the `gh` stub log has exactly one line: `GH_HOST` `pgw.dev` and the arguments `pr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid`

#### Scenario: Branch base ignores a merged pull request
- **WHEN** the `gh` stub prints the canned JSON with `state` `MERGED` and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/main`, `source` = `default` and no `pr`

#### Scenario: Branch base falls back when gh fails
- **WHEN** the `gh` stub exits 1 with `error connecting to pgw.dev` on stderr and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/main` and `:messages` is unchanged

#### Scenario: Branch base works without gh
- **WHEN** the child's `PATH` holds only a directory with a `git` symlink, so no `gh` is found, and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/main`, and no error is raised or shown

#### Scenario: Branch base gives up on a slow gh
- **WHEN** `GH_TIMEOUT_MS` is set to 200, the `gh` stub sleeps 30 s and `resolve` is called on the `prbranch` copy
- **THEN** within 2 s `cb` receives `base_ref` = `origin/main`, and the stub process is no longer running

#### Scenario: Branch base keeps the last pull request when gh fails
- **WHEN** a first `resolve` finds the canned open pull request, the stub is switched to exit 1 with `error connecting to pgw.dev`, and `refresh(root, { force = true })` runs
- **THEN** `get(root)` still has `pr.number` 482 and `base_ref` `origin/release/1.4`

#### Scenario: Branch base clears the pull request when none is found
- **WHEN** a first `resolve` finds the canned open pull request, the stub is switched back to "no pull requests found", and `refresh(root, { force = true })` runs
- **THEN** `get(root)` has `base_ref` `origin/main` and no `pr`, and `User GlebGitBaseChanged` fired once for the root with `data.root` = the root

### Requirement: Branch base cache and refresh
Results SHALL be cached per root. `get(root)` returns the cache without running a process. They SHALL be refreshed on `FocusGained`, on a change in the git dir (debounced `WATCH_DEBOUNCE_MS`) and by `refresh(root, opts)`. `gh` runs again only after a branch change, with `force`, or once its last answer is older than `PR_TTL_MS`, with at most one run per root at a time. `User GlebGitBaseChanged` SHALL fire only when the result changes.

#### Scenario: Branch base is cached
- **WHEN** `resolve` is called twice on files of the `prbranch` copy and `FocusGained` fires
- **THEN** the `gh` stub log has one line, both callbacks receive equal results, and `User GlebGitBaseChanged` fired once

#### Scenario: Branch base refreshes after a commit
- **WHEN** after a first `resolve`, a commit is made in the `prbranch` copy by a `git commit` outside Neovim
- **THEN** within 2 s `User GlebGitBaseChanged` fires for the root, `get(root).head` is the new HEAD oid, `merge_base` is unchanged, and the `gh` stub log still has one line

#### Scenario: Branch base refreshes after a checkout
- **WHEN** after a first `resolve`, `git checkout -q main` runs in the `prbranch` copy outside Neovim
- **THEN** within 2 s `User GlebGitBaseChanged` fires for the root and `get(root)` is nil

#### Scenario: Branch base asks gh again after the TTL on focus
- **WHEN** `PR_TTL_MS` is set to 0 after a first `resolve` and `FocusGained` fires
- **THEN** the `gh` stub log has two lines

#### Scenario: Branch base stops watching on reset
- **WHEN** a first `resolve` on the `prbranch` copy has started the git-dir watch and `require("gleb.git.base").reset()` runs
- **THEN** `state.roots` is empty and no libuv fs_event handle of the module is active

#### Scenario: Branch base discards stale asynchronous results
- **WHEN** `reset()` removes a root while its pull-request commit check or merge-base check is in flight
- **THEN** the discarded request calls no resolver callback, publishes no event and does not recreate root state

### Requirement: Committed signs
In a file buffer of a repository with a branch base (`gleb.git.base`), every line changed between the merge-base and HEAD SHALL carry a sign in namespace `gleb_git_committed_signs`: the gitsigns bar for added and changed lines, and the gitsigns delete glyph for deleted ones. The signs are in `GitCommittedSign` (palette purple `#d3869b`) at priority 5, below gitsigns' 6. Without a base, no sign is drawn.

#### Scenario: Committed signs mark the branch's lines
- **WHEN** `internal/billing/invoice.go` of a fresh `prbranch` copy is edited (the `gh` stub reports no pull request)
- **THEN** within 3 s the extmarks of namespace `gleb_git_committed_signs` are exactly on the manifest's `committed` `add` and `change` lines of that file, each with sign text `┃`, `sign_hl_group` `GitCommittedSign` and priority 5, and the manifest's uncommitted `hunks` line has none

#### Scenario: Committed signs mark every line of a file added on the branch
- **WHEN** `internal/billing/tax.go` of a fresh `prbranch` copy is edited
- **THEN** within 3 s every manifest `committed` `add` line of `tax.go` carries a `GitCommittedSign` sign, and no other line does

#### Scenario: Committed signs mark deleted lines
- **WHEN** `lib/util.lua` of the design.md Decision 9 deletion repo is edited on `feat/x`
- **THEN** within 3 s the namespace holds one extmark, on line 2, whose sign text equals the gitsigns config's `delete` text

#### Scenario: Committed signs colour is gruvbox purple
- **WHEN** Neovim starts with the full config, and again after `:colorscheme gruvbox-material`
- **THEN** `GitCommittedSign` resolves to fg `#d3869b`

#### Scenario: Committed signs are absent without a base
- **WHEN** a fresh `prbranch` copy runs `git stash -q` and `git checkout -q main`, and `internal/billing/invoice.go` is edited
- **THEN** after 1 s the namespace `gleb_git_committed_signs` has no extmark in that buffer

#### Scenario: Committed signs kinds and mapping follow the unit table
- **WHEN** `require("gleb.git.committed_signs.map")` `kinds` and `to_buffer` run over the rows of design.md Decision 4
- **THEN** each row returns its committed kinds and its buffer signs, e.g. base `a b c d`, head `a B c x d`, buffer `new a B c x d` gives `{ [3] = "change", [5] = "add" }`

### Requirement: Committed signs follow the buffer
The signs SHALL be re-mapped onto the live buffer, unsaved edits included, within `DEBOUNCE_MS` after an edit. A committed line changed locally SHALL lose its sign, so gitsigns' sign shows. On `User GlebGitBaseChanged` the signs of that root SHALL be recomputed, or cleared when the base is gone. Re-mapping a 10 000-line buffer SHALL take under 50 ms.

#### Scenario: Committed signs move with unsaved edits
- **WHEN** in the edited `invoice.go` of a fresh `prbranch` copy, `ggO// one<Esc>o// two<Esc>` inserts two lines above line 1 without writing
- **THEN** within 1 s the committed signs sit on the manifest lines plus 2, and `&modified` is true

#### Scenario: Committed signs yield to a local change on the same line
- **WHEN** in the edited `invoice.go` of a fresh `prbranch` copy, the first manifest `change` line is replaced with `	Tax   Rate // per invoice` and gitsigns has refreshed
- **THEN** that line has no `gleb_git_committed_signs` extmark and a gitsigns sign, and the other committed lines keep theirs

#### Scenario: Committed signs refresh after a commit
- **WHEN** the edited `invoice.go` of a fresh `prbranch` copy shows its committed signs, and `git commit -qam wip` runs in the copy outside Neovim
- **THEN** within 3 s the manifest's `hunks` line of `invoice.go` also carries a `GitCommittedSign` sign

#### Scenario: Committed signs appear when a root gains a base
- **WHEN** `invoice.go` is opened on `main` without a base, then a feature branch is checked out outside Neovim, the buffer is edited and saved, and the change is committed outside Neovim
- **THEN** within 3 s the committed line carries a `GitCommittedSign` sign without re-entering or reloading the buffer

#### Scenario: Committed signs clear when HEAD is detached
- **WHEN** the edited `invoice.go` of a fresh `prbranch` copy shows its committed signs, and `git checkout -q --detach` runs in the copy outside Neovim
- **THEN** within 3 s the namespace has no extmark in that buffer

#### Scenario: Committed signs map a large buffer quickly
- **WHEN** `kinds` and `to_buffer` run on 10 000 generated lines with one committed change and one inserted buffer line
- **THEN** both together finish in under 50 ms times `H.load_factor()`, and the change maps to its line plus 1

### Requirement: Committed signs limits
Only files changed between the merge-base and HEAD SHALL be read. A file renamed on the branch SHALL be compared with its merge-base path. A binary file, a file over `MAX_BYTES` or a file over `MAX_LINES` lines SHALL get no committed signs.

#### Scenario: Committed signs skip files the branch did not change
- **WHEN** `internal/money/money.go` and a new untracked `notes.md` of a fresh `prbranch` copy are edited
- **THEN** after 1 s neither buffer has a `gleb_git_committed_signs` extmark, and no `git cat-file` ran for them

#### Scenario: Committed signs compare a renamed file with its old path
- **WHEN** `lib/helpers.lua` of the design.md Decision 9 rename repo is edited on `feat/x`
- **THEN** within 3 s only line 2 carries a committed sign

#### Scenario: Committed signs skip a file over the line limit
- **WHEN** `require("gleb.git.committed_signs").MAX_LINES` is set to 10 and `internal/billing/tax.go` (11 lines) of a fresh `prbranch` copy is edited
- **THEN** after 1 s the buffer has no `gleb_git_committed_signs` extmark

### Requirement: Committed signs screen
The editor gutter on a branch SHALL match the approved purple render.

#### Scenario: Committed signs match the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh `prbranch` copy with gopls, null-ls and diagnostics off, and the gitsigns hunk and the committed signs are drawn, with the cursor on line 1
- **THEN** the screen matches the reference screenshot of design.md "Proposed — committed signs", and columns 1-6 of screen rows 2-29 match its colour mask
