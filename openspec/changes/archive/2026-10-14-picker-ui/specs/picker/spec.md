## Purpose

Provides the shared framed picker, responsive row layout and list sources used across the Neovim config.

## ADDED Requirements

### Requirement: Shared picker frame
Every shared picker SHALL draw a complete rounded border. Only its title and current query SHALL occupy the top border. It SHALL show no match counter and, when hints are present, SHALL reserve the final inner row for right-aligned muted hints below a rule joined to both side borders.

#### Scenario: Wide picker matches reference screenshot
- **WHEN** a shared picker with sections, metadata and hints is shown in a window at least 72 columns wide
- **THEN** its frame, rows, joined hint rule and highlights match the approved wide reference screenshot

#### Scenario: Focused match remains above the hint row
- **WHEN** focus moves beyond the fourth result in a shared picker with at least six matches
- **THEN** the focused match remains visible in the reserved item area above the hint row

#### Scenario: Alternate picker views keep the border counter-free
- **WHEN** a shared picker toggles from its main results into preview or info view
- **THEN** its complete border remains visible without a match counter

### Requirement: Picker rows
Picker rows SHALL place primary text first, optional secondary text immediately after it in a dimmer highlight, and optional category text right-aligned in a muted highlight. A section header SHALL end in a rule that fills its remaining width.

#### Scenario: Rows expose primary secondary and category text
- **WHEN** the row renderer receives an item with primary, secondary and category text
- **THEN** it draws those fields in order and aligns the category to the right edge

#### Scenario: Section header fills its row with a rule
- **WHEN** the row renderer receives a section header
- **THEN** it draws the heading followed by a rule through the remaining row width

### Requirement: Responsive picker layout
The picker SHALL recompute layout on resize. At 72 or more columns it SHALL show all row fields and full hints; at 48–71 it SHALL hide categories and reduce hints to keys; below 48 it SHALL show only primary text and no hint row. Below 15 editor lines it SHALL use the full available height.

#### Scenario: Compact picker matches reference screenshot
- **WHEN** the picker is shown at 60 columns
- **THEN** categories are absent, hints contain keys only, and the screen matches the approved compact reference screenshot

#### Scenario: Narrow picker matches reference screenshot
- **WHEN** the picker is shown at 40 columns
- **THEN** only primary row text is present, the hint row is absent, and the screen matches the approved narrow reference screenshot

#### Scenario: Short editor gives the picker full height
- **WHEN** the picker is shown in an editor with 14 lines
- **THEN** its window uses the full available height

#### Scenario: Resize recomputes picker layout
- **WHEN** an open picker crosses a responsive breakpoint after `VimResized`
- **THEN** its window geometry and visible row fields reflect the new size

### Requirement: Dashboard list actions use shared sources
The dashboard's find-file, recently-used and find-text actions SHALL open shared picker sources. The project picker action and project.nvim integration SHALL be absent after Telescope is removed.

#### Scenario: Dashboard opens shared list pickers
- **WHEN** each dashboard list action is invoked
- **THEN** a shared picker opens with the corresponding files, recent files or live-grep source
