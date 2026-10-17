## ADDED Requirements

### Requirement: Project tree window
The action `file_tree.toggle` SHALL open the project tree for the cwd in a left-docked window 35 columns wide with `winfixwidth`, filetype `gleb-file-tree` and a `nofile` buffer, at most one per tab page, and focus it. When the tree is the current window it SHALL close it. When the tree is open but not focused it SHALL focus it. Closing the last other non-floating window SHALL close the tree first, so `:q` behaves as without a tree.

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

### Requirement: Project tree live updates
The tree SHALL watch the root, every expanded folder and the repository's git dir with libuv `fs_event` handles, rescan and redraw a changed folder within 1000 ms, and rerun git status after watched changes, `BufWritePost` under the root and `FocusGained`. Handles SHALL stop when their folder collapses and when the last tree window for the root closes. On a global `DirChanged` the tree SHALL re-root to the new cwd.

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

### Requirement: Project tree remembers expanded folders
The tree SHALL store the relative paths of the expanded folders per root in `stdpath("state")/file_tree/expanded.json` whenever they change, and SHALL restore them when the tree opens for that root. A stored folder that no longer exists SHALL be dropped. A root without stored state SHALL start with only the root expanded.

#### Scenario: Project tree expanded folders persist per root
- **WHEN** `web` and `src` are expanded, the tree is closed, `require("gleb.file_tree.expanded").reset()` clears the in-memory state, and the action `file_tree.toggle` runs again
- **THEN** the `price.ts` row is shown and `expanded.json` maps the root to a list containing `web` and `web/src`

#### Scenario: Project tree drops a stored folder that is gone
- **WHEN** `expanded.json` lists `web/src` for the root, `web/src` is deleted from disk and the tree opens
- **THEN** no error is raised and `expanded.json` no longer lists `web/src` for the root

### Requirement: Project tree keys
The project tree actions SHALL be registered in `file_tree/actions.lua` with category `Project`; `file_tree.toggle` and `file_tree.reveal` without a filetype, the others scoped to filetype `gleb-file-tree`. Their keys SHALL come only from `settings/keymap.json`: `open` `<CR>` `o` `l`, `close_node` `h` `<BS>`, `open_split` `s`, `open_vsplit` `v`, `open_tab` `t`, `close` `q`, `toggle_fold` `za`, `fold_all` `zM`, `unfold_all` `zR`.

#### Scenario: Project tree keys come from the keymap file
- **WHEN** the project tree buffer is current and its buffer-local normal-mode mappings are read with `nvim_buf_get_keymap(0, "n")`
- **THEN** each lhs listed for a `file_tree.*` action in `settings/keymap.json` is mapped, and its `desc` is `Project: <action title>`

### Requirement: Project tree look
The tree SHALL draw its rows with the groups `FileTreeNormal`, `FileTreeRoot`, `FileTreeRootPath`, `FileTreeExpander`, `FileTreeFolderIcon`, `FileTreeFolderName`, `FileTreeFileName`, the `FileTreeGit*` groups, `FileTreeCursorLine` and the devicon groups, with colours from the gruvbox-material palette helpers redefined on `ColorScheme`, and SHALL hide the cursor while the tree is focused.

#### Scenario: Project tree highlight colours come from the palette
- **WHEN** the config has loaded with the gruvbox-material colorscheme
- **THEN** `FileTreeGitModified` fg is `#7daea3`, `FileTreeGitAdded` `#a9b665`, `FileTreeGitUntracked` `#e78a4e`, `FileTreeGitRenamed` `#89b482`, `FileTreeGitConflict` `#ea6962`, `FileTreeRoot` `#ddc7a1` bold, `FileTreeRootPath` `#928374`, and `FileTreeCursorLine` bg `#32302f`

#### Scenario: Project tree matches the approved render
- **WHEN** `HOME` is a temp dir, a copy of the `treeproj` fixture without its ignored entries is the cwd at `~/work/billing`, no nesting rules apply, `internal/billing/invoice.go` is open on a `100x30` screen without LSP or diagnostics, the action `file_tree.toggle` runs, `<CR>` is pressed on the `cmd/server`, `web` and `src` rows, and the cursor returns to the `invoice.go` row
- **THEN** the screen matches the approved render "Proposed F1 — project tree" (design.md) in text and in the colours of the tree window
