## ADDED Requirements

### Requirement: Changes review entry point
The config SHALL map `<A-g>` in normal mode to the `changes.review` action.

#### Scenario: Alt-g opens the changes review
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing` fixture is edited and `<A-g>` is pressed in normal mode
- **THEN** the current window has filetype `gleb-changes` with its cursor on the `invoice.go` row, and within the integration async wait budget the editor area shows the diff view of `internal/billing/invoice.go`

### Requirement: Project tree and changes panel toggles
The config SHALL map `<A-e>` in normal mode to the `file_tree.toggle` action and `<A-G>` to the `changes.toggle` action. Opening the project tree from a buffer whose file exists under the root SHALL put the tree cursor on that file's row. Each key SHALL close its panel when that panel is the current window, and opening one panel SHALL close the other.

#### Scenario: Alt-e reveals current file
- **WHEN** a file `foo.lua` is being edited and `<A-e>` is pressed in normal mode
- **THEN** the current window has `filetype` `gleb-file-tree` and the cursor line is the `foo.lua` row

#### Scenario: Alt-e on URI buffer focuses the project tree
- **WHEN** the current buffer is named `diffview:///x` and `<A-e>` is pressed in normal mode
- **THEN** the current window has `filetype` `gleb-file-tree`, its cursor is on the root row and no error is reported

#### Scenario: Alt-e tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised and the focused project tree has its cursor on the root row

#### Scenario: Alt-e closes the focused project tree
- **WHEN** the current window is the project tree and `<A-e>` is pressed in normal mode
- **THEN** no window with `filetype` `gleb-file-tree` remains

#### Scenario: Alt-G replaces the project tree with the changes panel
- **WHEN** the current window is the project tree inside a git repository and `<A-G>` is pressed in normal mode
- **THEN** the current window has `filetype` `gleb-changes` and no window with `filetype` `gleb-file-tree` remains

#### Scenario: Alt-G closes the focused changes panel
- **WHEN** the current window is the changes panel and `<A-G>` is pressed in normal mode
- **THEN** no window with `filetype` `gleb-changes` remains

### Requirement: Pending panel work does not override a toggle
A project tree rescan or git status refresh, or a changes panel refresh, that completes after its panel was closed by `<A-e>` or `<A-G>` SHALL NOT reopen or focus that panel.

#### Scenario: Toggle wins over a pending tree refresh
- **WHEN** the focused project tree shows the expanded `internal/billing` folder of the `treeproj` fixture, `touch internal/billing/fee.go` runs as an external process and `<A-e>` is pressed in normal mode at once
- **THEN** after 1000 ms no window with `filetype` `gleb-file-tree` exists and the current window is the editor window

#### Scenario: Toggle wins over a pending changes refresh
- **WHEN** the focused changes panel of the `dirty` fixture has a refresh pending after `FocusGained` and `<A-G>` is pressed in normal mode at once
- **THEN** after 1000 ms no window with `filetype` `gleb-changes` exists

## MODIFIED Requirements

### Requirement: Normal-mode command maps bypass the command line
The config SHALL run the Ex commands behind the normal-mode maps `<C-Up>`, `<C-Down>`, `<C-Left>`, `<C-Right>`, `<C-q>` and `<A-F>` without entering the command line, so no `CmdlineEnter` event fires and the command line is not redrawn with the command.

#### Scenario: Command maps do not enter the command line
- **WHEN** two windows exist stacked (`:split`), a `CmdlineEnter` autocmd counts its events, and `<C-Up>`, `<C-Down>`, `<C-Left>` and `<C-Right>` are pressed in normal mode
- **THEN** the `CmdlineEnter` count is 0

## REMOVED Requirements

### Requirement: Differ entry point
**Reason**: differ.nvim is removed; Cmd+G (`<A-g>`) opens the changes review.
**Migration**: "Alt-g opens Differ" → `keymaps: Alt-g opens the changes review`.

### Requirement: File tree and git panel toggles
**Reason**: neo-tree's smart toggle between its `filesystem` and `git_status` sources is removed; `<A-e>` and `<A-G>` open two separate panels.
**Migration**: replaced by "Project tree and changes panel toggles": "Alt-e reveals current file" and "Alt-e tolerates a deleted current file" keep their titles there; "Alt-e on URI buffer focuses filesystem" → `keymaps: Alt-e on URI buffer focuses the project tree`; "Alt-e closes focused filesystem tree" → `keymaps: Alt-e closes the focused project tree`; "Alt-G switches tree to git status" → `keymaps: Alt-G replaces the project tree with the changes panel`; "Alt-G closes focused git status tree" → `keymaps: Alt-G closes the focused changes panel`.

### Requirement: Pending file tree work does not override a toggle
**Reason**: neo-tree's asynchronous filesystem render is gone.
**Migration**: replaced by "Pending panel work does not override a toggle": "Toggle wins over pending filesystem render" → `keymaps: Toggle wins over a pending tree refresh` and `keymaps: Toggle wins over a pending changes refresh`.
