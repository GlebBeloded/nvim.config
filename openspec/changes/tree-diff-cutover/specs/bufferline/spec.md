## MODIFIED Requirements

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
- **THEN** screen rows 1-4 match design.md "Proposed — tabline over the changes panel", text and colour mask

#### Scenario: tabline with tree open matches reference screenshot
- **WHEN** a `100x12` screen shows an empty buffer and the action `file_tree.toggle` has opened the project tree, and a screenshot of the tabline row is taken
- **THEN** it matches the stored reference screenshot (design.md, Proposed render)

#### Scenario: tabline without tree matches reference screenshot
- **WHEN** a `100x12` screen shows an empty buffer, the action `file_tree.toggle` has opened and then closed the project tree, and a screenshot of the tabline row is taken
- **THEN** it matches the stored reference screenshot with the `[No Name]` tab starting at column 1

## REMOVED Requirements

### Requirement: Tabline offset for the file tree
**Reason**: neo-tree is removed; the offset now follows the project tree and the changes panel.
**Migration**: "tabs start after the open tree" → `bufferline: tabs start after the open project tree`; "tabline with tree open matches reference screenshot" and "tabline without tree matches reference screenshot" keep their titles under "Tabline offset for the project tree", opened with `file_tree.toggle` instead of `:Neotree`.
