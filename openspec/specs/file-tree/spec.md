# file-tree Specification

## Purpose
Provides the project tree sidebar for navigating the current project (`lua/gleb/file_tree/`).

## Requirements

### Requirement: Filesystem tree toggle
The normal-mode project tree toggle SHALL reveal an existing current buffer file and SHALL focus the project tree with its cursor on the root row, without an error, when the current buffer path does not exist on disk.

#### Scenario: Toggle tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised, the current window has filetype `gleb-file-tree` and its cursor is on the root row

### Requirement: Project tree rows
The tree SHALL show a root row (expanded expander, open folder icon, the root's basename in `FileTreeRoot` and, two spaces later, its `~`-relative path in `FileTreeRootPath`), then each folder's entries indented two columns per level: folders first, then files, by name compared case-insensitively, with byte order breaking ties. Files SHALL carry their devicon. Dotfiles SHALL be listed, the `.git` folder hidden by default, and no indent guides drawn.

#### Scenario: Project tree lists folders first in case-insensitive order
- **WHEN** the project tree opens in a copy of the `treeproj` fixture
- **THEN** the rows `.github/workflows`, `cmd/server`, `internal`, `web`, `.gitignore`, `go.mod`, `Makefile`, `notes.md`, `README.md` appear in this relative order below the root row

#### Scenario: Project tree root row names the project
- **WHEN** the project tree opens with the cwd at a copy of the `treeproj` fixture named `billing`
- **THEN** the first row is U+F47C, U+E5FE, `billing`, two spaces, then `vim.fn.fnamemodify(cwd, ":~")`, and `billing` is drawn with `FileTreeRoot`

#### Scenario: Project tree hides the git folder
- **WHEN** the project tree opens in a copy of the `treeproj` fixture
- **THEN** no row names `.git`, and the rows `.github/workflows` and `.gitignore` are present

#### Scenario: Project tree rows have icons and no guides
- **WHEN** the project tree opens in a copy of the `treeproj` fixture and `internal` and `billing` are expanded
- **THEN** the `invoice.go` row starts with nine spaces, then U+E627, a space and `invoice.go`, and no row contains `│`, `├` or `└`

### Requirement: Project tree buffer row correspondence
The project-tree buffer SHALL contain exactly one buffer line for every rendered row, with no trailing blank line, so every cursor position selects a tree row.

#### Scenario: Project tree has no trailing blank row
- **WHEN** the project tree opens in a copy of the `treeproj` fixture, `G` moves to its last line, and `zM` is pressed in normal mode
- **THEN** the buffer line count equals the view row count, the last line renders a tree row, and the fold action completes without error

### Requirement: Compact folder chains
A folder whose only visible entry is a folder SHALL share one row with it, labelled `<a>/<b>`, repeated down the chain, whatever its expansion. The row's expander and its expansion SHALL be those of the last folder of the chain, whose entries are listed one level deeper. A chain SHALL split as soon as one of its folders has more than one visible entry.

#### Scenario: Single-child folders share one row
- **WHEN** the project tree opens in a copy of the `treeproj` fixture
- **THEN** rows `.github/workflows` and `cmd/server` exist, each with U+F460, and no row is labelled `.github` or `cmd` alone

#### Scenario: Expanding a compact row shows the last folder's entries
- **WHEN** the cursor is on the `cmd/server` row and `<CR>` is pressed in normal mode
- **THEN** the row's expander is U+F47C and the next row is `main.go`, indented two columns deeper than `cmd/server`

#### Scenario: A compact chain splits when a folder gains an entry
- **WHEN** the project tree shows `cmd/server` and the directory `cmd/worker` is created on disk
- **THEN** within 1000 ms a row `cmd` exists with rows `server` and `worker` below it, and no row is labelled `cmd/server`

#### Scenario: Every compact chain member is watched
- **WHEN** the project tree shows the compact `cmd/server` row and `cmd/worker` is created on disk
- **THEN** both `cmd` and `cmd/server` have live watch handles before the change, and within 1000 ms the compact row splits into `cmd` with `server` and `worker` below it

### Requirement: Project tree open and close keys
In the tree, `file_tree.open` SHALL toggle a folder row, and on a file row edit the file in the most recently used non-tree window of the tab (creating one to the right if none exists) and focus it. `file_tree.close_node` SHALL collapse an expanded folder, else collapse the row's parent folder and move the cursor to it. `file_tree.open_split`, `open_vsplit` and `open_tab` SHALL open a file row in a split, vertical split or new tab. `file_tree.close` SHALL close the tree.

#### Scenario: Project tree Enter toggles a folder
- **WHEN** the cursor is on the collapsed `internal` row and `<CR>` is pressed twice in normal mode
- **THEN** after the first press the `billing` and `money` rows follow `internal`, and after the second they are gone and `internal` shows U+F460

#### Scenario: Project tree Enter opens a file in the editor window
- **WHEN** the tree is open next to one window showing `go.mod`, the cursor is on the `Makefile` row and `<CR>` is pressed in normal mode
- **THEN** the current window is the former `go.mod` window, its buffer is `Makefile`, and the tree is still open with width 35

#### Scenario: Project tree h on a file collapses its folder
- **WHEN** `internal` and `billing` are expanded, the cursor is on the `invoice.go` row and `h` is pressed in normal mode
- **THEN** the cursor is on the `billing` row, which shows U+F460, and no `invoice.go` row remains

#### Scenario: Project tree v opens a vertical split
- **WHEN** the cursor is on the `Makefile` row next to one file window and `v` is pressed in normal mode
- **THEN** the tab has three windows, the current one shows `Makefile` and is a vertical split of the former file window

#### Scenario: Project tree s opens a horizontal split
- **WHEN** the cursor is on the `Makefile` row next to one file window and `s` is pressed in normal mode
- **THEN** the tab has three windows and the current one shows `Makefile` above or below the former file window

#### Scenario: Project tree t opens a new tab
- **WHEN** the cursor is on the `Makefile` row and `t` is pressed in normal mode
- **THEN** the tab page count increases by one and the current buffer of the new tab is `Makefile`

#### Scenario: Project tree q closes the tree
- **WHEN** the project tree is focused and `q` is pressed in normal mode
- **THEN** no window with filetype `gleb-file-tree` remains and the file window is current

### Requirement: Project tree editor-window hygiene
File-opening actions SHALL run from the target editor window, never the tree, and skip the changes panel, quickfix, terminal, floating and diff-view windows. If a file replaces the tree buffer, it SHALL move to an eligible editor window. New split and tab windows SHALL inherit editor options, not tree-only options.

#### Scenario: Project tree opening skips non-editor windows
- **WHEN** the changes panel, quickfix, terminal, floating and diff-view windows are present, the project tree is focused on `Makefile`, and `<CR>` is pressed in normal mode
- **THEN** `Makefile` opens in the most recently used normal editor window and none of the skipped windows is replaced

#### Scenario: A file cannot replace the project tree buffer
- **WHEN** the project tree window is current and `:edit Makefile` runs
- **THEN** `Makefile` is shown in a normal editor window and the project tree remains open in its own window

#### Scenario: Project tree split windows keep editor options
- **WHEN** `v` or `s` is pressed in normal mode on the `Makefile` row
- **THEN** the new current window shows `Makefile`, has `number` set and does not have `winfixwidth` set

#### Scenario: Project tree tab windows keep editor options
- **WHEN** `t` is pressed in normal mode on the `Makefile` row
- **THEN** the new tab's current window shows `Makefile`, has `number` set and does not have `winfixwidth` set

### Requirement: Project tree window-local hygiene
The tree window SHALL set `foldenable=false`, `foldmethod=manual` and `statuscolumn=""`, detach ufo, and keep those settings local. It SHALL hide the cursor only in normal and visual modes while focused, using the original `guicursor` captured once, and restore that value on leaving or closing the tree.

#### Scenario: Project tree disables editor-only window features
- **WHEN** the project tree opens while ufo is attached to the source editor window
- **THEN** the tree has `foldenable=false`, `foldmethod=manual`, `statuscolumn=""`, no ufo attachment, and the source editor window keeps its original settings

#### Scenario: Project tree preserves the original cursor setting
- **WHEN** the project tree is entered twice from an editor whose `guicursor` has a non-default value, Insert mode is entered once, and the tree is closed
- **THEN** the cursor is hidden only during the tree's normal and visual modes and the original `guicursor` value is restored unchanged

### Requirement: Project tree folds
In the tree, `file_tree.toggle_fold` SHALL toggle a folder or nest-parent row and, on any other file row, collapse its folder and move the cursor to it. `file_tree.fold_all` SHALL collapse every folder and nest and put the cursor on the top-level row that contained the selection. `file_tree.unfold_all` SHALL expand every folder and nest below the root, stopping after 5000 rows with the WARN notification `Unfold all stopped at 5000 rows`.

#### Scenario: Project tree za on a file collapses its folder
- **WHEN** `internal` and `billing` are expanded, the `tax.go` nest is collapsed, the cursor is on the `tax.go` row and `za` is pressed in normal mode
- **THEN** the cursor remains on `tax.go` and `tax_test.go` is listed under it

#### Scenario: Project tree zM collapses every folder
- **WHEN** `cmd/server`, `internal`, `billing` and `web` are expanded, the cursor is on the `invoice.go` row and `zM` is pressed in normal mode
- **THEN** every folder row shows U+F460, the root row is expanded, and the cursor is on the `internal` row

#### Scenario: Project tree zR expands every folder
- **WHEN** only the root is expanded in a copy of the `treeproj` fixture and `zR` is pressed in normal mode
- **THEN** rows `ci.yml`, `main.go`, `invoice.go`, `money.go` and `price.ts` exist and every folder row shows U+F47C

#### Scenario: Project tree unfold all stops at the row limit
- **WHEN** the root holds 60 folders of 100 files each and `zR` is pressed in normal mode
- **THEN** the tree has at most 5001 rows and a WARN notification `Unfold all stopped at 5000 rows` is emitted

### Requirement: Project tree git colours
The tree SHALL read status asynchronously with `git --no-optional-locks -C <root> status --porcelain=v2 -z --untracked-files=normal --ignored=matching` and colour names by status. Ignored records SHALL be separate from file and folder status. A folder SHALL take the strongest descendant status: conflict, modified, added, untracked. Outside a repository it SHALL draw no git colours and run no git command.

#### Scenario: Project tree colours changed files
- **WHEN** the project tree shows the expanded `internal/billing` folder and the root files of a copy of the `treeproj` fixture
- **THEN** `invoice.go` is drawn with `FileTreeGitModified`, `tax.go` with `FileTreeGitAdded`, `notes.md` with `FileTreeGitUntracked`, and `discount.go` and `go.mod` with `FileTreeFileName`

#### Scenario: Project tree folders take the strongest status below them
- **WHEN** in a copy of the `treeproj` fixture `docs/api.md` is created and staged and `scratch/todo.txt` is created untracked, and the tree shows the root
- **THEN** `internal` and `web` are drawn with `FileTreeGitModified`, `docs` with `FileTreeGitAdded`, `scratch` with `FileTreeGitUntracked`, `cmd/server` with `FileTreeFolderName`, and the root name with `FileTreeRoot`

#### Scenario: Project tree colours renamed and conflicted files
- **WHEN** in a copy of the `treeproj` fixture `README.md` is renamed to `READ.md` with `git mv`, `go.mod` is left unmerged by a failed `git merge`, and the tree shows the root
- **THEN** `READ.md` is drawn with `FileTreeGitRenamed` and `go.mod` with `FileTreeGitConflict`

#### Scenario: Project tree reads git status without optional locks
- **WHEN** the project tree opens in a copy of the `treeproj` fixture
- **THEN** `require("gleb.file_tree.git").state.last_cmd` equals `{ "git", "--no-optional-locks", "-C", <root>, "status", "--porcelain=v2", "-z", "--untracked-files=normal", "--ignored=matching" }`

#### Scenario: Project tree outside a repository has no git colours
- **WHEN** the project tree opens in a temp directory outside any git repository that holds `a.txt`
- **THEN** `a.txt` is drawn with `FileTreeFileName` and no notification is emitted

#### Scenario: Project tree runs git status once per burst
- **WHEN** the project tree is open and 20 files are written into the root within 50 ms
- **THEN** after 1000 ms all 20 rows exist and `require("gleb.file_tree.git").state.runs` grew by at most 2

### Requirement: Project tree follows the current file
While the tree is open, entering a file under its root SHALL reveal it without moving focus. `file_tree.reveal` SHALL do the same and focus the tree, opening it if needed. A missing file SHALL select the root. Files outside the root and URI buffers SHALL be ignored. Entering a directory buffer SHALL leave the tree root and cursor unchanged.

#### Scenario: Project tree follows the current file
- **WHEN** the project tree is open and `:edit internal/money/money.go` runs in the file window
- **THEN** the `money` row shows U+F47C, the tree cursor is on the `money.go` row, and the current window is the file window

#### Scenario: Project tree ignores files outside the root
- **WHEN** the project tree is open with its cursor on the `go.mod` row and a file outside the root is edited in the file window
- **THEN** the tree cursor is still on the `go.mod` row and no error is raised

#### Scenario: Project tree reveal focuses the current file
- **WHEN** no project tree is open, the current buffer is `internal/money/money.go` and the action `file_tree.reveal` runs
- **THEN** the current window is the project tree and its cursor is on the `money.go` row

#### Scenario: Project tree reveal tolerates a deleted file
- **WHEN** the current buffer's file was deleted from disk and the action `file_tree.reveal` runs
- **THEN** no error is raised, the project tree is focused and its cursor is on the root row

#### Scenario: Project tree follow tolerates a deleted file
- **WHEN** the project tree is open and `BufEnter` runs for a file buffer whose file was deleted from disk
- **THEN** the tree cursor moves to the root row and no error or notification is raised

#### Scenario: Project tree toggle tolerates a deleted file
- **WHEN** no project tree is open, the current buffer's file was deleted from disk and the action `file_tree.toggle` runs
- **THEN** the project tree opens with its cursor on the root row and no error or notification is raised

#### Scenario: Project tree does not follow a directory buffer
- **WHEN** the project tree cursor is on `go.mod` and a directory buffer for `internal` is entered
- **THEN** the tree root and cursor stay unchanged on `go.mod` and no error or notification is raised

### Requirement: Project tree path normalization
One normalizer SHALL identify roots, buffers, git toplevels and HOME-relative paths by `fs_realpath`, or by the nearest existing parent when the leaf is gone. Scans SHALL cut a folder branch at its first already-seen realpath. Unreadable folders SHALL remain harmless rows. These cases SHALL raise and notify nothing.

#### Scenario: Project tree normalizes a symlinked root
- **WHEN** the cwd reaches a copy of `treeproj` through a directory symlink and the project tree opens
- **THEN** the root and current file resolve to the same real project, the current file is revealed, and the displayed root path is HOME-relative

#### Scenario: Project tree cuts a symlink loop
- **WHEN** the project root contains the symlink `loop -> .` and the project tree opens and unfolds
- **THEN** the `loop` row is not traversed a second time and no error or notification is raised

#### Scenario: Project tree tolerates an unreadable folder
- **WHEN** the project root contains a folder changed to mode `000` and that folder is expanded
- **THEN** the folder remains a row with no children and no error or notification is raised

### Requirement: Project tree live updates
The tree SHALL cache scans and watch every folder whose scan feeds a row, every expanded folder, and the repository git dir. If a safety cap or watch-start failure leaves a listed directory unwatched, the tree SHALL periodically invalidate and rescan it. A filesystem change SHALL redraw within 1000 ms and rerun git status when relevant. Handles and fallback work SHALL stop when no tree for their root needs them. Global `DirChanged` SHALL re-root the current tab's tree.

#### Scenario: Project tree shows files created outside Neovim
- **WHEN** the project tree shows the expanded `internal/billing` folder and `touch internal/billing/fee.go` runs as an external process
- **THEN** within 1000 ms a `fee.go` row exists, drawn with `FileTreeGitUntracked`

#### Scenario: Project tree recolours a written file
- **WHEN** `internal/billing/discount.go` is edited and written with `:write` while the tree shows it
- **THEN** within 1000 ms its row is drawn with `FileTreeGitModified`

#### Scenario: Project tree recolours after staging outside Neovim
- **WHEN** the project tree shows `notes.md` and `git add notes.md` runs as an external process
- **THEN** within 1000 ms `notes.md` is drawn with `FileTreeGitAdded`

#### Scenario: Project tree watchers stop when the tree closes
- **WHEN** the project tree with expanded folders is closed with `q`
- **THEN** `require("gleb.file_tree.watch").state.handles` is empty

#### Scenario: Project tree re-roots on a cwd change
- **WHEN** the project tree is open at a copy of the `treeproj` fixture and `:cd internal` runs
- **THEN** the root row names `internal` and the rows `billing` and `money` follow it

#### Scenario: Project tree prunes a deleted expanded folder
- **WHEN** the project tree cursor is inside expanded `web/src` and `web/src` is deleted on disk
- **THEN** within 1000 ms its rows and expansion entry are gone, its watch handle is closed, the cursor is clamped to an existing row, and no error or notification is raised

#### Scenario: Project tree shares root work across tabs
- **WHEN** two tab pages have project trees open for the same root and one tree closes
- **THEN** git and watch state for that root remains active with one reference, the other tab's buffer and autocmds still work, and the closed tab's view state is gone

#### Scenario: Project tree isolates tabpage state
- **WHEN** two tab pages have project trees open and the first tab is closed before the second is used
- **THEN** the second tree keeps its distinct buffer name, follows files and updates rows without a group-wide autocmd clear or tab-number reuse

#### Scenario: Project tree caps watched folders
- **WHEN** the watch-handle cap is lowered for the test and more expanded folders feed visible rows than the cap permits
- **THEN** the number of live folder handles does not exceed the cap, visible rows remain usable, and no error is raised

#### Scenario: Project tree updates the last folder beyond the legacy watch limit
- **WHEN** the project tree has more than 256 expanded listed directories and an external process creates a file in the alphabetically last directory
- **THEN** within 1000 ms the new file appears in the tree even when that directory has no live watch handle

### Requirement: Project tree remembers expanded folders
The tree SHALL merge relative expanded paths per normalized root into `stdpath("state")/file_tree/expanded.json` with an atomic replacement, preserving other roots, and restore them on open. Missing folders SHALL be dropped. A root without state SHALL start with only the root expanded. Re-rooting SHALL also refresh the worktree's absolute git dir.

#### Scenario: Project tree expanded folders persist per root
- **WHEN** `web` and `src` are expanded, the tree is closed, `require("gleb.file_tree.expanded").reset()` clears the in-memory state, and the action `file_tree.toggle` runs again
- **THEN** the `price.ts` row is shown and `expanded.json` maps the root to a list containing `web` and `web/src`

#### Scenario: Project tree drops a stored folder that is gone
- **WHEN** `expanded.json` lists `web/src` for the root, `web/src` is deleted from disk and the tree opens
- **THEN** no error is raised and `expanded.json` no longer lists `web/src` for the root

#### Scenario: Project tree atomically merges expansion state
- **WHEN** trees for two roots change their expanded folders before pending state writes flush
- **THEN** the valid JSON file contains both roots' latest sorted paths and no partial replacement file remains

#### Scenario: Project tree re-roots across git worktrees
- **WHEN** a project tree is open in one git worktree and global `DirChanged` changes cwd to a second worktree
- **THEN** the root, expanded set, status paths and watched git dir switch to the second worktree using `git rev-parse --absolute-git-dir`

### Requirement: Project tree expansion limits
Manual expansion SHALL stop before exceeding the same 5000-row safety bound as unfold-all and emit the WARN notification `Expansion stopped at 5000 rows`. Watch registration SHALL stop at a configurable handle cap without preventing rows from rendering.

#### Scenario: Project tree manual expansion stops at the row limit
- **WHEN** expanding one folder would grow the tree beyond 5000 rows and `<CR>` is pressed on it in normal mode
- **THEN** the tree has at most 5001 rows and a WARN notification `Expansion stopped at 5000 rows` is emitted

### Requirement: Project tree keys
The project tree actions SHALL be registered in `file_tree/actions.lua` with category `Project`; `file_tree.toggle` and `file_tree.reveal` without a filetype, the others scoped to filetype `gleb-file-tree`. Their keys SHALL come only from `settings/keymap.json`: `open` `<CR>` `o` `l`, `close_node` `h` `<BS>`, `open_split` `s`, `open_vsplit` `v`, `open_tab` `t`, `close` `q`, `toggle_fold` `za`, `fold_all` `zM`, `unfold_all` `zR`.

#### Scenario: Project tree keys come from the keymap file
- **WHEN** the project tree buffer is current and its buffer-local normal-mode mappings are read with `nvim_buf_get_keymap(0, "n")`
- **THEN** each lhs listed for a `file_tree.*` action in `settings/keymap.json` is mapped, and its `desc` is `Project: <action title>`

### Requirement: Project tree look
The tree SHALL draw rows with `FileTreeNormal`, root, path, expander, folder, file, git, cursor-line and devicon groups, using gruvbox-material palette helpers redefined on `ColorScheme`. Each row SHALL expose its exact extmark groups. The reference screen SHALL match `renders/f1_proposed.ansi` verbatim and its reviewed screenshot. The cursor SHALL be hidden only in normal and visual modes.

#### Scenario: Project tree highlight colours come from the palette
- **WHEN** the config has loaded with the gruvbox-material colorscheme
- **THEN** `FileTreeGitModified` fg is `#7daea3`, `FileTreeGitAdded` `#a9b665`, `FileTreeGitUntracked` `#e78a4e`, `FileTreeGitRenamed` `#89b482`, `FileTreeGitConflict` `#ea6962`, `FileTreeRoot` `#ddc7a1` bold, `FileTreeRootPath` `#928374`, and `FileTreeCursorLine` bg `#32302f`

#### Scenario: Project tree matches the approved render
- **WHEN** `HOME` is a temp dir, a copy of the `treeproj` fixture without its ignored entries is the cwd at `~/work/billing`, no nesting rules apply, `internal/billing/invoice.go` is open on a `100x30` screen without LSP or diagnostics, the action `file_tree.toggle` runs, `<CR>` is pressed on the `cmd/server`, `web` and `src` rows, and the cursor returns to the `invoice.go` row
- **THEN** the screen matches the approved render "Proposed F1 — project tree" (design.md) in text and in the colours of the tree window

#### Scenario: Project tree rows expose their highlight groups
- **WHEN** the approved-render fixture is drawn and extmarks are read for every tree row
- **THEN** each icon, expander, root, path, folder and git-coloured name uses the group named by the Proposed F1 legend, and every `FileTree*` and used `DevIcon*` group matches its pinned colours

#### Scenario: Project tree render text matches the ANSI artifact
- **WHEN** the approved-render screen case captures the tree window text with real glyphs
- **THEN** its rows equal `openspec/changes/file-tree-view/renders/f1_proposed.ansi` verbatim and the reference screenshot has been reviewed against that artifact

### Requirement: Project tree create
`file_tree.add` SHALL prompt in `New File or Directory` for a folder row's own folder (a compact row's last folder), a file row's folder, or the root. A trailing `/` SHALL create a folder; another name SHALL create an empty file; missing parents SHALL be created. A new file SHALL open in the focused editor window; a new folder SHALL stay selected. An existing path SHALL notify `Already exists: <relative path>` at ERROR and remain unchanged.

#### Scenario: Project tree a creates a file in the folder under the cursor
- **WHEN** `internal` is expanded, the cursor is on the `billing` row, `a` is pressed in normal mode and `tax_rate.go<CR>` is typed
- **THEN** `internal/billing/tax_rate.go` exists and is empty, the current window is the editor window showing it, and the tree has a `tax_rate.go` row

#### Scenario: Project tree a on a file creates next to it
- **WHEN** the cursor is on the `invoice.go` row, `a` is pressed in normal mode and `fee.go<CR>` is typed
- **THEN** `internal/billing/fee.go` exists

#### Scenario: Project tree a with a trailing slash creates a folder
- **WHEN** the cursor is on the `billing` row, `a` is pressed in normal mode and `rates/<CR>` is typed
- **THEN** `internal/billing/rates` is a directory, the tree cursor is on its row, and the tree window is current

#### Scenario: Project tree a creates missing parent folders
- **WHEN** the cursor is on the root row, `a` is pressed in normal mode and `api/v1/handler.go<CR>` is typed
- **THEN** `api/v1/handler.go` exists and the tree shows the row `api/v1` expanded with `handler.go` below it

#### Scenario: Project tree a reports an existing name
- **WHEN** the cursor is on the `billing` row, `a` is pressed in normal mode and `tax.go<CR>` is typed
- **THEN** a notification `Already exists: internal/billing/tax.go` at ERROR is emitted and the content of `tax.go` is unchanged

#### Scenario: Project tree add prompt matches the approved render
- **WHEN** the tree is shown as in "Proposed F1 — project tree", `a` is pressed on the `invoice.go` row and `tax_rate.go` is typed
- **THEN** the screen matches the approved render "Proposed G1 — add prompt" (design.md) in text and in the colours of the prompt

### Requirement: Project tree rename
`file_tree.rename` SHALL prompt in `Rename` with the entry name. The submitted name SHALL be relative to its folder and MAY contain `/`. One batched `workspace/willRenameFiles` exchange SHALL apply matching clients' edits within 1000 ms total before the move. After every target is confirmed by stat, matching clients SHALL receive one batched `workspace/didRenameFiles` notification and loaded buffers SHALL follow by realpath.

#### Scenario: Project tree r renames a file and its buffer
- **WHEN** `internal/billing/invoice.go` is loaded in buffer N, the cursor is on its tree row, `r` is pressed in normal mode and `<C-u>bill.go<CR>` is typed
- **THEN** `internal/billing/bill.go` exists, `invoice.go` does not, buffer N's name is the absolute path of `bill.go`, `:write` in buffer N raises no error, and the tree cursor is on the `bill.go` row

#### Scenario: Project tree r renames a folder and the buffers inside
- **WHEN** `internal/money/money.go` is loaded, the cursor is on the `money` row, `r` is pressed in normal mode and `<C-u>currency<CR>` is typed
- **THEN** `internal/currency/money.go` exists, `internal/money` does not, and the buffer of `money.go` is named after `internal/currency/money.go`

#### Scenario: Project tree rename asks language servers to update references
- **WHEN** an in-process language server advertising `workspace.fileOperations.willRename` and `didRename` with the filter `**/*.go` is attached, it answers `willRenameFiles` with an edit inserting `// moved` as line 1 of `cmd/server/main.go`, and `invoice.go` is renamed to `bill.go` with `r`
- **THEN** the server received `workspace/willRenameFiles` with `files = { { oldUri = <invoice.go uri>, newUri = <bill.go uri> } }` while `invoice.go` still existed, line 1 of `cmd/server/main.go` is `// moved`, and it then received `workspace/didRenameFiles` with the same files

#### Scenario: Project tree rename skips servers whose filters do not match
- **WHEN** the only attached in-process server's `willRename` filter is `**/*.ts` and `invoice.go` is renamed to `bill.go` with `r`
- **THEN** the server received no `workspace/willRenameFiles` request and `bill.go` exists

#### Scenario: Project tree rename waits for servers at most one second
- **WHEN** the attached in-process server never answers `workspace/willRenameFiles` and `invoice.go` is renamed to `bill.go` with `r`
- **THEN** `bill.go` exists within 1500 ms of `<CR>` and no error is raised

#### Scenario: Project tree r reports an existing name
- **WHEN** the cursor is on the `invoice.go` row, `r` is pressed in normal mode and `<C-u>tax.go<CR>` is typed
- **THEN** a notification `Already exists: internal/billing/tax.go` at ERROR is emitted and both `invoice.go` and `tax.go` keep their content

#### Scenario: Project tree r creates missing destination folders
- **WHEN** the cursor is on the `tax.go` row, `r` is pressed in normal mode and `<C-u>sub/tax2.go<CR>` is typed
- **THEN** `internal/billing/sub/tax2.go` exists with the content of `tax.go`, `internal/billing/tax.go` does not, and no error is emitted

#### Scenario: Project tree rename prompt matches the approved render
- **WHEN** the tree is shown as in "Proposed F1 — project tree" and `r` is pressed on the `invoice.go` row
- **THEN** the screen matches the approved render "Proposed G2 — rename prompt" (design.md) in text and in the colours of the prompt

### Requirement: Project tree delete
`file_tree.delete` SHALL act on the cursor row or deduplicated Visual rows except the root. Confirmation SHALL offer `Move to Trash` and `Cancel` when executable `/usr/bin/trash` exists, otherwise `Delete` and `Cancel`. Trash SHALL run as `/usr/bin/trash -s <lstat paths>`; its failure SHALL notify `Delete failed: <stderr>` at ERROR without permanent fallback. Without it, confirmed paths SHALL be removed recursively.

#### Scenario: Project tree d moves a file to the Trash after confirmation
- **WHEN** `PATH` starts with a directory whose fake `trash` records its arguments and removes them, the cursor is on the `tax_test.go` row, `d` is pressed in normal mode and `Move to Trash` is chosen
- **THEN** the fake `trash` received `-s` and the absolute path of `tax_test.go`, the file is gone, and the tree has no `tax_test.go` row

#### Scenario: Project tree d keeps the file when cancelled
- **WHEN** the cursor is on the `tax_test.go` row, `d` is pressed in normal mode and `Cancel` is chosen
- **THEN** `tax_test.go` still exists and no `trash` command was run

#### Scenario: Project tree Visual d deletes every selected row
- **WHEN** the fake `trash` is on `PATH`, `V` selects the `discount.go` and `discount_test.go` rows, `d` is pressed and `Move to Trash` is chosen
- **THEN** one fake `trash` call received `-s` and both absolute paths, and neither file exists

#### Scenario: Project tree d deletes without a trash command
- **WHEN** `PATH` holds no `trash` executable, the cursor is on the `web` row, `d` is pressed in normal mode and `Delete` is chosen
- **THEN** the `web` folder no longer exists on disk

#### Scenario: Project tree d closes buffers of deleted files
- **WHEN** `internal/billing/tax_test.go` is shown unmodified in the editor window and deleted, then hidden loaded `internal/money/money.go` is deleted, using `d` and `Move to Trash` with the fake `trash` on `PATH`
- **THEN** no buffer is named after either deleted file, the tab has the same number of windows as before, and deleting the hidden buffer creates no listed unnamed buffer

#### Scenario: Project tree d reports a failed delete
- **WHEN** a fake `trash` that prints `boom` on stderr and exits 1 is on `PATH`, and `tax_test.go` is deleted with `d` and `Move to Trash`
- **THEN** a notification `Delete failed: boom` at ERROR is emitted and `tax_test.go` still exists

### Requirement: Project tree copy, cut and paste
`file_tree.copy` and `file_tree.cut` SHALL replace the tree clipboard with the cursor row or deduplicated Visual rows, then return a Visual invocation to Normal mode. `file_tree.paste` SHALL target the folder defined by add. Copies SHALL be recursive and prompt in `Copy` with `<stem>_copy<ext>` on conflict. Cuts SHALL use the rename pipeline and clear after paste. Pasting a folder into itself or below it SHALL notify `Cannot paste <path> into itself` at ERROR.

#### Scenario: Project tree c and p copy a file into another folder
- **WHEN** `c` is pressed in normal mode on the `money.go` row and `p` on the `cmd/server` row
- **THEN** `cmd/server/money.go` has the content of `internal/money/money.go`, which still exists

#### Scenario: Project tree pasting a copy over an existing name asks for a new name
- **WHEN** `c` is pressed on the `invoice.go` row, `p` on the `billing` row, and the prompt titled `Copy`, whose query is `invoice_copy.go`, is confirmed with `<CR>`
- **THEN** `internal/billing/invoice_copy.go` has the content of `invoice.go`

#### Scenario: Project tree c and p copy a folder recursively
- **WHEN** `c` is pressed on the `money` row and `p` on the root row
- **THEN** `money/money.go` and `money/money_test.go` exist at the root with the content of the originals

#### Scenario: Project tree x and p move a file like a rename
- **WHEN** `internal/billing/discount.go` is loaded in buffer N, `x` is pressed on its row and `p` on the `money` row
- **THEN** `internal/money/discount.go` exists, `internal/billing/discount.go` does not, buffer N is named after the new path, and `require("gleb.file_tree.ops").state.clipboard` is nil

#### Scenario: Project tree refuses to paste a folder into itself
- **WHEN** `x` is pressed on the `internal` row and `p` on the `billing` row below it
- **THEN** a notification `Cannot paste internal into itself` at ERROR is emitted and `internal/billing/invoice.go` still exists

#### Scenario: Project tree Visual c copies every selected row
- **WHEN** `V` selects the `discount.go` and `invoice.go` rows, `c` is pressed, and `p` is pressed on the `money` row
- **THEN** `internal/money/discount.go` and `internal/money/invoice.go` exist

#### Scenario: Project tree Visual copy and cut return to Normal mode
- **WHEN** multiple project-tree rows are selected with `V`, then `c` and `x` are each invoked through their Visual mappings
- **THEN** each operation captures the selected paths in the tree clipboard and leaves Neovim in Normal mode

### Requirement: Project tree refresh and operation keys
`file_tree.refresh` SHALL rescan every expanded folder and rerun git status at once. The operation actions SHALL be scoped to filetype `gleb-file-tree` with keys only from `settings/keymap.json`: `add` `a`, `rename` `r`, `delete` `d`, `copy` `c`, `cut` `x`, `paste` `p`, `refresh` `R`, with `delete`, `copy` and `cut` also in Visual mode.

#### Scenario: Project tree R picks up changes at once
- **WHEN** the watchers are stopped with `require("gleb.file_tree.watch").stop_all()`, `internal/billing/fee.go` is created on disk, and `R` is pressed in normal mode
- **THEN** a `fee.go` row exists and `require("gleb.file_tree.git").state.runs` grew by one

#### Scenario: Project tree operation keys come from the keymap file
- **WHEN** the project tree buffer is current and its buffer-local mappings are read with `nvim_buf_get_keymap(0, "n")` and `nvim_buf_get_keymap(0, "x")`
- **THEN** normal mode maps `a`, `r`, `d`, `c`, `x`, `p` and `R`, Visual mode maps `d`, `c` and `x`, each with the `desc` `Project: <action title>` of its `settings/keymap.json` action

### Requirement: Project tree operation path safety
Every submitted path SHALL normalize inside the tree root with no absolute path, `..` or empty segment. Rename, delete, copy and cut SHALL refuse the root row. Create and move failures SHALL leave the tree and filesystem consistent and notify their operation-specific ERROR message.

#### Scenario: Project tree refuses operations on the root row
- **WHEN** the cursor is on the root row and `r`, `d`, `c` and `x` are each pressed in normal mode
- **THEN** no prompt opens, the tree clipboard stays nil, the root still exists, and no filesystem entry changes

#### Scenario: Project tree Visual operations refuse the root row
- **WHEN** the root row alone is selected in Visual mode and `d`, `c` and `x` are each pressed
- **THEN** no confirmation opens, the tree clipboard stays nil, the root still exists, and no filesystem entry changes

#### Scenario: Project tree refuses a path that escapes the root
- **WHEN** the cursor is on the `billing` row, `r` is pressed in normal mode and `<C-u>../../../outside<CR>` is typed
- **THEN** `internal/billing` still exists, no path named `outside` is created beyond the root, and a `Rename failed:` notification at ERROR is emitted

#### Scenario: Project tree refuses unsafe submitted names
- **WHEN** rename is submitted for `invoice.go` with `../moved.go`, `/absolute.go` and `sub//moved.go`, then `money.go` is copied onto its folder and the Copy prompt is submitted with `../../../escaped.go`
- **THEN** neither source changes, no submitted target is created inside or outside the root, and each submission emits its operation-specific ERROR notification

#### Scenario: Project tree create reports a read-only destination
- **WHEN** the root has mode `0555`, the cursor is on its row, `a` is pressed in normal mode and `blocked.go<CR>` is typed
- **THEN** no `blocked.go` exists and a `Create failed:` notification at ERROR is emitted

### Requirement: Project tree move preflight
`ops.move(pairs)` SHALL preflight every pair before LSP traffic or mutation: source lstat exists; target is absent case-insensitively except its source; target is inside the root; source and destination parent have the same `dev`; and no pair is the root. A cross-device pair SHALL notify `Rename failed: cross-device`. A failed pair SHALL prevent the entire batch from moving or contacting LSP.

#### Scenario: Project tree rename refuses a vanished row
- **WHEN** the tree still shows `invoice.go` after it is removed on disk, `r` is pressed on its row and `<C-u>bill.go<CR>` is typed
- **THEN** `bill.go` does not exist, no LSP rename message is sent, and a `Rename failed:` notification at ERROR is emitted

#### Scenario: Project tree move preflights the whole batch
- **WHEN** two cut rows are pasted and the second source has vanished before `p` is pressed
- **THEN** neither source is moved, no `workspace/willRenameFiles` request is sent, and a `Rename failed:` notification at ERROR is emitted

#### Scenario: Project tree refuses a cross-device move
- **WHEN** `ops.move` is called for a source and destination whose stat results have different `dev` values
- **THEN** neither path changes, no LSP rename message is sent, and `Rename failed: cross-device` is notified at ERROR

#### Scenario: Project tree rename reports a read-only destination
- **WHEN** the destination folder has mode `0555`, `r` is pressed on the `invoice.go` row and `<C-u>bill.go<CR>` is typed
- **THEN** `invoice.go` still exists, `bill.go` does not, and a `Rename failed:` notification at ERROR is emitted

### Requirement: Project tree move identity and state
A case-only rename SHALL move through a temporary sibling. Buffer names SHALL follow moved files by realpath, including symlinked roots and `/private/var` aliases; symlink rows SHALL instead move buffers opened through their logical path. Folder moves SHALL migrate every expanded relative key below the old path. Every view of the same root SHALL refresh once per successful batch, after all targets stat successfully and before `didRenameFiles`.

#### Scenario: Project tree supports a case-only rename
- **WHEN** the cursor is on `README.md`, `r` is pressed in normal mode and `<C-u>Readme.md<CR>` is typed on a case-insensitive filesystem
- **THEN** `Readme.md` exists with the original content, `README.md` does not, and no temporary sibling remains

#### Scenario: Project tree rename follows a buffer opened through a symlinked root
- **WHEN** `invoice.go` is loaded through a symlink to the project root and its tree row is renamed to `bill.go` with `r`
- **THEN** the loaded buffer is named through the symlink as `internal/billing/bill.go`, writes to the moved file, and no buffer retains the old realpath

#### Scenario: Project tree rename moves a symlink and not its target
- **WHEN** a tree row is a symlink to a file outside the root and the row is renamed with `r`
- **THEN** the symlink and a buffer opened through it move by logical path, while the outside target and its content are unchanged

#### Scenario: Project tree case-only rename moves a symlink by logical path
- **WHEN** `link.txt` is a symlink to a file outside the root, buffers are loaded for both the target and `link.txt`, and the tree row is renamed to `Link.txt` with `r` on a case-insensitive filesystem
- **THEN** the symlink and only the buffer opened as `link.txt` move to the logical `Link.txt` path, the target buffer keeps its outside path, and writing either buffer creates no outside sibling

#### Scenario: Project tree folder rename migrates expanded keys
- **WHEN** `internal` and `internal/billing` are expanded and `internal` is renamed to `domain` with `r`
- **THEN** the tree remains expanded through `domain/billing`, expanded state contains `domain` and `domain/billing`, and contains no key below `internal`

#### Scenario: Project tree move notifies didRename only after the target exists
- **WHEN** an in-process server records filesystem state when `workspace/didRenameFiles` arrives and `invoice.go` is renamed to `bill.go`
- **THEN** its one didRename batch arrives after `bill.go` stats successfully and after `invoice.go` is absent

### Requirement: Project tree delete buffer safety
Delete SHALL remove each selected lstat path, never its realpath target. Only files confirmed absent by stat SHALL have unmodified buffers wiped across all tabs. Replacement buffers SHALL not name a deleted file. Modified buffers SHALL remain open, the confirmation SHALL count them, and auto-save SHALL skip missing paths. A vanished row SHALL be treated as gone without deleting another path.

#### Scenario: Project tree delete refuses a vanished row safely
- **WHEN** the tree still shows `tax_test.go` after it is removed on disk and `d` then confirmation are used on its row
- **THEN** no other path is removed, the stale row disappears, and no fallback path is deleted

#### Scenario: Project tree fallback delete reports a read-only destination
- **WHEN** `/usr/bin/trash` is unavailable through the test override, the containing folder has mode `0555`, and `Delete` confirms deleting `tax_test.go`
- **THEN** `tax_test.go` still exists and a `Delete failed:` notification at ERROR is emitted

#### Scenario: Project tree delete removes a symlink and not its target
- **WHEN** the selected row is a symlink to a file outside the root and `d` is confirmed
- **THEN** the symlink is gone and the outside target and its content are unchanged

#### Scenario: Project tree trash failure never falls back to permanent delete
- **WHEN** the configured trash command exits 1 after printing `boom` and deleting nothing, and `d` is confirmed on `tax_test.go`
- **THEN** `tax_test.go` still exists, no recursive delete runs, and `Delete failed: boom` is notified at ERROR

#### Scenario: Project tree delete does not let auto-save resurrect a file
- **WHEN** a modified buffer for `tax_test.go` is open, its tree row is deleted after a confirmation naming one unsaved buffer, and the auto-save event runs
- **THEN** the modified buffer stays open, `tax_test.go` remains absent, and `should_autosave` returns false for it

#### Scenario: Project tree delete preserves windows across tabs
- **WHEN** unmodified buffers for `tax_test.go` are displayed in two tabs and its tree row is deleted
- **THEN** both buffers are wiped, every window remains, and no replacement buffer names `tax_test.go`

### Requirement: Project tree copy and paste safety
Folder copy SHALL preflight the complete destination before writing and recreate symlinks without following them. A conflict SHALL re-prompt with `_copy2` when `_copy` exists. A cut SHALL never overwrite, and cutting into its current parent SHALL do nothing. A missing clipboard source SHALL notify `Paste failed: <path>: ENOENT` and SHALL NOT stop other clipboard entries.

#### Scenario: Project tree copy conflict advances to copy2
- **WHEN** `invoice.go` and `invoice_copy.go` exist, `c` and `p` are used on `invoice.go` in `billing`, and the conflict prompt opens
- **THEN** its query is `invoice_copy2.go` and confirming it creates that file without changing either existing file

#### Scenario: Project tree folder copy preflights before writing
- **WHEN** a copied folder contains two files and the second destination already exists before `p` is pressed
- **THEN** no destination entry from that folder is created or overwritten and the conflict is resolved before copying starts

#### Scenario: Project tree folder copy recreates symlinks
- **WHEN** a copied folder contains a symlink to a file outside that folder and `p` is pressed on the root row
- **THEN** the destination contains a symlink with the same link text and the external target is neither copied nor changed

#### Scenario: Project tree cut refuses an existing target name
- **WHEN** `x` is pressed on `internal/billing/invoice.go` and `p` on a folder already containing `invoice.go`
- **THEN** both files keep their content, the source remains, and `Already exists: <relative path>` is notified at ERROR

#### Scenario: Project tree cut into its current parent is a no-op
- **WHEN** `x` is pressed on `internal/billing/invoice.go` and `p` on the `billing` row
- **THEN** the source stays in place unchanged, no LSP rename message is sent, and the clipboard is cleared

#### Scenario: Project tree paste continues after a missing clipboard path
- **WHEN** two copied paths are pasted after the first is removed from disk
- **THEN** `Paste failed: <first relative path>: ENOENT` is notified at ERROR and the second path is copied

### Requirement: Project tree refresh isolation
`file_tree.refresh` SHALL rescan the initiating view's expanded folders and start at least one immediate git-status run without replacing another tab's distinct root, expansion set, selection or buffer state.

#### Scenario: Project tree R starts at least one git status run
- **WHEN** `R` is pressed in a project tree and the git run count before and after is read
- **THEN** the run count grows by at least one

#### Scenario: Project tree R preserves another tab's tree state
- **WHEN** two tabs have trees with distinct roots, expanded folders and selections, and `R` is pressed in the first tab
- **THEN** the first tree refreshes while the second tree keeps its root, expanded folders, selection and buffer name unchanged

### Requirement: File tree nesting settings
`settings/file_tree.json` SHALL hold `nesting.enabled` and the ordered list `nesting.rules`. A pattern rule's `parent` and `children` SHALL be Lua patterns matched against a whole file name. A child template's `${capture}` (first capture) and `${1}`…`${9}` SHALL insert the parent's captures literally. A rule with a malformed pattern or an unknown capture SHALL be skipped with a WARN. An unreadable file SHALL disable nesting with an ERROR, and a write from Neovim SHALL reload it.

#### Scenario: Nesting rule nests by capture
- **WHEN** `require("gleb.tree.nesting").nest(dir, entries, rules)` gets the files `discount.go`, `discount_test.go`, `invoice.go`, `invoice_test.go`, `invoice_mock.go`, `tax.go` and the one rule `{ parent = "(.+)%.go", children = { "${capture}_test%.go", "${capture}_mock%.go" } }`
- **THEN** it returns exactly `{ ["discount.go"] = { "discount_test.go" }, ["invoice.go"] = { "invoice_mock.go", "invoice_test.go" } }`

#### Scenario: Nesting patterns match whole names
- **WHEN** `nest` gets the files `go.mod`, `go.sum`, `go.sum.bak`, `xgo.mod` and the rule `{ parent = "go%.mod", children = { "go%.sum" } }`
- **THEN** it returns exactly `{ ["go.mod"] = { "go.sum" } }`

#### Scenario: Nesting captures are inserted literally
- **WHEN** `nest` gets the files `a.b.ts`, `a.b.test.ts`, `aXb.test.ts` and the rule `{ parent = "(.+)%.ts", children = { "${capture}%.test%.ts" } }`
- **THEN** it returns exactly `{ ["a.b.ts"] = { "a.b.test.ts" } }`

#### Scenario: Broken nesting rules are skipped
- **WHEN** `nest` gets the files `go.mod`, `go.sum`, `init.lua`, `init_spec.lua` and the rules `{ parent = "go%.mod", children = { "${capture}%.sum" } }`, `{ parent = "[", children = { "x" } }`, `{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } }`
- **THEN** it returns exactly `{ ["init.lua"] = { "init_spec.lua" } }`, and WARN notifications starting `File tree nesting rule 1 skipped` and `File tree nesting rule 2 skipped` are shown, once each per load

#### Scenario: Invalid settings file disables nesting
- **WHEN** the settings path holds `{ "nesting": ` and the tree opens on the `treeproj` fixture with `internal/billing` expanded
- **THEN** an ERROR notification starting `File tree settings invalid` is shown, and `discount.go`, `discount_test.go`, `invoice.go`, `invoice_test.go`, `tax.go`, `tax_test.go` are sibling rows without a file chevron

#### Scenario: Writing the settings file reloads nesting
- **WHEN** the tree is open on the `treeproj` fixture with `internal/billing` expanded, the settings path (a temporary copy of the default file) is edited in a buffer to remove the `(.+)%.go` rule, and `:write` is run
- **THEN** within 1 s `invoice_test.go` is a sibling row of `invoice.go`, and `invoice.go` has no chevron

#### Scenario: Nesting can be turned off
- **WHEN** the settings file sets `nesting.enabled` to `false` and the tree opens on the `treeproj` fixture with `internal/billing` expanded
- **THEN** the six Go files of `internal/billing` are sibling rows in name order, and no file row has a chevron

#### Scenario: Writing settings through a normalized path reloads nesting
- **WHEN** `settings.setup` receives a settings path under `/var`, the same file is edited through its normalized `/private/var` path to remove the `(.+)%.go` rule, and `:write` is run
- **THEN** within 1 s `invoice_test.go` is a sibling row of `invoice.go`, and `invoice.go` has no chevron

### Requirement: File tree programmable nesting rules
A rule `{ "lua": "<module>" }` SHALL call the function `require("<module>")` returns with the folder's absolute path and its file names. The returned parent → children map SHALL take part in precedence at the rule's position. Names that are not files of the folder SHALL be ignored. A module that fails to load, errors or returns no table SHALL be skipped with a WARN, and later rules SHALL still apply.

#### Scenario: Lua nesting rule nests by function
- **WHEN** `package.preload["nest_sql"]` returns a function that returns `{ ["schema.sql"] = { "schema_seed.sql", "missing.sql", "schema.sql" } }`, and `nest("/repo/db", entries, { { lua = "nest_sql" } })` gets the files `schema.sql`, `schema_seed.sql`, `other.sql`
- **THEN** the function is called with `"/repo/db"` and the three names, and `nest` returns exactly `{ ["schema.sql"] = { "schema_seed.sql" } }`

#### Scenario: Failing Lua nesting rule is skipped
- **WHEN** `package.preload["nest_boom"]` returns a function that raises `boom`, and `nest` gets the files `init.lua`, `init_spec.lua` and the rules `{ lua = "nest_boom" }`, `{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } }`
- **THEN** it returns exactly `{ ["init.lua"] = { "init_spec.lua" } }`, and one WARN notification starting `File tree nesting rule 1 skipped` and containing `boom` is shown

### Requirement: File tree nesting precedence
Nesting SHALL be one level within one folder and SHALL apply to files only. Claims SHALL be taken in rule order, so the first rule that claims a file is its parent. A claim whose parent descends from the child SHALL be dropped. A child whose parent is itself nested SHALL be listed under the top parent. A file SHALL never be its own child. Children SHALL be listed in the tree's name order.

#### Scenario: Earlier nesting rule wins a shared child
- **WHEN** `nest` gets the files `price.ts`, `price.js`, `price.d.ts`, `price.js.map` and the default TypeScript rule followed by the default JavaScript rule
- **THEN** it returns exactly `{ ["price.ts"] = { "price.d.ts", "price.js", "price.js.map" } }`

#### Scenario: Nesting cycles keep rule order
- **WHEN** `nest` gets the files `a.ts`, `a.js` and the rules `{ parent = "(.+)%.ts", children = { "${capture}%.js" } }`, `{ parent = "(.+)%.js", children = { "${capture}%.ts" } }`
- **THEN** it returns exactly `{ ["a.ts"] = { "a.js" } }`

#### Scenario: Folders never nest
- **WHEN** `nest` gets the entries `{ name = "invoice.go", path = "/repo/invoice.go", kind = "file" }`, `{ name = "invoice_test.go", path = "/repo/invoice_test.go", kind = "directory" }` and the default Go rule
- **THEN** it returns an empty table

### Requirement: File tree nesting cache and limits
Nest maps SHALL be cached by the folder's `fs.scan` table and the settings generation, held through weak keys. Reloading settings SHALL bump the generation. Git-only redraws SHALL not run rules again. A substituted child SHALL use a name lookup. The 16 default rules over 5000 files SHALL finish within 50 ms. The 5000-row expansion cap SHALL count nest children.

#### Scenario: Default nesting rules meet the large-folder bound
- **WHEN** `nest` runs all 16 default rules over 5000 file entries after one warm-up run
- **THEN** the measured run finishes within 50 ms

#### Scenario: Git redraw reuses the nest map
- **WHEN** a Lua nesting rule increments a counter, the tree draws one folder, and a git-status update redraws the same unchanged `fs.scan` table without a settings reload
- **THEN** the counter remains `1`

#### Scenario: Unfold all counts nested children toward the row limit
- **WHEN** the root has enough parent files and nested children to exceed 5000 visible rows and `zR` is pressed in normal mode
- **THEN** the tree has at most 5001 rows and a WARN notification `Unfold all stopped at 5000 rows` is emitted

### Requirement: File tree default nesting rules
`settings/file_tree.json` SHALL ship `nesting.enabled = true` and the default rules for Go, protobuf, `go.mod`, `go.work`, TypeScript, TSX, JavaScript, `package.json`, `tsconfig.json`, Python, `pyproject.toml`, `Cargo.toml`, Lua specs, `.gitignore`, `README*` and `Makefile`, in that order, with the children the user approved (design.md Decision 5).

#### Scenario: Default nesting rules nest Go files
- **WHEN** `nest` gets the default rules and the files `invoice.go`, `invoice_test.go`, `invoice_mock.go`, `invoice_string.go`, `api.proto`, `api.pb.go`, `api_grpc.pb.go`, `go.mod`, `go.sum`, `go.work`, `go.work.sum`
- **THEN** it returns exactly `invoice.go` → `invoice_mock.go`, `invoice_string.go`, `invoice_test.go`; `api.proto` → `api.pb.go`, `api_grpc.pb.go`; `go.mod` → `go.sum`; `go.work` → `go.work.sum`

#### Scenario: Default nesting rules nest web files
- **WHEN** `nest` gets the default rules and the files `price.ts`, `price.test.ts`, `price.spec.ts`, `price.d.ts`, `price.js`, `price.d.ts.map`, `price.js.map`, `cart.tsx`, `cart.test.tsx`, `cart.stories.tsx`, `cart.module.css`, `util.js`, `util.min.js`, `util.d.ts`, `package.json`, `package-lock.json`, `yarn.lock`, `.npmrc`, `.nvmrc`, `tsconfig.json`, `tsconfig.build.json`
- **THEN** it returns exactly `price.ts` → `price.d.ts`, `price.d.ts.map`, `price.js`, `price.js.map`, `price.spec.ts`, `price.test.ts`; `cart.tsx` → `cart.module.css`, `cart.stories.tsx`, `cart.test.tsx`; `util.js` → `util.d.ts`, `util.min.js`; `package.json` → `.npmrc`, `.nvmrc`, `package-lock.json`, `yarn.lock`; `tsconfig.json` → `tsconfig.build.json`

#### Scenario: Default nesting rules nest Python and Rust files
- **WHEN** `nest` gets the default rules and the files `money.py`, `money.pyi`, `test_money.py`, `money_test.py`, `pyproject.toml`, `uv.lock`, `requirements-dev.txt`, `setup.cfg`, `setup.py`, `.python-version`, `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `rustfmt.toml`, `.rustfmt.toml`, `clippy.toml`
- **THEN** it returns exactly `money.py` → `money.pyi`, `money_test.py`, `test_money.py`; `pyproject.toml` → `.python-version`, `requirements-dev.txt`, `setup.cfg`, `setup.py`, `uv.lock`; `Cargo.toml` → `.rustfmt.toml`, `Cargo.lock`, `clippy.toml`, `rust-toolchain.toml`, `rustfmt.toml`

#### Scenario: Default nesting rules nest project files
- **WHEN** `nest` gets the default rules and the files `init.lua`, `init_spec.lua`, `.gitignore`, `.gitattributes`, `.gitmodules`, `README.md`, `CHANGELOG.md`, `LICENSE`, `Makefile`, `rules.mk`
- **THEN** it returns exactly `init.lua` → `init_spec.lua`; `.gitignore` → `.gitattributes`, `.gitmodules`; `README.md` → `CHANGELOG.md`, `LICENSE`; `Makefile` → `rules.mk`

### Requirement: File tree nest rows
A file with at least one present child SHALL show a chevron in the expander column, drawn with `FileTreeExpander` in the folder expander glyphs, collapsed or expanded. Every nest SHALL start collapsed. Child rows SHALL follow their parent, indented one level deeper, with no chevron and the same icon and name groups as other files. A nest's expanded state SHALL survive refreshes for as long as the tree lives.

#### Scenario: Nests start collapsed under a chevron
- **WHEN** `file_tree.toggle` opens the tree on the `treeproj` fixture and `internal/billing` is expanded
- **THEN** that folder's rows are exactly `discount.go`, `invoice.go`, `tax.go`, each with the collapsed chevron, and no `_test.go` row is listed

#### Scenario: Nest children are indented under the parent
- **WHEN** the tree is open on the `treeproj` fixture with `internal/billing` expanded, and `za` is pressed on the `invoice.go` row
- **THEN** `invoice.go` shows the expanded chevron, the next row is `invoice_test.go` with its icon 2 columns right of `invoice.go`'s icon and no chevron, and the row after it is `tax.go`

#### Scenario: Nest state survives a refresh
- **WHEN** the `invoice.go` nest is expanded and `R` is pressed in the tree
- **THEN** after the refresh `invoice_test.go` is still listed under `invoice.go`, and the `discount.go` nest is still collapsed

### Requirement: File tree nest state
Each tab SHALL keep `expanded_nests` separately from `expanded`, keyed by the parent's path relative to the root. Nest state SHALL not be stored in `expanded.json`. `zM` and rerooting SHALL clear it. Drawing SHALL drop a key whose parent is gone, is not a file, or has no child. File and folder moves SHALL migrate matching keys in every view of the root.

#### Scenario: Nest state is isolated between tabs
- **WHEN** two tabs show the same root, the `invoice.go` nest is expanded in the first tab, and the second tab is focused
- **THEN** `invoice_test.go` is listed only in the first tab and the second tab's `invoice.go` nest remains collapsed

#### Scenario: Fold all and reroot clear nest state
- **WHEN** the `invoice.go` nest is expanded, `zM` is pressed, and the tree is then rerooted by changing cwd to another fixture root
- **THEN** `expanded_nests` is empty after `zM` and remains empty after rerooting, while `expanded.json` contains no nest-parent key

#### Scenario: Drawing prunes stale nest state
- **WHEN** `expanded_nests` contains parents that are gone, are directories, or no longer have a child and the tree draws
- **THEN** all three parent keys are absent from `expanded_nests`

#### Scenario: Renaming a nest parent migrates its state
- **WHEN** the `invoice.go` nest is expanded and `r` renames it to `bill.go` together with a matching `bill_test.go`
- **THEN** the old relative key is absent, the `bill.go` key is present, and `bill_test.go` is listed under `bill.go`

#### Scenario: Renaming a folder migrates nest state in every view
- **WHEN** two tabs show the same root with the `invoice.go` nest expanded and `r` renames `internal/billing` to `internal/accounts` in one tab
- **THEN** both views replace the old nest key with `internal/accounts/invoice.go` and keep `invoice_test.go` listed

### Requirement: File tree nest actions
`file_tree.toggle_fold` SHALL toggle the nest of a parent row. On a child row, it and `file_tree.close_node` SHALL collapse the nest and move the cursor to the parent. `file_tree.close_node` on an expanded parent SHALL collapse it. `file_tree.open` SHALL open a parent's file without toggling. `file_tree.unfold_all` and `file_tree.fold_all` SHALL also expand and collapse nests. Following the current file and revealing a new file SHALL expand their nest.

#### Scenario: za toggles a nest
- **WHEN** `za` is pressed twice on the `invoice.go` row
- **THEN** after the first press `invoice_test.go` is listed under it, and after the second it is not

#### Scenario: h on a nested file closes its nest
- **WHEN** the `invoice.go` nest is expanded, the cursor is on `invoice_test.go`, and `h` is pressed
- **THEN** `invoice_test.go` is no longer listed and the cursor is on the `invoice.go` row

#### Scenario: Enter on a nest parent opens the file
- **WHEN** the cursor is on the collapsed `invoice.go` row and `<CR>` is pressed
- **THEN** the window right of the tree edits `internal/billing/invoice.go`, and the `invoice.go` nest is still collapsed

#### Scenario: Fold all and unfold all include nests
- **WHEN** `zR` is pressed in the tree on the `treeproj` fixture, then `zM`
- **THEN** after `zR` the rows include `discount_test.go`, `invoice_test.go`, `tax_test.go`, `money_test.go`, `price.test.ts`, `price.d.ts`, `package-lock.json` and `go.sum`, each under its parent; after `zM` none of them is listed

#### Scenario: Followed nested file expands its nest
- **WHEN** the tree is open on the `treeproj` fixture with every nest collapsed and `:edit internal/billing/invoice_test.go` runs in the editor window
- **THEN** the `invoice.go` nest is expanded and the tree cursor is on the `invoice_test.go` row

#### Scenario: Added nested file is revealed in its nest
- **WHEN** the cursor is on the collapsed `invoice.go` row and `file_tree.add` creates `invoice_mock.go`
- **THEN** the `invoice.go` nest is expanded, it lists `invoice_mock.go` and `invoice_test.go` in that order, and the cursor is on `invoice_mock.go`

#### Scenario: Renamed file is revealed in a collapsed nest
- **WHEN** the `invoice.go` nest is collapsed and `r` renames `notes.go` to `invoice_mock.go`
- **THEN** the `invoice.go` nest is expanded and the cursor is on `invoice_mock.go`

#### Scenario: Pasted file is revealed in a collapsed nest
- **WHEN** the `invoice.go` nest is collapsed and `p` pastes a copied `invoice_mock.go` into `internal/billing`
- **THEN** the `invoice.go` nest is expanded and the cursor is on `invoice_mock.go`

#### Scenario: Visual delete on a collapsed parent deletes only the parent
- **WHEN** the `discount.go` nest is collapsed, Visual `d` selects only its parent row, and the delete is confirmed
- **THEN** `discount.go` is deleted, `discount_test.go` still exists, and `discount_test.go` is listed as a plain row

#### Scenario: Following under a symlinked root expands the nest
- **WHEN** the tree root normalizes from `/var` to `/private/var`, every nest is collapsed, and the editor opens `internal/billing/invoice_test.go` through the `/var` spelling
- **THEN** the `invoice.go` nest is expanded and the tree cursor is on `invoice_test.go`

#### Scenario: Deleting a nest parent keeps its children
- **WHEN** the cursor is on the `discount.go` row and `file_tree.delete` deletes it after confirmation
- **THEN** `internal/billing/discount_test.go` still exists and is listed as a plain row of `internal/billing` without a chevron

### Requirement: File tree nest git tint
A parent file without its own git status SHALL show its name in the status its children give it, by the folder tint rule of the file tree. A parent's own status SHALL win. The tint SHALL be the same whether the nest is collapsed or expanded.

#### Scenario: Collapsed nest parent shows a changed child
- **WHEN** in a copy of the `treeproj` fixture a line is appended to `internal/billing/discount_test.go`, `discount.go` is unchanged, and the tree shows `internal/billing` with the `discount.go` nest collapsed
- **THEN** the `discount.go` name is drawn with `FileTreeGitModified`

#### Scenario: Nest parent keeps its own status
- **WHEN** in a copy of the `treeproj` fixture `git commit -m test -- internal/billing/tax_test.go` runs and a line is then appended to `tax_test.go`, so `tax.go` is added and `tax_test.go` is modified, and the tree shows `internal/billing`
- **THEN** the `tax.go` name is drawn with `FileTreeGitAdded`, not the modified tint its child would give, and once its nest is expanded `tax_test.go` is drawn with `FileTreeGitModified`

#### Scenario: Deleted unlisted child does not tint its parent
- **WHEN** a tracked nested child is deleted so git reports it but the child is absent from the folder listing, and its unchanged parent nest is collapsed
- **THEN** the parent name has no git-status highlight from that deleted child

### Requirement: File tree nesting screen
With the default rules, the tree SHALL look like the approved render.

#### Scenario: File tree nests match the approved render
- **WHEN** the editor is 100x30, a copy of the `treeproj` fixture without its ignored entries is on branch `feat/tax` with design.md Decision 8's git state, `file_tree.toggle` opens the tree, `cmd/server`, `internal/billing` and `web/src` are expanded, the `invoice.go` nest is expanded, the tree cursor is on `invoice.go`, and the right window edits `internal/billing/invoice.go` at line 17
- **THEN** the screen matches the approved render "Proposed — nests under a chevron"

### Requirement: File tree ignored entries
An entry SHALL be ignored when porcelain-v2 marks it `!`, its parent is ignored, or it matches `settings/file_tree.json` `ignore`: patterns without `/` by name at any depth and patterns with `/` from the tree root. Tracked files, the tree root and its ancestors SHALL not be ignored. With Show Ignored off, ignored entries SHALL be removed before nesting with no hint. `.git` SHALL never be listed.

#### Scenario: Ignored entries are hidden by default
- **WHEN** `file_tree.toggle` opens the tree on the `treeproj` fixture with no saved state, and `web` is expanded
- **THEN** no row is `bin`, `node_modules`, `.env` or `.git`, the direct children of `web` are listed as exactly `src` and `package.json`, and no row mentions hidden or ignored entries

#### Scenario: Tracked files matching gitignore stay listed
- **WHEN** in a copy of the `treeproj` fixture `internal/billing/audit.log` is created and added with `git add -f`, `internal/billing/debug.log` is created untracked, and the tree shows `internal/billing`
- **THEN** `audit.log` is listed with the `FileTreeFileName` group, not `FileTreeIgnored`, and `debug.log` is not listed

#### Scenario: Settings ignore patterns hide entries
- **WHEN** the settings file sets `"ignore": ["*.swp", "web/src/*.d.ts"]`, `notes.md.swp` and `cmd/server/main.go.swp` exist in a copy of the `treeproj` fixture, the tree shows `cmd/server` and `web/src`, and the `price.ts` nest is expanded
- **THEN** neither `.swp` file is listed, `price.d.ts` is not listed, and the `price.ts` nest lists only `price.test.ts`

#### Scenario: Ignored nest children leave no chevron
- **WHEN** the settings file sets `"ignore": ["package-lock.json"]` and the tree shows `web`
- **THEN** `package.json` is listed without a chevron and `package-lock.json` is not listed

#### Scenario: Editing gitignore updates ignored entries
- **WHEN** the tree shows the `treeproj` fixture with its cursor on `notes.md`, the line `notes.md` is appended to `.gitignore` in a buffer, and `:write` is run
- **THEN** within 2 s `notes.md` is no longer listed and the tree cursor is on `Makefile`, the nearest listed row above

#### Scenario: Hidden ignored file is not revealed
- **WHEN** Show Ignored is off, the tree cursor is on `invoice.go`, and `:edit .env` runs in the editor window
- **THEN** the tree rows are unchanged and the tree cursor is still on `invoice.go`

#### Scenario: Ignore patterns apply outside a git repository
- **WHEN** the tree opens on a temporary folder that is not inside a git repository, holding `main.go` and `scratch.swp`, with the settings file setting `"ignore": ["*.swp"]`
- **THEN** `main.go` is listed, `scratch.swp` is not, no `git ls-files` command is spawned, and no notification is shown

#### Scenario: Nested gitignore and negation are honoured
- **WHEN** a copy of `treeproj` has `web/.gitignore` containing `generated/*` and `!generated/keep.ts`, both `web/generated/drop.ts` and `web/generated/keep.ts` exist untracked, and the tree shows `web/generated`
- **THEN** `keep.ts` is listed and `drop.ts` is not listed

#### Scenario: Tree root inside an ignored folder stays visible
- **WHEN** the tree root is `web/node_modules/left-pad` in a copy of the `treeproj` fixture
- **THEN** the root row and `index.js` are listed and neither is marked ignored

#### Scenario: Folder with only ignored content stays listed
- **WHEN** a copy of `treeproj` has an untracked `generated` folder containing only `debug.log`, and the root row is expanded
- **THEN** `generated` is listed, expanding it lists no child, and `generated` is not marked ignored

#### Scenario: Ignored sets follow normalized roots across tabs
- **WHEN** two tabs show the same repository through a symlink-normalized `/private/var` path, one rooted at the repository and one at `web/`, with Show Ignored off
- **THEN** both tabs hide their ignored entries and the `web/` tab hides `node_modules`

### Requirement: File tree hidden-path gate
A hidden ignored target SHALL not expand folders or nests, write `expanded.json`, or move the tree cursor when reached by follow, reveal, create selection or move refresh. Ignoring SHALL win over nest reveal. If refresh or toggling removes the selected row, the cursor SHALL move to the nearest listed row above.

#### Scenario: File under hidden node_modules is not revealed
- **WHEN** Show Ignored is off, the tree cursor is on `web/src/cart.tsx`, and `:edit web/node_modules/left-pad/index.js` runs in the editor window
- **THEN** no folder or nest expands, `expanded.json` is unchanged, and the tree cursor stays on `cart.tsx`

#### Scenario: Created or renamed ignored target is not selected
- **WHEN** Show Ignored is off and file-tree create or rename completes at `web/node_modules/left-pad/new.js`
- **THEN** `select_created` or `refresh_moved` does not expand `web/node_modules`, persist expansion, or select the hidden target; if the selected rename source vanishes, the cursor moves to the nearest listed row above

### Requirement: File tree Show Ignored action
The toggle action `file_tree.show_ignored` (title "Show Ignored", category Project, filetype `gleb-file-tree`) SHALL show or hide ignored entries in every open tree. It SHALL be bound to `I` through `settings/keymap.json` and listed in Find Action with its state. Its state SHALL persist as `show_ignored` in `stdpath("state")/file_tree/view.json` and be read when a tree opens. The default SHALL be off.

#### Scenario: I toggles ignored entries
- **WHEN** the tree shows the `treeproj` fixture with `web` expanded, and `I` is pressed twice
- **THEN** after the first press `bin` is listed between `.github/workflows` and `cmd/server`, `node_modules` before `src` under `web`, and `.env` before `.gitignore`; after the second press none of them is listed

#### Scenario: Show Ignored is a Find Action toggle
- **WHEN** `<M-A>` opens Find Action from the tree window, `Show Ignored` is typed, and Enter is pressed
- **THEN** the row shows the on glyph `●`, the palette stays open, and after it is closed the tree lists `bin`, `node_modules` and `.env`

#### Scenario: Show Ignored persists
- **WHEN** `I` is pressed in the tree, the tree is closed with `q`, and `file_tree.toggle` opens it again
- **THEN** `bin` is listed, and `stdpath("state") .. "/file_tree/view.json"` decodes to a table with `show_ignored = true`

#### Scenario: Saved Show Ignored state is restored
- **WHEN** `stdpath("state") .. "/file_tree/view.json"` holds `{"show_ignored":true}` before `file_tree.toggle` first opens the tree on the `treeproj` fixture
- **THEN** `bin` and `.env` are listed

#### Scenario: Hiding the selected ignored row moves upward
- **WHEN** Show Ignored is on, the tree cursor is on `node_modules`, and `I` is pressed
- **THEN** ignored rows disappear and the cursor moves to the nearest listed row above the former `node_modules` row

### Requirement: File tree ignored look
A shown ignored entry SHALL draw its name and its file or folder icon with `FileTreeIgnored`, defined from the palette as grey0 italic. Its expander SHALL keep `FileTreeExpander`. An ignored entry SHALL get no git colour and SHALL never tint its folder.

#### Scenario: Ignored rows are grey italic
- **WHEN** `I` is pressed in the tree on the `treeproj` fixture
- **THEN** the icon and name cells of the `bin`, `node_modules` and `.env` rows are drawn with `FileTreeIgnored`, and `FileTreeIgnored` has the palette's grey0 foreground and `italic = true`

#### Scenario: Settings-ignored entries do not tint folders or nests
- **WHEN** settings ignore an untracked `cmd/server/main.go.swp` and an untracked `cmd/server/main_mock.go`, and the tree shows `cmd/server` before and after Show Ignored is enabled
- **THEN** `cmd/server` and the `main.go` nest parent are not drawn with `FileTreeGitUntracked`

### Requirement: File tree ignored folders
The tree SHALL never scan or watch an ignored folder until the user expands it. `file_tree.unfold_all` SHALL leave ignored folders collapsed. Expanded children SHALL inherit ignored state without another git request. Filtering SHALL precede nesting; compaction SHALL not enter or cross an ignored folder. Row limits SHALL count listed rows only.

#### Scenario: Unfold all leaves ignored folders collapsed
- **WHEN** `I` is pressed in the tree on the `treeproj` fixture, then `zR`
- **THEN** `bin` and `node_modules` show the collapsed expander, and neither `server` nor `left-pad` is listed

#### Scenario: Expanded ignored folder lists ignored children
- **WHEN** Show Ignored is on, `vim.system` calls are recorded, and `za` is pressed on the `bin` row
- **THEN** `server` is listed under `bin` with its name drawn in `FileTreeIgnored`, and no recorded call during the expansion runs `git`

#### Scenario: Ignored folders do not compact or consume unfold budget
- **WHEN** Show Ignored is on, `web/node_modules` is collapsed, and `file_tree.unfold_all` runs near its row limit
- **THEN** the listed row is `node_modules`, not `node_modules/left-pad`, it stays collapsed, and its hidden descendants do not count toward the row limit

### Requirement: File tree first paint
For a git-backed tree whose watcher has established `toplevel`, the first status request SHALL skip debounce and drawing SHALL wait for its result or 300 ms, whichever comes first. Later refreshes and trees outside git SHALL not wait.

#### Scenario: First paint waits for ignored status
- **WHEN** a git-backed `treeproj` tree opens with status completing within 300 ms
- **THEN** its first drawn frame omits `bin`, `web/node_modules` and `.env`

### Requirement: File tree ignored screen
After Show Ignored, the tree SHALL look like the approved render.

#### Scenario: Show Ignored matches the approved render
- **WHEN** the editor is 100x30 and the tree is in the state of `file-tree: File tree nests match the approved render`, with `web` and `web/src` expanded, and `I` is pressed
- **THEN** the screen matches the approved render "Proposed — after Show Ignored"

### Requirement: Shared porcelain status records
`gleb.git.status.parse_records(z)` SHALL parse every porcelain-v2 NUL record once into ordered `{ kind, xy, sub, path, orig }` values. A `2` record SHALL consume its following original-path field. `gleb.git.status.parse(z, prefix)` and the ignored-path set SHALL remain wrappers over those records, and the Changes panel SHALL consume only those records.

#### Scenario: Shared parser preserves rename and copy origins
- **WHEN** `gleb.git.status.parse_records` receives NUL-delimited `2` records for a rename and a copy
- **THEN** each result has kind `2`, its XY and submodule fields, the destination in `path`, and the following NUL field in `orig`

#### Scenario: Shared parser classifies added and unmerged records
- **WHEN** `gleb.git.status.parse` receives an ordinary `.A` record and a `u` record
- **THEN** the ordinary path is `added`, the unmerged path is `conflict`, and neither record is ignored

#### Scenario: Shared parser keeps ignored records separate
- **WHEN** `gleb.git.status.parse` receives a modified tracked record, an untracked record and an ignored record
- **THEN** the status map contains the modified and untracked paths while the ignored set alone contains the ignored path

### Requirement: Project tree opens for a directory buffer
With no project tree open, editing a directory SHALL open and focus the sidebar rooted there, replace the directory buffer's window with an empty buffer and wipe the directory buffer. With a tree already open, entering a directory buffer SHALL focus that tree without changing its root or cursor. netrw SHALL not load.

#### Scenario: Directory argument opens the project tree
- **WHEN** `:edit <dir>` runs for a directory `docs` that contains `workflow.md`
- **THEN** the current window has filetype `gleb-file-tree`, its root row names `docs` and a `workflow.md` row follows, no window shows a buffer named `<dir>`, and no buffer has filetype `netrw`

#### Scenario: netrw is not loaded
- **WHEN** Neovim starts with the full config and `VeryLazy` has fired
- **THEN** `:Explore` is not a command (`vim.fn.exists(":Explore") == 0`) and `lazy.nvim`'s `performance.rtp.disabled_plugins` contains `netrwPlugin`

#### Scenario: Directory buffer focuses an open project tree
- **WHEN** the project tree rooted at a copy of `treeproj` has its cursor on `go.mod` and `:edit internal` runs in its editor window
- **THEN** the existing project tree is current, its root is still `treeproj`, its cursor is still on `go.mod`, and no directory buffer remains

#### Scenario: Directory buffer entered from project tree focuses it
- **WHEN** the project tree rooted at a copy of `treeproj` has its cursor on `go.mod` and `:edit internal` runs in the project-tree window
- **THEN** the existing project tree is current with the same root and cursor, the editor still shows its previous file, and no directory buffer remains

#### Scenario: Directory buffer replaces an open changes panel
- **WHEN** the changes panel is open beside an editor and `:edit internal` runs in the editor
- **THEN** no changes-panel or diff-view window remains and the focused project tree is rooted at `internal`

### Requirement: Project tree sidebar
The action `file_tree.toggle` SHALL open the project tree for the cwd in a left-docked window 35 columns wide with `winfixwidth`, filetype `gleb-file-tree` and a `nofile` buffer, at most one per tab page, reveal the current file, and focus it. When current it SHALL close; when open but unfocused it SHALL focus. Closing the last other non-floating window SHALL close the tree first.

#### Scenario: Project tree opens on the left at width 35
- **WHEN** the action `file_tree.toggle` runs in a tab with one file window
- **THEN** the current window has filetype `gleb-file-tree`, is the leftmost window of the tab, has width 35 and `winfixwidth` set, and the tab has two windows

#### Scenario: Project tree toggle closes a focused tree
- **WHEN** the project tree is the current window and the action `file_tree.toggle` runs
- **THEN** no window with filetype `gleb-file-tree` remains in the tab

#### Scenario: Project tree toggle focuses an open tree
- **WHEN** the project tree is open, `:wincmd l` has moved focus to the file window, and the action `file_tree.toggle` runs
- **THEN** the current window is the project tree and the tab still has two windows

#### Scenario: Project tree closes with the last window
- **WHEN** the project tree is open next to one file window and that file window is closed with `:q`
- **THEN** Neovim exits

#### Scenario: Project tree toggle reveals the current file
- **WHEN** no project tree is open, the current buffer is `internal/money/money.go` and the action `file_tree.toggle` runs
- **THEN** the current window is the project tree and its cursor is on the `money.go` row

#### Scenario: Project tree opens from non-project buffers
- **WHEN** no project tree is open and `file_tree.toggle` runs from either a file outside the cwd or a terminal buffer
- **THEN** the project tree draws its root row and top-level rows

### Requirement: Project tree and changes panel close-if-last isolation
QuitPre SHALL count project-tree and changes-panel windows as sidebars. Closing the last editor window with `:q` or `:close` SHALL close sidebars first without clearing another tab's state or autocmds. A tab containing both sidebar types SHALL still quit as if neither were present.

#### Scenario: Project tree closes before last editor with close
- **WHEN** the project tree is open next to one file window and that file window is closed with `:close`
- **THEN** the tab page closes without an error or a remaining project-tree window

#### Scenario: Project tree and changes panel close before the last editor
- **WHEN** project tree and changes panel windows are open next to one file window and that file window is closed with `:q`
- **THEN** both sidebar windows close first and Neovim exits

### Requirement: Project tree bounded redraw work
Project-tree row construction, expansion and drawing SHALL remain responsive at the 5000-row safety limit. Timing bounds SHALL be multiplied by the host load factor. A draw SHALL consume one prepared row set, and a manual expansion SHALL replace the tree buffer at most once.

#### Scenario: Project tree redraw meets the large-tree bound
- **WHEN** `require("gleb.file_tree.view").redraw_all()` runs after one warm-up with 5000 visible rows in a generated fixture
- **THEN** it finishes within 100 ms multiplied by the host load factor, preserves the same rows and selection, and replaces the tree buffer once

#### Scenario: Project tree expansion meets the large-tree bound
- **WHEN** the tree has 4900 visible rows and `<CR>` is pressed in normal mode on a collapsed folder whose children keep the result within the 5000-row limit
- **THEN** the expanded rows appear within 100 ms multiplied by the host load factor and the tree buffer is replaced once

### Requirement: Project tree coalesces refresh work
Each project-tree view SHALL coalesce watcher, write, follow and git invalidations arriving within 50 ms into one scheduled draw and one git-status request. A completed git request whose status and ignored maps equal the current maps SHALL not redraw. Existing live-update deadlines SHALL still apply.

#### Scenario: Project tree coalesces a save burst
- **WHEN** the tree is settled and one file write triggers `BufWritePost`, a filesystem watch event and a git result within 50 ms
- **THEN** within 1000 ms the changed row is current, the tree buffer was replaced once, and one new git-status command ran

#### Scenario: Unchanged git status does not redraw the project tree
- **WHEN** the settled tree refreshes git status and the returned status and ignored maps equal its current maps
- **THEN** no tree-buffer replacement occurs

#### Scenario: Project tree save leaves the main path promptly
- **WHEN** `:write` saves a changed listed file while a 5000-row tree is open
- **THEN** the command returns within 100 ms multiplied by the host load factor and the row reaches its final git colour within 1000 ms

#### Scenario: Project tree refresh survives initial git completion
- **WHEN** `:write` runs after repository discovery but before the first git result, then a file is created outside Neovim
- **THEN** within 1000 ms the created file is listed

#### Scenario: Project tree refresh survives failed git status
- **WHEN** `:write` runs after the open repository's `.git` directory is removed, then a file is created outside Neovim
- **THEN** within 1000 ms the created file is listed

### Requirement: Project tree follows listed rows without redraw
Entering a file that already has a visible row SHALL move the tree cursor to that row without rebuilding or replacing the tree buffer. The `BufEnter` processing bound SHALL be 50 ms multiplied by the host load factor.

#### Scenario: Project tree follows an already listed row promptly
- **WHEN** a 5000-row tree is settled and `:edit` enters another file whose row is already visible
- **THEN** within 50 ms multiplied by the host load factor the tree cursor is on that row, focus remains in the editor, and the tree buffer was not replaced

### Requirement: Project tree defers maintenance work
Repository discovery, watch-handle reconciliation and expansion-state persistence SHALL not synchronously delay tree actions. Re-root and fold actions SHALL return within 100 ms multiplied by the host load factor, while their observable state SHALL settle within existing live-update deadlines.

#### Scenario: Project tree re-roots without waiting for repository discovery
- **WHEN** a 5000-row project tree is open and global `DirChanged` changes cwd to another generated git worktree
- **THEN** `DirChanged` returns within 100 ms multiplied by the host load factor and within 1000 ms the tree shows the new root and watches its git directory

#### Scenario: Project tree persists folds off the action path
- **WHEN** a 5000-row tree is open and `za` is pressed in normal mode on a folder
- **THEN** the action returns within 100 ms multiplied by the host load factor and within 1000 ms `expanded.json` contains the resulting valid expansion state

#### Scenario: Project tree persists a last-moment fold on exit
- **WHEN** `za` changes a folder and Neovim quits before the 500 ms persistence debounce expires
- **THEN** restarting Neovim restores the changed expansion state

#### Scenario: Project tree opens once with saved expansion
- **WHEN** the project tree opens with a saved non-empty expansion state
- **THEN** the first tree-buffer replacement includes that expansion state and the open replaces the buffer exactly once

#### Scenario: Project tree re-roots once with saved expansion
- **WHEN** global `DirChanged` re-roots an open project tree to a root with saved non-empty expansion state
- **THEN** the first tree-buffer replacement includes that expansion state and the re-root replaces the buffer exactly once

### Requirement: Project tree unfolds in linear time
`file_tree.unfold_all` SHALL discover folders and count visible rows in one traversal, preserve ignored-folder and nesting behavior, and build the final rows once. Its bound SHALL be 500 ms multiplied by the host load factor for a generated fixture that reaches the 5000-row safety limit.

#### Scenario: Project tree unfold all meets the large-tree bound
- **WHEN** only the root is expanded in a generated fixture with 60 folders of 100 files and `zR` is pressed in normal mode
- **THEN** within 500 ms multiplied by the host load factor the tree has at most 5001 rows and emits the WARN notification `Unfold all stopped at 5000 rows`

#### Scenario: Project tree unfold all preserves skipped expansion state
- **WHEN** Show Ignored is on, an ignored folder is expanded with `<CR>`, and `zR` is pressed in normal mode
- **THEN** the ignored folder remains expanded and its child remains listed
