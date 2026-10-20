# Spec Delta

## MODIFIED Requirements

### Requirement: Project tree bounded redraw work
Project-tree row construction, expansion and drawing SHALL remain responsive at the 5000-row safety limit. The 100 ms bounds SHALL be checked with process CPU time in parallel and load-scaled wall time in the serial performance layer. A draw SHALL consume one prepared row set, and a manual expansion SHALL replace the tree buffer at most once.

#### Scenario: Project tree redraw meets the large-tree bound
- **WHEN** `require("gleb.file_tree.view").redraw_all()` runs after one warm-up with 5000 visible rows in a generated fixture
- **THEN** it consumes at most 100 ms of process CPU time, finishes within 100 ms multiplied by the host load factor in the serial performance layer, preserves the same rows and selection, and replaces the tree buffer once

#### Scenario: Project tree expansion meets the large-tree bound
- **WHEN** the tree has 4900 visible rows and `<CR>` is pressed in normal mode on a collapsed folder whose children keep the result within the 5000-row limit
- **THEN** the expanded rows consume at most 100 ms of process CPU time, appear within 100 ms multiplied by the host load factor in the serial performance layer, and the tree buffer is replaced once

### Requirement: Project tree coalesces refresh work
Each project-tree view SHALL coalesce watcher, write, follow and git invalidations arriving within 50 ms into one scheduled draw and one git-status request. A completed git request whose status and ignored maps equal the current maps SHALL not redraw. Existing live-update deadlines SHALL still apply, and the debounce interval SHALL be manually advanceable in tests.

#### Scenario: Project tree coalesces a save burst
- **WHEN** the tree is settled, one file write triggers `BufWritePost`, a filesystem watch event and a git result, and the debounce interval advances by 50 ms
- **THEN** the changed row is current, the tree buffer was replaced once, and one new git-status command ran

#### Scenario: Project tree save burst observes both debounce deadlines
- **WHEN** a settled tree processes a real write while the watcher debounce advances by 149 ms then 1 ms and the resulting draw debounce advances by 49 ms then 1 ms
- **THEN** no git request runs before 150 ms, no tree-buffer replacement occurs before the final 50 ms, and then one new git request and one replacement occur

#### Scenario: Unchanged git status does not redraw the project tree
- **WHEN** the settled tree refreshes git status and the returned status and ignored maps equal its current maps
- **THEN** no tree-buffer replacement occurs

#### Scenario: Project tree save leaves the main path promptly
- **WHEN** `:write` saves a changed listed file while a 5000-row tree is open
- **THEN** the command consumes at most 100 ms of process CPU time, returns within 100 ms multiplied by the host load factor in the serial performance layer, and the row reaches its final git colour within 1000 ms

#### Scenario: Project tree refresh survives initial git completion
- **WHEN** `:write` runs after repository discovery but before the first git result, then a file is created outside Neovim
- **THEN** within 1000 ms the created file is listed

#### Scenario: Project tree refresh survives failed git status
- **WHEN** `:write` runs after the open repository's `.git` directory is removed, then a file is created outside Neovim
- **THEN** within 1000 ms the created file is listed

### Requirement: Project tree follows listed rows without redraw
Entering a file that already has a visible row SHALL move the tree cursor to that row without rebuilding or replacing the tree buffer. The `BufEnter` processing bound SHALL be 50 ms of process CPU time in parallel and 50 ms multiplied by the host load factor in the serial performance layer.

#### Scenario: Project tree follows an already listed row promptly
- **WHEN** a 5000-row tree is settled and `:edit` enters another file whose row is already visible
- **THEN** the operation consumes at most 50 ms of process CPU time, finishes within 50 ms multiplied by the host load factor in the serial performance layer, leaves the tree cursor on that row and focus in the editor, and does not replace the tree buffer

### Requirement: Project tree defers maintenance work
Repository discovery, watch-handle reconciliation and expansion-state persistence SHALL not synchronously delay tree actions. Re-root SHALL leave repository discovery pending when it returns. Re-root and fold SHALL consume at most 100 ms of process CPU time and meet the load-scaled 100 ms wall-time bound in the serial performance layer. Observable state SHALL settle within existing deadlines.

#### Scenario: Project tree re-roots without waiting for repository discovery
- **WHEN** a 5000-row project tree is open and global `DirChanged` changes cwd to another generated git worktree
- **THEN** `DirChanged` returns while repository discovery is still pending, consumes at most 100 ms of process CPU time, finishes within 100 ms multiplied by the host load factor in the serial performance layer, and within 1000 ms the tree shows the new root and watches its git directory

#### Scenario: Project tree persists folds off the action path
- **WHEN** a 5000-row tree is open and `za` is pressed in normal mode on a folder
- **THEN** the action consumes at most 100 ms of process CPU time, finishes within 100 ms multiplied by the host load factor in the serial performance layer, and within 1000 ms `expanded.json` contains the resulting valid expansion state

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
`file_tree.unfold_all` SHALL discover folders and count visible rows in one traversal, preserve ignored-folder and nesting behavior, and build the final rows once. At the 5000-row limit it SHALL consume at most 500 ms of process CPU time and meet the 500 ms load-scaled wall-time bound in the serial performance layer.

#### Scenario: Project tree unfold all meets the large-tree bound
- **WHEN** only the root is expanded in a generated fixture with 60 folders of 100 files and `zR` is pressed in normal mode
- **THEN** it consumes at most 500 ms of process CPU time, finishes within 500 ms multiplied by the host load factor in the serial performance layer, has at most 5001 rows, and emits the WARN notification `Unfold all stopped at 5000 rows`

#### Scenario: Project tree unfold all preserves skipped expansion state
- **WHEN** Show Ignored is on, an ignored folder is expanded with `<CR>`, and `zR` is pressed in normal mode
- **THEN** the ignored folder remains expanded and its child remains listed
