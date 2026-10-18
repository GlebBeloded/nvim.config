## ADDED Requirements

### Requirement: Project tree window
The action `file_tree.toggle` SHALL open the project tree for the cwd in a left-docked window 35 columns wide with `winfixwidth`, filetype `gleb-file-tree` and a `nofile` buffer, at most one per tab page, reveal the current file, and focus it. When the tree is current it SHALL close it; when open but unfocused it SHALL focus it. Closing the last other non-floating window SHALL close the tree first, so `:q` behaves as without a tree.

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

#### Scenario: Project tree actions start unbound
- **WHEN** `settings/keymap.json` is read and the normal-mode mapping of `<A-e>` is inspected
- **THEN** it has no entry for `file_tree.toggle` or `file_tree.reveal`, and `<A-e>` still runs `tree.toggle_filesystem`

#### Scenario: Project tree toggle reveals the current file
- **WHEN** no project tree is open, the current buffer is `internal/money/money.go` and the action `file_tree.toggle` runs
- **THEN** the current window is the project tree and its cursor is on the `money.go` row

#### Scenario: Project tree opens from non-project buffers
- **WHEN** no project tree is open and `file_tree.toggle` runs from either a file outside the cwd or a terminal buffer
- **THEN** the project tree draws its root row and top-level rows

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
File-opening actions SHALL run from the target editor window, never the tree, and skip neo-tree, quickfix, terminal, floating and diff-view windows. If a file replaces the tree buffer, it SHALL move to an eligible editor window. New split and tab windows SHALL inherit editor options, not tree-only options.

#### Scenario: Project tree opening skips non-editor windows
- **WHEN** neo-tree, quickfix, terminal, floating and diff-view windows are present, the project tree is focused on `Makefile`, and `<CR>` is pressed in normal mode
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

### Requirement: Project tree close-if-last isolation
QuitPre SHALL count both project-tree and neo-tree windows as trees. Closing the last editor window with `:q` or `:close` SHALL close tree windows first without clearing another tab's state or autocmds. A tab containing both tree types SHALL still quit as if neither tree were present.

#### Scenario: Project tree closes before last editor with close
- **WHEN** the project tree is open next to one file window and that file window is closed with `:close`
- **THEN** the tab page closes without an error or a remaining project-tree window

#### Scenario: Project and neo-tree close before the last editor
- **WHEN** project tree and neo-tree windows are open next to one file window and that file window is closed with `:q`
- **THEN** both tree windows close first and Neovim exits

### Requirement: Project tree folds
In the tree, `file_tree.toggle_fold` SHALL toggle a folder row and, on a file row, collapse its folder and move the cursor to it. `file_tree.fold_all` SHALL collapse every folder and put the cursor on the top-level row that contained the selection. `file_tree.unfold_all` SHALL expand every folder below the root, stopping after 5000 rows with the WARN notification `Unfold all stopped at 5000 rows`.

#### Scenario: Project tree za on a file collapses its folder
- **WHEN** `internal` and `billing` are expanded, the cursor is on the `tax.go` row and `za` is pressed in normal mode
- **THEN** the cursor is on the `billing` row and no `tax.go` row remains

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
The tree SHALL read status asynchronously with `git --no-optional-locks -C <root> status --porcelain=v2 -z --untracked-files=normal` and colour names: `FileTreeGitModified`, `FileTreeGitAdded` (index `A`), `FileTreeGitUntracked`, `FileTreeGitRenamed`, `FileTreeGitConflict`. A folder SHALL take the strongest status below it: conflict, modified (incl. renamed, deleted), added, untracked. Outside a repository it SHALL draw no git colours and notify nothing.

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
- **THEN** `require("gleb.file_tree.git").state.last_cmd` equals `{ "git", "--no-optional-locks", "-C", <root>, "status", "--porcelain=v2", "-z", "--untracked-files=normal" }`

#### Scenario: Project tree outside a repository has no git colours
- **WHEN** the project tree opens in a temp directory outside any git repository that holds `a.txt`
- **THEN** `a.txt` is drawn with `FileTreeFileName` and no notification is emitted

#### Scenario: Project tree runs git status once per burst
- **WHEN** the project tree is open and 20 files are written into the root within 50 ms
- **THEN** after 1000 ms all 20 rows exist and `require("gleb.file_tree.git").state.runs` grew by at most 2

### Requirement: Project tree follows the current file
While the tree is open in a tab, entering a buffer whose file lies under the root SHALL expand its folders and put the tree cursor on its row without moving focus. The action `file_tree.reveal` SHALL open the tree if needed, reveal the current buffer's file the same way and focus the tree; a buffer that is no file on disk SHALL leave the cursor on the root row. Files outside the root and `scheme://` buffers SHALL be ignored.

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
- **THEN** the tree cursor stays on `go.mod` and no error or notification is raised

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
The tree SHALL cache scans and watch every folder whose scan feeds a row, every expanded folder, and the repository git dir. A watch event SHALL invalidate the affected cache, redraw within 1000 ms, and rerun git status when relevant. Handles SHALL stop when no tree for their root needs them. Global `DirChanged` SHALL re-root the current tab's tree.

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
