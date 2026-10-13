# bufferline Specification

## Purpose
The bufferline tabline at the top of the screen: one tab per listed buffer, styled from the statusline palette, aligned with the editor window when a side panel is open.

## Requirements
### Requirement: Tabline offset for the file tree
While a neo-tree window is open as the leftmost full-height window, the config SHALL shift the buffer tabs right by the tree width plus one column (the window separator), so the first tab starts above the editor window. The offset area SHALL hold no label and no separator and SHALL use the tree window's highlight. With no tree open, tabs SHALL start at column 1.

#### Scenario: tabs start after the open tree
- **WHEN** a `100x12` screen shows an empty buffer and `:Neotree filesystem` opens the tree at width 35
- **THEN** columns 1-36 of the tabline row contain only spaces and the `[No Name]` tab is drawn from column 37

#### Scenario: tabline with tree open matches reference screenshot
- **WHEN** a `100x12` screen shows an empty buffer and `:Neotree filesystem` has opened the tree, and a screenshot of the tabline row is taken
- **THEN** it matches the stored reference screenshot (design.md, Proposed render)

#### Scenario: tabline without tree matches reference screenshot
- **WHEN** a `100x12` screen shows an empty buffer, `:Neotree close` has closed the tree, and a screenshot of the tabline row is taken
- **THEN** it matches the stored reference screenshot with the `[No Name]` tab starting at column 1
