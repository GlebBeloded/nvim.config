## MODIFIED Requirements

### Requirement: Project tree live updates
The tree SHALL cache scans and watch every folder whose scan feeds a row, every expanded folder, and the repository git dir. Changes during watch startup or restart SHALL remain covered until the event stream is confirmed live. Unwatched listed directories SHALL be polled after a safety cap or start failure. A filesystem change SHALL redraw within 1000 ms and rerun relevant git status. Handles and fallback work SHALL stop when unused. Global `DirChanged` SHALL re-root the current tab's tree.

#### Scenario: Project tree shows files created outside Neovim
- **WHEN** the project tree shows the expanded `internal/billing` folder and `touch internal/billing/fee.go` runs as an external process
- **THEN** within 1000 ms a `fee.go` row exists, drawn with `FileTreeGitUntracked`

#### Scenario: Project tree recolours a written file
- **WHEN** `internal/billing/discount.go` is edited and written with `:write` while the tree shows it
- **THEN** within 1000 ms its row is drawn with `FileTreeGitModified`

#### Scenario: Project tree recolours after staging outside Neovim
- **WHEN** the project tree shows `notes.md` and `git add notes.md` runs as an external process
- **THEN** within 1000 ms `notes.md` is drawn with `FileTreeGitAdded`

#### Scenario: Project tree recolours staging during watch startup
- **WHEN** the project tree shows untracked `notes.md`, no watch event has confirmed the started git dir watch, that watch delivers no event, and `git add notes.md` runs as an external process
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
