# Spec Delta

## ADDED Requirements

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

### Requirement: Project tree unfolds in linear time
`file_tree.unfold_all` SHALL discover folders and count visible rows in one traversal, preserve ignored-folder and nesting behavior, and build the final rows once. Its bound SHALL be 500 ms multiplied by the host load factor for a generated fixture that reaches the 5000-row safety limit.

#### Scenario: Project tree unfold all meets the large-tree bound
- **WHEN** only the root is expanded in a generated fixture with 60 folders of 100 files and `zR` is pressed in normal mode
- **THEN** within 500 ms multiplied by the host load factor the tree has at most 5001 rows and emits the WARN notification `Unfold all stopped at 5000 rows`
