## ADDED Requirements

### Requirement: Project tree create
`file_tree.add` SHALL prompt in `New File or Directory` for a folder row's own folder (a compact row's last folder), a file row's folder, or the root. A trailing `/` SHALL create a folder; another name SHALL create an empty file; missing parents SHALL be created. A new file SHALL open in the focused editor window; a new folder SHALL stay selected. An existing path SHALL notify `Already exists: <relative path>` at ERROR and remain unchanged.

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
`file_tree.rename` SHALL prompt in `Rename` with the entry name. The submitted name SHALL be relative to its folder and MAY contain `/`. One batched `workspace/willRenameFiles` exchange SHALL apply matching clients' edits within 1000 ms total before the move. After every target is confirmed by stat, matching clients SHALL receive one batched `workspace/didRenameFiles` notification and loaded buffers SHALL follow by realpath.

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
`file_tree.delete` SHALL act on the cursor row or deduplicated Visual rows except the root. Confirmation SHALL offer `Move to Trash` and `Cancel` when executable `/usr/bin/trash` exists, otherwise `Delete` and `Cancel`. Trash SHALL run as `/usr/bin/trash -s <lstat paths>`; its failure SHALL notify `Delete failed: <stderr>` at ERROR without permanent fallback. Without it, confirmed paths SHALL be removed recursively.

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
`file_tree.copy` and `file_tree.cut` SHALL replace the tree clipboard with the cursor row or deduplicated Visual rows. `file_tree.paste` SHALL target the folder defined by add. Copies SHALL be recursive and prompt in `Copy` with `<stem>_copy<ext>` on conflict. Cuts SHALL use the rename pipeline and clear after paste. Pasting a folder into itself or below it SHALL notify `Cannot paste <path> into itself` at ERROR.

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

### Requirement: Project tree operation path safety
Every submitted path SHALL normalize inside the tree root with no absolute path, `..` or empty segment. Rename, delete, copy and cut SHALL refuse the root row. Create and move failures SHALL leave the tree and filesystem consistent and notify their operation-specific ERROR message.

#### Scenario: Project tree refuses operations on the root row
- **WHEN** the cursor is on the root row and `r`, `d`, `c` and `x` are each pressed in normal mode
- **THEN** no prompt opens, the tree clipboard stays nil, the root still exists, and no filesystem entry changes

#### Scenario: Project tree Visual operations refuse the root row
- **WHEN** the root row alone is selected in Visual mode and `d`, `c` and `x` are each pressed
- **THEN** no confirmation opens, the tree clipboard stays nil, the root still exists, and no filesystem entry changes

#### Scenario: Project tree refuses a path that escapes the root
- **WHEN** the cursor is on the `billing` row, `r` is pressed in normal mode and `<C-u>../../../outside<CR>` is typed
- **THEN** `internal/billing` still exists, no path named `outside` is created beyond the root, and a `Rename failed:` notification at ERROR is emitted

#### Scenario: Project tree create reports a read-only destination
- **WHEN** the root has mode `0555`, the cursor is on its row, `a` is pressed in normal mode and `blocked.go<CR>` is typed
- **THEN** no `blocked.go` exists and a `Create failed:` notification at ERROR is emitted

### Requirement: Project tree move preflight
`ops.move(pairs)` SHALL preflight every pair before LSP traffic or mutation: source lstat exists; target is absent case-insensitively except its source; target is inside the root; source and destination parent have the same `dev`; and no pair is the root. A cross-device pair SHALL notify `Rename failed: cross-device`. A failed pair SHALL prevent the entire batch from moving or contacting LSP.

#### Scenario: Project tree rename refuses a vanished row
- **WHEN** the tree still shows `invoice.go` after it is removed on disk, `r` is pressed on its row and `<C-u>bill.go<CR>` is typed
- **THEN** `bill.go` does not exist, no LSP rename message is sent, and a `Rename failed:` notification at ERROR is emitted

#### Scenario: Project tree move preflights the whole batch
- **WHEN** two cut rows are pasted and the second source has vanished before `p` is pressed
- **THEN** neither source is moved, no `workspace/willRenameFiles` request is sent, and a `Rename failed:` notification at ERROR is emitted

#### Scenario: Project tree refuses a cross-device move
- **WHEN** `ops.move` is called for a source and destination whose stat results have different `dev` values
- **THEN** neither path changes, no LSP rename message is sent, and `Rename failed: cross-device` is notified at ERROR

#### Scenario: Project tree rename reports a read-only destination
- **WHEN** the destination folder has mode `0555`, `r` is pressed on the `invoice.go` row and `<C-u>bill.go<CR>` is typed
- **THEN** `invoice.go` still exists, `bill.go` does not, and a `Rename failed:` notification at ERROR is emitted

### Requirement: Project tree move identity and state
A case-only rename SHALL move through a temporary sibling. Buffer names SHALL follow moved files by realpath, including symlinked roots and `/private/var` aliases. Folder moves SHALL migrate every expanded relative key below the old path. Every view of the same root SHALL refresh once per successful batch, after all targets stat successfully and before `didRenameFiles`.

#### Scenario: Project tree supports a case-only rename
- **WHEN** the cursor is on `README.md`, `r` is pressed in normal mode and `<C-u>Readme.md<CR>` is typed on a case-insensitive filesystem
- **THEN** `Readme.md` exists with the original content, `README.md` does not, and no temporary sibling remains

#### Scenario: Project tree rename follows a buffer opened through a symlinked root
- **WHEN** `invoice.go` is loaded through a symlink to the project root and its tree row is renamed to `bill.go` with `r`
- **THEN** the loaded buffer is named through the symlink as `internal/billing/bill.go`, writes to the moved file, and no buffer retains the old realpath

#### Scenario: Project tree folder rename migrates expanded keys
- **WHEN** `internal` and `internal/billing` are expanded and `internal` is renamed to `domain` with `r`
- **THEN** the tree remains expanded through `domain/billing`, expanded state contains `domain` and `domain/billing`, and contains no key below `internal`

#### Scenario: Project tree move notifies didRename only after the target exists
- **WHEN** an in-process server records filesystem state when `workspace/didRenameFiles` arrives and `invoice.go` is renamed to `bill.go`
- **THEN** its one didRename batch arrives after `bill.go` stats successfully and after `invoice.go` is absent

### Requirement: Project tree delete buffer safety
Delete SHALL remove each selected lstat path, never its realpath target. Only files confirmed absent by stat SHALL have unmodified buffers wiped across all tabs. Replacement buffers SHALL not name a deleted file. Modified buffers SHALL remain open, the confirmation SHALL count them, and auto-save SHALL skip missing paths. A vanished row SHALL be treated as gone without deleting another path.

#### Scenario: Project tree delete refuses a vanished row safely
- **WHEN** the tree still shows `tax_test.go` after it is removed on disk and `d` then confirmation are used on its row
- **THEN** no other path is removed, the stale row disappears, and no fallback path is deleted

#### Scenario: Project tree fallback delete reports a read-only destination
- **WHEN** `/usr/bin/trash` is unavailable through the test override, the containing folder has mode `0555`, and `Delete` confirms deleting `tax_test.go`
- **THEN** `tax_test.go` still exists and a `Delete failed:` notification at ERROR is emitted

#### Scenario: Project tree delete removes a symlink and not its target
- **WHEN** the selected row is a symlink to a file outside the root and `d` is confirmed
- **THEN** the symlink is gone and the outside target and its content are unchanged

#### Scenario: Project tree trash failure never falls back to permanent delete
- **WHEN** the configured trash command exits 1 after printing `boom` and deleting nothing, and `d` is confirmed on `tax_test.go`
- **THEN** `tax_test.go` still exists, no recursive delete runs, and `Delete failed: boom` is notified at ERROR

#### Scenario: Project tree delete does not let auto-save resurrect a file
- **WHEN** a modified buffer for `tax_test.go` is open, its tree row is deleted after a confirmation naming one unsaved buffer, and the auto-save event runs
- **THEN** the modified buffer stays open, `tax_test.go` remains absent, and `should_autosave` returns false for it

#### Scenario: Project tree delete preserves windows across tabs
- **WHEN** unmodified buffers for `tax_test.go` are displayed in two tabs and its tree row is deleted
- **THEN** both buffers are wiped, every window remains, and no replacement buffer names `tax_test.go`

### Requirement: Project tree copy and paste safety
Folder copy SHALL preflight the complete destination before writing and recreate symlinks without following them. A conflict SHALL re-prompt with `_copy2` when `_copy` exists. A cut SHALL never overwrite, and cutting into its current parent SHALL do nothing. A missing clipboard source SHALL notify `Paste failed: <path>: ENOENT` and SHALL NOT stop other clipboard entries.

#### Scenario: Project tree copy conflict advances to copy2
- **WHEN** `invoice.go` and `invoice_copy.go` exist, `c` and `p` are used on `invoice.go` in `billing`, and the conflict prompt opens
- **THEN** its query is `invoice_copy2.go` and confirming it creates that file without changing either existing file

#### Scenario: Project tree folder copy preflights before writing
- **WHEN** a copied folder contains two files and the second destination already exists before `p` is pressed
- **THEN** no destination entry from that folder is created or overwritten and the conflict is resolved before copying starts

#### Scenario: Project tree folder copy recreates symlinks
- **WHEN** a copied folder contains a symlink to a file outside that folder and `p` is pressed on the root row
- **THEN** the destination contains a symlink with the same link text and the external target is neither copied nor changed

#### Scenario: Project tree cut refuses an existing target name
- **WHEN** `x` is pressed on `internal/billing/invoice.go` and `p` on a folder already containing `invoice.go`
- **THEN** both files keep their content, the source remains, and `Already exists: <relative path>` is notified at ERROR

#### Scenario: Project tree cut into its current parent is a no-op
- **WHEN** `x` is pressed on `internal/billing/invoice.go` and `p` on the `billing` row
- **THEN** the source stays in place unchanged, no LSP rename message is sent, and the clipboard is cleared

#### Scenario: Project tree paste continues after a missing clipboard path
- **WHEN** two copied paths are pasted after the first is removed from disk
- **THEN** `Paste failed: <first relative path>: ENOENT` is notified at ERROR and the second path is copied

### Requirement: Project tree refresh isolation
`file_tree.refresh` SHALL rescan the initiating view's expanded folders and start at least one immediate git-status run without replacing another tab's distinct root, expansion set, selection or buffer state.

#### Scenario: Project tree R starts at least one git status run
- **WHEN** `R` is pressed in a project tree and the git run count before and after is read
- **THEN** the run count grows by at least one

#### Scenario: Project tree R preserves another tab's tree state
- **WHEN** two tabs have trees with distinct roots, expanded folders and selections, and `R` is pressed in the first tab
- **THEN** the first tree refreshes while the second tree keeps its root, expanded folders, selection and buffer name unchanged
