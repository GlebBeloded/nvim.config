## ADDED Requirements

### Requirement: Project tree create
`file_tree.add` SHALL open the picker input prompt titled `New File or Directory` for the target folder: a folder row's own folder (a compact row's last folder), a file row's folder, or the root. A name ending in `/` SHALL create a folder; any other name an empty file; missing parents SHALL be created. A new file SHALL open in the editor window with focus; a new folder SHALL be selected in the tree. An existing path SHALL notify `Already exists: <relative path>` at ERROR and change nothing.

#### Scenario: Project tree a creates a file in the folder under the cursor
- **WHEN** `internal` is expanded, the cursor is on the `billing` row, `a` is pressed in normal mode and `tax_rate.go<CR>` is typed
- **THEN** `internal/billing/tax_rate.go` exists and is empty, the current window is the editor window showing it, and the tree has a `tax_rate.go` row

#### Scenario: Project tree a on a file creates next to it
- **WHEN** the cursor is on the `invoice.go` row, `a` is pressed in normal mode and `fee.go<CR>` is typed
- **THEN** `internal/billing/fee.go` exists

#### Scenario: Project tree a with a trailing slash creates a folder
- **WHEN** the cursor is on the `billing` row, `a` is pressed in normal mode and `rates/<CR>` is typed
- **THEN** `internal/billing/rates` is a directory, the tree cursor is on its row, and the tree window is current

#### Scenario: Project tree a creates missing parent folders
- **WHEN** the cursor is on the root row, `a` is pressed in normal mode and `api/v1/handler.go<CR>` is typed
- **THEN** `api/v1/handler.go` exists and the tree shows the row `api/v1` expanded with `handler.go` below it

#### Scenario: Project tree a reports an existing name
- **WHEN** the cursor is on the `billing` row, `a` is pressed in normal mode and `tax.go<CR>` is typed
- **THEN** a notification `Already exists: internal/billing/tax.go` at ERROR is emitted and the content of `tax.go` is unchanged

#### Scenario: Project tree add prompt matches the approved render
- **WHEN** the tree is shown as in "Proposed F1 — project tree", `a` is pressed on the `invoice.go` row and `tax_rate.go` is typed
- **THEN** the screen matches the approved render "Proposed G1 — add prompt" (design.md) in text and in the colours of the prompt

### Requirement: Project tree rename
`file_tree.rename` SHALL open the picker input prompt titled `Rename` with the entry name as its query; the submitted name is relative to the entry's folder and may contain `/`. Before moving, it SHALL send `workspace/willRenameFiles` to clients whose `willRename` filters match and apply their edits, waiting at most 1000 ms; then move with `vim.lsp.util.rename`, so loaded buffers follow; then notify `workspace/didRenameFiles` to matching `didRename` clients.

#### Scenario: Project tree r renames a file and its buffer
- **WHEN** `internal/billing/invoice.go` is loaded in buffer N, the cursor is on its tree row, `r` is pressed in normal mode and `<C-u>bill.go<CR>` is typed
- **THEN** `internal/billing/bill.go` exists, `invoice.go` does not, buffer N's name is the absolute path of `bill.go`, `:write` in buffer N raises no error, and the tree cursor is on the `bill.go` row

#### Scenario: Project tree r renames a folder and the buffers inside
- **WHEN** `internal/money/money.go` is loaded, the cursor is on the `money` row, `r` is pressed in normal mode and `<C-u>currency<CR>` is typed
- **THEN** `internal/currency/money.go` exists, `internal/money` does not, and the buffer of `money.go` is named after `internal/currency/money.go`

#### Scenario: Project tree rename asks language servers to update references
- **WHEN** an in-process language server advertising `workspace.fileOperations.willRename` and `didRename` with the filter `**/*.go` is attached, it answers `willRenameFiles` with an edit inserting `// moved` as line 1 of `cmd/server/main.go`, and `invoice.go` is renamed to `bill.go` with `r`
- **THEN** the server received `workspace/willRenameFiles` with `files = { { oldUri = <invoice.go uri>, newUri = <bill.go uri> } }` while `invoice.go` still existed, line 1 of `cmd/server/main.go` is `// moved`, and it then received `workspace/didRenameFiles` with the same files

#### Scenario: Project tree rename skips servers whose filters do not match
- **WHEN** the only attached in-process server's `willRename` filter is `**/*.ts` and `invoice.go` is renamed to `bill.go` with `r`
- **THEN** the server received no `workspace/willRenameFiles` request and `bill.go` exists

#### Scenario: Project tree rename waits for servers at most one second
- **WHEN** the attached in-process server never answers `workspace/willRenameFiles` and `invoice.go` is renamed to `bill.go` with `r`
- **THEN** `bill.go` exists within 1500 ms of `<CR>` and no error is raised

#### Scenario: Project tree r reports an existing name
- **WHEN** the cursor is on the `invoice.go` row, `r` is pressed in normal mode and `<C-u>tax.go<CR>` is typed
- **THEN** a notification `Already exists: internal/billing/tax.go` at ERROR is emitted and both `invoice.go` and `tax.go` keep their content

#### Scenario: Project tree rename prompt matches the approved render
- **WHEN** the tree is shown as in "Proposed F1 — project tree" and `r` is pressed on the `invoice.go` row
- **THEN** the screen matches the approved render "Proposed G2 — rename prompt" (design.md) in text and in the colours of the prompt

### Requirement: Project tree delete
`file_tree.delete` SHALL act on the row under the cursor or, in Visual mode, on every selected row except the root. After `vim.ui.select` with `Move to Trash` (or `Delete` without a `trash` command) and `Cancel` confirms, it SHALL run `trash -s <absolute paths>` when `trash` is executable, else remove them recursively; unmodified buffers of removed files SHALL be wiped with their windows kept. A failure SHALL notify `Delete failed: <stderr>` at ERROR.

#### Scenario: Project tree d moves a file to the Trash after confirmation
- **WHEN** `PATH` starts with a directory whose fake `trash` records its arguments and removes them, the cursor is on the `tax_test.go` row, `d` is pressed in normal mode and `Move to Trash` is chosen
- **THEN** the fake `trash` received `-s` and the absolute path of `tax_test.go`, the file is gone, and the tree has no `tax_test.go` row

#### Scenario: Project tree d keeps the file when cancelled
- **WHEN** the cursor is on the `tax_test.go` row, `d` is pressed in normal mode and `Cancel` is chosen
- **THEN** `tax_test.go` still exists and no `trash` command was run

#### Scenario: Project tree Visual d deletes every selected row
- **WHEN** the fake `trash` is on `PATH`, `V` selects the `discount.go` and `discount_test.go` rows, `d` is pressed and `Move to Trash` is chosen
- **THEN** one fake `trash` call received `-s` and both absolute paths, and neither file exists

#### Scenario: Project tree d deletes without a trash command
- **WHEN** `PATH` holds no `trash` executable, the cursor is on the `web` row, `d` is pressed in normal mode and `Delete` is chosen
- **THEN** the `web` folder no longer exists on disk

#### Scenario: Project tree d closes buffers of deleted files
- **WHEN** `internal/billing/tax_test.go` is shown unmodified in the editor window, the fake `trash` is on `PATH`, and it is deleted from its tree row with `d` and `Move to Trash`
- **THEN** no buffer is named after `tax_test.go` and the tab has the same number of windows as before

#### Scenario: Project tree d reports a failed delete
- **WHEN** a fake `trash` that prints `boom` on stderr and exits 1 is on `PATH`, and `tax_test.go` is deleted with `d` and `Move to Trash`
- **THEN** a notification `Delete failed: boom` at ERROR is emitted and `tax_test.go` still exists

### Requirement: Project tree copy, cut and paste
`file_tree.copy` and `file_tree.cut` SHALL put the row under the cursor, or every selected row in Visual mode, in the tree clipboard. `file_tree.paste` SHALL paste into the target folder as `file_tree.add` defines it: copies recursively, and when the name exists, after the picker input `Copy` prefilled with `<stem>_copy<ext>`; cuts move like a rename and clear the clipboard. Pasting a folder into itself or below it SHALL notify `Cannot paste <path> into itself` at ERROR.

#### Scenario: Project tree c and p copy a file into another folder
- **WHEN** `c` is pressed in normal mode on the `money.go` row and `p` on the `cmd/server` row
- **THEN** `cmd/server/money.go` has the content of `internal/money/money.go`, which still exists

#### Scenario: Project tree pasting a copy over an existing name asks for a new name
- **WHEN** `c` is pressed on the `invoice.go` row, `p` on the `billing` row, and the prompt titled `Copy`, whose query is `invoice_copy.go`, is confirmed with `<CR>`
- **THEN** `internal/billing/invoice_copy.go` has the content of `invoice.go`

#### Scenario: Project tree c and p copy a folder recursively
- **WHEN** `c` is pressed on the `money` row and `p` on the root row
- **THEN** `money/money.go` and `money/money_test.go` exist at the root with the content of the originals

#### Scenario: Project tree x and p move a file like a rename
- **WHEN** `internal/billing/discount.go` is loaded in buffer N, `x` is pressed on its row and `p` on the `money` row
- **THEN** `internal/money/discount.go` exists, `internal/billing/discount.go` does not, buffer N is named after the new path, and `require("gleb.file_tree.ops").state.clipboard` is nil

#### Scenario: Project tree refuses to paste a folder into itself
- **WHEN** `x` is pressed on the `internal` row and `p` on the `billing` row below it
- **THEN** a notification `Cannot paste internal into itself` at ERROR is emitted and `internal/billing/invoice.go` still exists

#### Scenario: Project tree Visual c copies every selected row
- **WHEN** `V` selects the `discount.go` and `invoice.go` rows, `c` is pressed, and `p` is pressed on the `money` row
- **THEN** `internal/money/discount.go` and `internal/money/invoice.go` exist

### Requirement: Project tree refresh and operation keys
`file_tree.refresh` SHALL rescan every expanded folder and rerun git status at once. The operation actions SHALL be scoped to filetype `gleb-file-tree` with keys only from `settings/keymap.json`: `add` `a`, `rename` `r`, `delete` `d`, `copy` `c`, `cut` `x`, `paste` `p`, `refresh` `R`, with `delete`, `copy` and `cut` also in Visual mode.

#### Scenario: Project tree R picks up changes at once
- **WHEN** the watchers are stopped with `require("gleb.file_tree.watch").stop_all()`, `internal/billing/fee.go` is created on disk, and `R` is pressed in normal mode
- **THEN** a `fee.go` row exists and `require("gleb.file_tree.git").state.runs` grew by one

#### Scenario: Project tree operation keys come from the keymap file
- **WHEN** the project tree buffer is current and its buffer-local mappings are read with `nvim_buf_get_keymap(0, "n")` and `nvim_buf_get_keymap(0, "x")`
- **THEN** normal mode maps `a`, `r`, `d`, `c`, `x`, `p` and `R`, Visual mode maps `d`, `c` and `x`, each with the `desc` `Project: <action title>` of its `settings/keymap.json` action
