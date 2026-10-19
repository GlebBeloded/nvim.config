# Spec Delta

## ADDED Requirements

### Requirement: Project tree unfold and fold keys
`file_tree.expand_node` SHALL expand a folded folder or nest parent, move the cursor to the first child of an open one, and do nothing on any other file row. `file_tree.close_node` SHALL keep its behaviour on all its keys. Both SHALL be the shared tree fold verbs, raise no error, and keep the 5000-row expansion bound.

#### Scenario: Project tree l expands a folder
- **WHEN** the cursor is on the collapsed `internal` row and `l` is pressed in normal mode
- **THEN** the `billing` and `money` rows follow `internal`, `internal` shows U+F47C, and the cursor is still on `internal`

#### Scenario: Project tree l on an open folder moves to its first child
- **WHEN** `internal` is expanded, the cursor is on the `internal` row and `l` is pressed in normal mode
- **THEN** the rows are unchanged and the cursor is on the `billing` row

#### Scenario: Project tree l on a file does nothing
- **WHEN** the tree is open next to one window showing `go.mod`, the cursor is on the `Makefile` row and `l` is pressed in normal mode
- **THEN** the rows and the cursor are unchanged, the tree is the current window, and no window edits `Makefile`

#### Scenario: Project tree l opens a nest
- **WHEN** `internal` and `billing` are expanded, the cursor is on the collapsed `invoice.go` row and `l` is pressed in normal mode
- **THEN** the next row is `invoice_test.go`, the cursor is still on `invoice.go`, and no window edits `internal/billing/invoice.go`

#### Scenario: Project tree arrow keys fold and unfold a folder
- **WHEN** the cursor is on the collapsed `internal` row, `<Right>` is pressed and then `<Left>` in normal mode
- **THEN** after `<Right>` the `billing` and `money` rows follow `internal`, and after `<Left>` they are gone, `internal` shows U+F460 and the cursor is on it

#### Scenario: Project tree zo and zc fold without an error
- **WHEN** `v:errmsg` is empty, the cursor is on the collapsed `internal` row, and `zo` and then `zc` are pressed in normal mode
- **THEN** after `zo` the `billing` row follows `internal`, after `zc` it is gone, and `v:errmsg` is still empty

## MODIFIED Requirements

### Requirement: Project tree keys
The project tree actions SHALL be registered in `file_tree/actions.lua` with category `Project`; `file_tree.toggle` and `file_tree.reveal` without a filetype, the others scoped to filetype `gleb-file-tree`. Their keys SHALL come only from `settings/keymap.json`: `open` `<CR>` `o`, `expand_node` `l` `<Right>` `zo`, `close_node` `h` `<Left>` `zc` `<BS>`, `open_split` `s`, `open_vsplit` `v`, `open_tab` `t`, `close` `q`, `toggle_fold` `za`, `fold_all` `zM`, `unfold_all` `zR`.

#### Scenario: Project tree keys come from the keymap file
- **WHEN** the project tree buffer is current and its buffer-local normal-mode mappings are read with `nvim_buf_get_keymap(0, "n")`
- **THEN** each lhs listed for a `file_tree.*` action in `settings/keymap.json` is mapped, and its `desc` is `Project: <action title>`
