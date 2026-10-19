## MODIFIED Requirements

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
