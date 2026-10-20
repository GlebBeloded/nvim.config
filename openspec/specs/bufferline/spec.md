# bufferline Specification

## Purpose
The bufferline tabline at the top of the screen: one tab per listed buffer, styled from the statusline palette, aligned with the editor window when a side panel is open.

## Requirements

### Requirement: Tabline offset for the project tree
While a project tree (filetype `gleb-file-tree`) or changes panel (filetype `gleb-changes`) window is open as the leftmost full-height window, the config SHALL shift the buffer tabs right by the panel width plus one column (the window separator), so the first tab starts above the editor window. The offset area SHALL hold no label and no separator and SHALL use the panel window's highlight. With no panel open, tabs SHALL start at column 1.

#### Scenario: tabs start after the open project tree
- **WHEN** a `100x12` screen shows an empty buffer and the action `file_tree.toggle` opens the project tree at width 35
- **THEN** columns 1-36 of the tabline row contain only spaces and the `[No Name]` tab is drawn from column 37

#### Scenario: tabs start after the open changes panel
- **WHEN** a `100x12` screen shows an empty buffer in a git repository with one modified file and the action `changes.toggle` opens the changes panel at width 35
- **THEN** columns 1-36 of the tabline row contain only spaces and the `[No Name]` tab is drawn from column 37

#### Scenario: tabline over the changes panel matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing` fixture and the action `changes.toggle` runs
- **THEN** screen row 1 and columns 37-100 of screen rows 2-4 match design.md "Proposed — tabline over the changes panel", and columns 1-36 of screen rows 2-4 match rows 2-4 of the git-changes-tabs design.md "Proposed — Local only on main", text and colour mask

#### Scenario: tabline with tree open matches reference screenshot
- **WHEN** a `100x12` screen shows an empty buffer and the action `file_tree.toggle` has opened the project tree, and a screenshot of the tabline row is taken
- **THEN** it matches the stored reference screenshot (design.md, Proposed render)

#### Scenario: tabline without tree matches reference screenshot
- **WHEN** a `100x12` screen shows an empty buffer, the action `file_tree.toggle` has opened and then closed the project tree, and a screenshot of the tabline row is taken
- **THEN** it matches the stored reference screenshot with the `[No Name]` tab starting at column 1
