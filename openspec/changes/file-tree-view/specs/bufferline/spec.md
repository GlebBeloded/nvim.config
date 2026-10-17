## ADDED Requirements

### Requirement: Tabline offset for the project tree
While a project tree window (filetype `gleb-file-tree`) is open as the leftmost full-height window, the config SHALL shift the buffer tabs right by the tree width plus one column, with no label, no separator and the tree window's highlight in the offset area, exactly as for the neo-tree window.

#### Scenario: tabs start after the open project tree
- **WHEN** a `100x12` screen shows an empty buffer and the action `file_tree.toggle` opens the project tree at width 35
- **THEN** columns 1-36 of the tabline row contain only spaces and the `[No Name]` tab is drawn from column 37
