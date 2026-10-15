# find-action Specification

## Purpose
Find Action gives the user one searchable palette for discovering, running, and assigning shortcuts to editor and plugin actions without leaving Neovim.

## Requirements

### Requirement: Find Action entry point
The config SHALL expose the palette as action `find_action.open` titled `Find Action...`. Pressing `<M-A>` in normal or visual mode SHALL open it with the editor context captured before focus moves into the palette.

#### Scenario: Find Action opens from its shortcut
- **WHEN** `<M-A>` is pressed in normal mode
- **THEN** a `Find Action` palette opens for the current editor window

#### Scenario: Find Action is registered as an action
- **WHEN** the action catalog is queried for `find_action.open`
- **THEN** it returns an action titled `Find Action...` that opens the palette

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

### Requirement: Action ordering and matching
With an empty query, the palette SHALL list recently used actions saved across sessions before curated actions, retaining at most the last 20 action ids. Recent history SHALL record catalog actions run from the palette or a configured shortcut. With a query, the palette SHALL fuzzy-match action titles, categories, and aliases. Section rows SHALL be display-only; after opening or replacing results, the first actionable match SHALL be current.

#### Scenario: Empty query puts recent actions first
- **WHEN** catalog actions are run from a configured shortcut and from the palette, then the palette is reopened with no query
- **THEN** the persisted applicable actions appear before the curated action section in most-recently-used order

#### Scenario: Shortcut and palette use update recent actions
- **WHEN** one catalog action runs from a configured shortcut and another runs from the palette before reopening it
- **THEN** both actions appear in the recent section with the last-used action first

#### Scenario: Only executed shortcuts update recent actions
- **WHEN** configured mapping and plug shortcuts execute, and a colliding configured shortcut key is consumed as input by an open picker
- **THEN** only actions whose shortcut mappings executed are added to recent history

#### Scenario: Recent history keeps the last 20 actions
- **WHEN** more than 20 distinct actions are run and the history is loaded in a new session
- **THEN** only the 20 most recently used action ids remain in order

#### Scenario: Query matches all searchable fields
- **WHEN** a query fuzzy-matches an action title, category, or alias
- **THEN** that action appears in the matching results

#### Scenario: Selection skips section rows
- **WHEN** the palette opens or Show hidden or a query makes a section row the first match
- **THEN** the first actionable match is selected and Enter, `<M-}>`, and navigation all act from that row

### Requirement: Hidden and unavailable actions
Hidden Ex-command actions and actions unavailable for the captured mode, filetype, or `when` condition SHALL be absent initially. Pressing `<M-A>` again while the palette is open SHALL preserve the query and reveal them below a `More results` separator; hidden Ex commands SHALL remain ineligible for shortcut assignment.

#### Scenario: Hidden and unavailable actions start absent
- **WHEN** the palette opens with hidden commands and actions unavailable in its captured context
- **THEN** none of those actions is listed

#### Scenario: Show hidden reveals a separate tier
- **WHEN** `<M-A>` is pressed in an open palette with a query
- **THEN** the query is unchanged and hidden and unavailable actions appear below a `More results` separator

#### Scenario: Hidden commands cannot be assigned
- **WHEN** shortcut assignment is requested for a hidden Ex-command row
- **THEN** no capture dialog opens and the shortcut map is unchanged

### Requirement: Actions run in the opening context
Choosing a regular action SHALL close the palette and run it in the captured window, buffer, cursor, mode, and visual selection. Choosing a toggle SHALL change it in that context and keep the palette open on the same row. A visual-mode palette SHALL list only visual actions and preserve the selection.

#### Scenario: Regular action runs like its shortcut
- **WHEN** a listed action is chosen after the palette has taken focus
- **THEN** the palette closes and the action has the same observable effect as its shortcut in the captured context

#### Scenario: Toggle changes without closing the palette
- **WHEN** Enter is pressed on a toggle action
- **THEN** the captured window's toggle changes and the palette remains open with the same row selected

#### Scenario: Visual palette preserves the selection
- **WHEN** `<M-A>` opens the palette from visual mode
- **THEN** only visual-mode actions are listed and choosing one runs it with the captured selection restored

### Requirement: Shortcut assignment flow
Pressing `<M-}>` on an eligible action SHALL open a modal capture float for chords or sequences. Enter SHALL save, Esc SHALL cancel, and a conflict SHALL offer Remove other, Keep both, or Cancel. A successful save SHALL update `settings/keymap.json` and active bindings immediately, except plugin adapters SHALL report that the shortcut applies when the plugin reopens.

#### Scenario: Assign float captures a free shortcut
- **WHEN** `<M-}>` is pressed on an eligible action and a free key sequence followed by Enter is entered
- **THEN** the float shows the keys, saves them for the action, closes, and returns focus to the palette

#### Scenario: Assignment can be cancelled
- **WHEN** Esc is pressed while the assign float is capturing keys
- **THEN** the float closes, focus returns to the palette, and the shortcut map is unchanged

#### Scenario: Conflict choices have distinct outcomes
- **WHEN** a captured shortcut conflicts and Remove other, Keep both, or Cancel is chosen
- **THEN** respectively the other binding is removed, both bindings are kept, or neither binding is changed

#### Scenario: Saved shortcut applies immediately
- **WHEN** a non-adapter shortcut assignment is saved
- **THEN** `settings/keymap.json` contains it and pressing the key runs the action without restarting Neovim

#### Scenario: Adapter assignment reports deferred application
- **WHEN** a shortcut handled by a plugin adapter is saved
- **THEN** the palette reports `applies when <plugin> reopens`

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

### Requirement: Find Action survives restart
The complete physical-key workflow SHALL open, search, run, assign, and use an action through the real terminal stack. A saved shortcut SHALL still run the action after Neovim restarts, and each workflow screen SHALL match its approved render.

#### Scenario: Physical Find Action workflow persists an assignment
- **WHEN** real keys open Find Action, search and run an action, assign another physical shortcut, use it, restart Neovim, and use it again
- **THEN** every action runs, the assignment survives the restart, and each captured screen matches its approved render
