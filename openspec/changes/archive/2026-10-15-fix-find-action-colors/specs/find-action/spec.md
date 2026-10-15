# Spec Delta

## MODIFIED Requirements

### Requirement: Action rows
The palette SHALL draw each action with its title first, two spaces before its first shortcut, and its category right-aligned, with no icon column. Equivalent Alt/Meta and control-key spellings SHALL resolve to the same physical label; an unknown shortcut SHALL use canonical Vim notation. Toggle rows SHALL show a green `●` when on or a grey `○` when off before the category, without ON/OFF text.

#### Scenario: Rows show action metadata
- **WHEN** an action with multiple shortcuts and a known physical label is listed
- **THEN** its row shows the title, two spaces, only the first shortcut's physical label, and the right-aligned category without an icon

#### Scenario: Rows fall back to Vim notation
- **WHEN** an action's first shortcut has no physical label
- **THEN** its row shows that shortcut in canonical Vim notation two spaces after the title

#### Scenario: Toggle rows show state glyphs
- **WHEN** available toggle actions in on and off states are listed
- **THEN** their rows show green `●` and grey `○` state glyphs respectively and no ON/OFF text

#### Scenario: Rows normalize shortcut spellings
- **WHEN** listed actions use equivalent Alt/Meta or control-key spellings such as `<A-F>`, `<C-h>`, `<M-H>`, or `<C-S>`
- **THEN** every known shortcut shows its corresponding physical label instead of raw Vim notation

### Requirement: Find Action reference screens
The palette SHALL match the approved renders for its empty, queried, toggle, hidden, assignment, and visual states. Wide and compact layouts SHALL show an in-frame darker hint band with dim words, bright keys, applicable hints on the left, and the match counter on the right; they SHALL omit a standalone Remove hint. Below 48 columns it SHALL show titles only and no hint band.

#### Scenario: Wide palette matches reference screenshots
- **WHEN** the palette is shown at 100 columns in empty, queried, toggle, hidden, or visual state
- **THEN** its body, selected row, prompt, section labels and rules, metadata, hint band, applicable hints, match counter, screen content, and highlights match the approved wide reference render

#### Scenario: Compact palette matches reference screenshot
- **WHEN** the palette is shown at 60 columns
- **THEN** categories are absent, hints are reduced to bright keys on the left, the match counter remains on the right, and the screen matches the approved compact render

#### Scenario: Narrow palette matches reference screenshot
- **WHEN** the palette is shown at 40 columns
- **THEN** only titles are shown, the hint band and match counter are absent, and the screen matches the approved narrow render

#### Scenario: Conflict assignment matches reference screenshot
- **WHEN** the assign float shows a shortcut conflict
- **THEN** its keys, conflicting actions, buttons, screen content, and highlights match the approved conflict render

#### Scenario: Free assignment matches reference screenshot
- **WHEN** the assign float shows a shortcut without conflicts
- **THEN** its keys, no-conflict message, buttons, screen content, and highlights match the approved free-assignment render
