# Spec Delta

## ADDED Requirements

### Requirement: Find Usages fold keys
`references.close_node`, `references.expand_node`, `references.fold_all` and `references.unfold_all` SHALL apply the shared tree fold verbs to scope, usage type and folder rows, and `references.fold` on a usage row SHALL fold its group and select it. The view SHALL stay open with the tree focused, and no key SHALL raise an error.

#### Scenario: h folds a group and l unfolds it
- **WHEN** the view is open for `Format` in the `gomod` fixture with default grouping, the cursor is on the `billing 2` row, and `h` and then `l` are pressed
- **THEN** after `h` the `invoice.go:16` and `invoice.go:23` rows are hidden; after `l` they are shown again and the cursor is on `billing 2`

#### Scenario: h on a usage folds its group
- **WHEN** the cursor is on the `summary.go:7` row and `h` is pressed
- **THEN** no `summary.go:7` row remains, the cursor is on the `report 1` row, and the view is still open

#### Scenario: l on an open group moves to its first child
- **WHEN** the cursor is on the `Production 3` row and `l` is pressed
- **THEN** the rows are unchanged and the cursor is on the `Call 3` row

#### Scenario: l on a usage keeps the view open
- **WHEN** the cursor is on the `summary.go:7` row and `l` is pressed
- **THEN** the rows and the cursor are unchanged and the current buffer is the view's tree buffer

#### Scenario: zM and zR fold every group
- **WHEN** the cursor is on the `invoice.go:23` row and `zM` and then `zR` are pressed
- **THEN** after `zM` the rows are `Production 3` and `Test 1` with the cursor on `Production 3`; after `zR` the eleven default rows are back in order and the cursor is still on `Production 3`

#### Scenario: Arrow keys and zc zo fold groups without an error
- **WHEN** `v:errmsg` is empty, the cursor is on the `billing 2` row, and `<Left>`, `<Right>`, `zc` and `zo` are pressed in turn
- **THEN** the `invoice.go:16` row is hidden after `<Left>` and `zc` and shown after `<Right>` and `zo`, and `v:errmsg` is still empty

## MODIFIED Requirements

### Requirement: Find Usages navigation keys
The view's keys SHALL be registry actions scoped to the view, bound from `settings/keymap.json`: `<CR>` opens the selected usage (or folds/unfolds a group row), `za` folds/unfolds the group under the cursor, `h` `<Left>` `zc` fold, `l` `<Right>` `zo` unfold, `zM` and `zR` fold and unfold every group, `q` and `<Esc>` close the view. Opening a usage SHALL close the view and place the cursor on the usage; closing SHALL return to the window the view was opened from.

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
- **THEN** each of `<CR>`, `za`, `h`, `<Left>`, `zc`, `l`, `<Right>`, `zo`, `zM`, `zR`, `t`, `f`, `u`, `P`, `q` and `<Esc>` has a `desc` naming a registered `references.*` action, `settings/keymap.json` lists that action with that key, and no buffer-local `w` mapping exists
