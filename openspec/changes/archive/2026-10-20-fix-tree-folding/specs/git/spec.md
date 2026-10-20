# Spec Delta

## ADDED Requirements

### Requirement: Changes panel fold keys
`changes.close_node`, `changes.expand_node`, `changes.fold_all` and `changes.unfold_all` SHALL apply the shared tree fold verbs to root, directory and nest-parent rows, and `changes.toggle_fold` on a file row SHALL fold its parent and select it. Fold state SHALL survive refreshes, the panel SHALL stay open and focused, and no key SHALL raise an error.

#### Scenario: Changes panel h folds a directory and l unfolds it
- **WHEN** the changes panel is open on a fresh copy of the `billing` fixture, the cursor is on the `internal/billing 4` row, and `h` and then `l` are pressed in normal mode
- **THEN** after `h` no `invoice.go`, `invoice_test.go`, `tax.go` or `tax_test.go` row remains and `internal/billing 4` shows U+F460; after `l` all four are back and the cursor is on `internal/billing 4`

#### Scenario: Changes panel h on a file folds its directory
- **WHEN** the cursor is on the `price.ts` row of the changes panel on the `billing` fixture and `h` is pressed in normal mode
- **THEN** no `price.ts` row remains and the cursor is on the `web/src 1` row, which shows U+F460

#### Scenario: Changes panel l on an open group moves to its first child
- **WHEN** the cursor is on the `Changes 5 files` row of the changes panel on the `billing` fixture and `l` is pressed in normal mode
- **THEN** the rows are unchanged and the cursor is on the `internal/billing 4` row

#### Scenario: Changes panel l on a file does nothing
- **WHEN** the cursor is on the `notes.md` row of the changes panel on the `billing` fixture and `l` is pressed in normal mode
- **THEN** the rows and the cursor are unchanged and the current window's filetype is `gleb-changes`

#### Scenario: Changes panel za on a file folds its parent
- **WHEN** the cursor is on the nested `invoice_test.go` row of the changes panel on the `billing` fixture and `za` is pressed in normal mode
- **THEN** no `invoice_test.go` row remains and the cursor is on the `invoice.go` row, which shows U+F460

#### Scenario: Changes panel zM and zR fold every group
- **WHEN** the cursor is on the `tax_test.go` row of the changes panel on the `billing` fixture and `zM` and then `zR` are pressed in normal mode
- **THEN** after `zM` the rows are `Changes 5 files` and `Unversioned Files 1 file` with the cursor on `Changes 5 files`; after `zR` all ten rows are back in their order and the cursor is still on `Changes 5 files`

#### Scenario: Changes panel arrow keys and zc zo fold without an error
- **WHEN** `v:errmsg` is empty, the cursor is on the `web/src 1` row of the changes panel on the `billing` fixture, and `<Left>`, `<Right>`, `zc` and `zo` are pressed in turn in normal mode
- **THEN** the `price.ts` row is gone after `<Left>` and `zc` and back after `<Right>` and `zo`, and `v:errmsg` is still empty

## MODIFIED Requirements

### Requirement: Changes panel keys
The panel keys SHALL come from `changes.*` actions scoped to `gleb-changes`: `<Space>`, `A`, `<CR>`, `X`, `gc`, `P`, `q`, `za`, `h`, `<Left>`, `zc`, `l`, `<Right>`, `zo`, `zM`, `zR`. Those actions SHALL set no `plugin`; the panel SHALL set no local `gr`. `changes.toggle` and `changes.review` SHALL be in Find Action's approved catalog list.

#### Scenario: Changes panel mappings come from the shortcut file
- **WHEN** the changes panel is opened after `VeryLazy` and its buffer-local normal mappings are enumerated
- **THEN** every mapping invokes the `changes.*` action assigned to its lhs by `settings/keymap.json`, with description `Changes: <Title>`, and no other mapping exists

#### Scenario: Changes panel leaves gr global
- **WHEN** the changes panel buffer is current and `vim.fn.maparg("gr", "n", false, true)` is read
- **THEN** the result is the global mapping (`buffer` is 0) whose callback opens the Find Usages view

#### Scenario: Changes panel entry points are actions
- **WHEN** the action catalog is read after startup
- **THEN** it contains `changes.toggle` titled `Toggle Changes` and `changes.review` titled `Review Changes`, both in category `View | Tool Windows`
