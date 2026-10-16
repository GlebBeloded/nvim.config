## ADDED Requirements

### Requirement: Find Usages view opens on gr
Normal-mode `gr` SHALL request `textDocument/references` (declaration excluded) from the attached clients that support it and open the Find Usages view for the symbol under the cursor. When no attached client supports references, or no usages are returned, it SHALL notify at INFO level (`No LSP references support` / `No usages found`) and open no window.

#### Scenario: gr opens the view in a Go module
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration, gopls attached, and `gr` is pressed in normal mode
- **THEN** a Find Usages view is open whose top border title is `Usages of Format · 4`

#### Scenario: gr with no usages notifies and opens nothing
- **WHEN** the cursor is on a local variable that has no usages and `gr` is pressed in normal mode
- **THEN** `No usages found` is notified at INFO level and the window count is unchanged

#### Scenario: gr without a references-capable client notifies
- **WHEN** a buffer with no attached LSP client is current and `gr` is pressed in normal mode
- **THEN** `No LSP references support` is notified at INFO level and the window count is unchanged

### Requirement: Find Usages layout
With the preview shown, the view SHALL be a centred rounded float covering the editor except two columns per side and the bufferline and statusline rows, with the tree on the left (45% of the inner width) and the preview on the right. Without the preview it SHALL shrink to its content and stay centred. Hints SHALL sit on the last inner row below a joined rule. Below 80 editor columns the preview SHALL start hidden.

#### Scenario: Wide view matches reference screenshot
- **WHEN** `gr` is pressed on `Format` in the `gomod` fixture with the editor at 100x30 and default grouping
- **THEN** the screen matches the approved render "Proposed V1 — default grouping"

#### Scenario: Narrow view fits its content
- **WHEN** `gr` is pressed on `Format` in the `gomod` fixture with the editor at 70x24
- **THEN** the view has no preview pane, is only as wide and tall as its rows and hints need, is centred, and the screen matches the approved render "Proposed V4 — no preview"

#### Scenario: View reflows when the editor resizes
- **WHEN** an open wide view is resized wider and then below 80 editor columns
- **THEN** its frame is recentered at each size and it switches to the fitted layout without a preview below 80 columns

### Requirement: Usage tree grouping
The tree SHALL group usages by test scope (`Production` before `Test`, from test-file detection), then by folder, with one row per folder showing its full path relative to the working directory (no nested folder rows), ordering rows by path then line. Group rows SHALL show their usage count. Usage rows SHALL show only `<file name>:<line>`.

#### Scenario: Go usages are grouped by scope and folder
- **WHEN** the view is open for `Format` in the `gomod` fixture with default grouping
- **THEN** the tree rows are, in order: `Production 3`, `billing 2`, `invoice.go:16`, `invoice.go:23`, `report 1`, `summary.go:7`, `Test 1`, `internal/money 1`, `money_test.go:6`

#### Scenario: Nested folders become one row
- **WHEN** the view lists usages in `internal/provisioner/postgres/deprovision.go` and `internal/provisioner/postgres/provision.go`
- **THEN** a single folder row `internal/provisioner/postgres 2` holds both usage rows and no row exists for `internal` or `internal/provisioner`

#### Scenario: The first usage is selected and previewed
- **WHEN** the view opens for `Format` in the `gomod` fixture
- **THEN** the cursor is on the `invoice.go:16` row and the preview shows `billing/invoice.go` centred on line 16

### Requirement: Tree icons and colours
Production rows SHALL show the oct-rocket glyph (U+F427) in aqua, Test rows the oct-beaker glyph (U+F499) in yellow, folder rows the md-folder_outline glyph (U+F0256) in grey, and usage rows their file's devicon in its colour. Each label SHALL use a paler shade of its icon colour, the palette mix of icon colour and foreground at 0.7; counts and `:<line>` SHALL use the secondary picker highlight.

#### Scenario: Icons and label shades match the palette
- **WHEN** the view is open for `Format` and the extmarks of the `Production 3`, `Test 1`, `billing 2` and `invoice.go:16` rows are read
- **THEN** each icon cell uses its icon group (aqua, yellow, grey, the Go devicon colour) and each label uses a group whose foreground equals the 0.7 mix of that icon colour and the palette foreground

#### Scenario: Label shade is the 0.7 mix of icon and foreground
- **WHEN** the label colour is computed for icon colour `#000000` and foreground `#646464`
- **THEN** it is `#464646`, 70% of the way from the icon colour to the foreground

### Requirement: Grouping controls
`t` SHALL cycle the tests mode: grouped (`Production`/`Test` level), hidden (test usages removed), mixed (no scope level; test usages carry a right-aligned beaker `test` tag). `f` SHALL toggle `Folders` (off: usage rows show the path relative to the working directory). Each change SHALL rebuild the tree in place, keep the selected usage when still listed, update counts and the title, show its state in the hint row (`Tests: <mode> t`, `●`/`○ Folders f`), and persist across sessions.

#### Scenario: Tests key cycles grouped, hidden and mixed
- **WHEN** the view is open for `Format` with default grouping and `t` is pressed three times
- **THEN** after the first press the screen matches the approved render "Proposed V2 — tests hidden"; after the second there are no `Production` or `Test` rows, `money_test.go:6` carries the `test` tag and the hint row shows `Tests: mixed t`; after the third the tree equals the default one

#### Scenario: Mixed tests without folders is a flat list
- **WHEN** the view is open for `Format` with default grouping and `t`, `t`, `f` are pressed
- **THEN** the screen matches the approved render "Proposed V3 — tests mixed, folders off"

#### Scenario: Grouping persists across sessions
- **WHEN** `t` and `f` are pressed once in the view, Neovim is restarted, and the view is opened again for `Format`
- **THEN** the hint row shows `Tests: hidden t` and `○ Folders f`, and no `Test` group is listed

#### Scenario: Regrouping keeps the selected usage
- **WHEN** the cursor is on the `summary.go:7` row and `f` is pressed
- **THEN** the cursor is on the `report/summary.go:7` row in the rebuilt tree

#### Scenario: Tests filter can leave the tree empty
- **WHEN** every usage is in a test file and the tests mode becomes or is persisted as hidden
- **THEN** the view remains open with count zero, a one-row tree, and no stale preview

### Requirement: Usage preview
The preview SHALL show the selected usage's file around its line, centred, with line numbers and the same syntax highlighting a regular buffer of that filetype gets (treesitter when its parser is installed, else the Vim syntax file). The usage's line number SHALL use the current-line-number highlight and every listed usage in the file SHALL be marked.

#### Scenario: Preview follows the selection
- **WHEN** the view is open for `Format` and the cursor moves to the `summary.go:7` row
- **THEN** the preview shows `report/summary.go` centred on line 7 with its line number highlighted and `Format` marked on it

#### Scenario: UTF-16 usage columns are converted to byte columns
- **WHEN** a usage follows a multibyte character and its LSP client reports UTF-16 positions
- **THEN** the preview mark and Return cursor are on the first byte of the usage

#### Scenario: Preview highlighting matches a regular buffer
- **WHEN** the preview shows `billing/invoice.go` around line 16
- **THEN** the treesitter highlight captures at every column of preview lines 11 to 16 equal the captures at the same positions in a regular buffer editing `billing/invoice.go`

#### Scenario: Preview falls back to Vim syntax without a parser
- **WHEN** the preview shows a file whose filetype has no installed treesitter parser but a Vim syntax file
- **THEN** the preview buffer's `syntax` option is that filetype and no treesitter highlighter is active for it

#### Scenario: P toggles the preview pane
- **WHEN** the view is open at 100x30 with the preview visible and `P` is pressed
- **THEN** the preview pane is closed, the window shrinks to its content as in the narrow layout, and pressing `P` again restores the wide layout

### Requirement: Preview has no side effects
The preview SHALL read the loaded buffer's text when the file is loaded, else the file on disk, and SHALL NOT load a buffer, attach an LSP client or create a swap file.

#### Scenario: Preview leaves no buffer or client behind
- **WHEN** the view is open for `Format`, every usage row is selected once, and the view is closed
- **THEN** the buffer list and the number of buffers attached to gopls equal those before `gr` was pressed

#### Scenario: Preview shows unsaved edits
- **WHEN** `billing/invoice.go` is loaded with an unsaved edit on line 15 and the `invoice.go:16` row is selected
- **THEN** the preview shows the edited line 15

### Requirement: Find Usages navigation keys
The view's keys SHALL be registry actions scoped to the view, bound from `settings/keymap.json`: `<CR>` opens the selected usage (or folds/unfolds a group row), `za` folds/unfolds the group under the cursor, `q` and `<Esc>` close the view. Opening a usage SHALL close the view and place the cursor on the usage; closing SHALL return to the window the view was opened from.

#### Scenario: Return opens a usage at its position
- **WHEN** the cursor is on the `summary.go:7` row and Return is pressed
- **THEN** the view is closed, the current buffer is `report/summary.go`, and the cursor is at line 7 on the `Format` call

#### Scenario: za folds a group
- **WHEN** the cursor is on the `billing 2` row and `za` is pressed
- **THEN** the `invoice.go:16` and `invoice.go:23` rows are hidden, and pressing `za` again shows them

#### Scenario: Escape returns to the origin window
- **WHEN** the view was opened from `internal/money/money.go` and Escape is pressed
- **THEN** no view window remains and the current window shows `internal/money/money.go` with the cursor where `gr` was pressed

#### Scenario: Built-in close returns to the origin window
- **WHEN** the view was opened from `internal/money/money.go` and the tree window is closed with `:quit`
- **THEN** no view window remains, resize handling is removed, and the current window shows `internal/money/money.go` with the cursor where `gr` was pressed

#### Scenario: View keys come from the keymap file
- **WHEN** the view buffer is current and its buffer-local normal-mode mappings are read
- **THEN** each of `<CR>`, `za`, `t`, `f`, `P`, `q` and `<Esc>` has a `desc` naming a registered `references.*` action, and `settings/keymap.json` lists that action with that key
