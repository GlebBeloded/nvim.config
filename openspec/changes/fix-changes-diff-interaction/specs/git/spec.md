## ADDED Requirements

### Requirement: Changes diff interaction
A diff shown from the panel (Local, Branch or commit row, `]f`) SHALL open with the right window's cursor on the first line of the first change and the left window's cursor on its transferred line, focus staying where it was. The window keys SHALL move between panel and both panes; motion in a pane SHALL move both. A Local or Branch right pane SHALL be the working-tree file buffer: editable, savable, re-diffed. A commit diff SHALL be read-only but navigable.

#### Scenario: Changes Local diff starts on the first change
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing-branch` fixture is current and the `changes.review` action runs
- **THEN** within the integration async wait budget the diff view of `invoice.go` is shown, the `gleb-changes` window is still current, the right window's cursor is on line 11 and the left window's cursor on line 11

#### Scenario: Changes Branch diff starts on the first change
- **WHEN** the `changes.review` action runs twice on a fresh copy of the `billing-branch` fixture with `internal/billing/invoice.go` current
- **THEN** the Branch tab shows the diff of `invoice.go`, the `gleb-changes` window is current, and the right and left windows' cursors are both on line 9

#### Scenario: Changes commit diff starts on the first change
- **WHEN** the Branch tab of the `billing-branch` fixture is shown, `c` is pressed in normal mode in the panel and the diff of `invoice.go` under `e325463` is shown
- **THEN** the right and left windows' cursors are both on line 9 and the `gleb-changes` window is current

#### Scenario: Changes ]f starts the next file on its first change
- **WHEN** the Branch tab shows the diff of `invoice.go`, focus moves to the right diff window and `]f` is pressed in normal mode
- **THEN** the diff view shows `internal/billing/invoice_test.go`, the current window is its right window and its cursor is on the first line of its first change (`fragments[1].start2 + 1`)

#### Scenario: Real key presses move, scroll and edit in the Branch diff
- **WHEN** Neovim runs in the sandbox VM's terminal stack (Alacritty, zellij) in a fresh copy of the `billing-branch` fixture, the changes panel is on the Branch tab with `invoice.go` selected, and `<C-l>` `<C-l>`, `j` `j`, `x` and `:w<CR>` are pressed as real key presses
- **THEN** the zellij screen dump shows the cursor in the right diff pane two lines below the first change, the character under the cursor was deleted in `internal/billing/invoice.go` on disk, and the diff was redrawn with that edit

#### Scenario: Window keys enter the diff panes
- **WHEN** the Local tab of the `billing-branch` fixture shows the diff of `invoice.go`, the panel is current and `<C-l>` is pressed twice in normal mode, then `<C-h>` twice
- **THEN** after the first `<C-l>` the current window is the diff's left window, after the second its right window with the cursor on line 11; after the two `<C-h>` the `gleb-changes` window is current, its cursor still on the `invoice.go` row, and the diff view is unchanged

#### Scenario: Branch diff panes move together
- **WHEN** the Branch tab shows the diff of `invoice.go`, `<C-w>l` is pressed twice from the panel, then `gg`, `j`, `j`, `<C-d>`, `G` and `k` are pressed in normal mode in the right window
- **THEN** after each key the left window's cursor is on the line `layout.transfer_line` gives for the right cursor and both windows have the same aligned top row; the right cursor ends on line 36

#### Scenario: Branch diff right pane is the working file
- **WHEN** the Branch tab of the `billing-branch` fixture shows the diff of `invoice.go`
- **THEN** the right window's buffer is `vim.fn.bufnr(<root>/internal/billing/invoice.go)`, with empty `buftype`, `modifiable` on and filetype `go`, its lines equal the file on disk, and the diff has a change at right line 11 (the uncommitted edit) besides the committed ones at lines 9 and 18

#### Scenario: Branch diff edits are saved and re-diffed
- **WHEN** the right window of the Branch diff of `invoice.go` is focused, `:11s/ \/\/ invoice number//` and `:write` run there and 300 ms pass
- **THEN** `internal/billing/invoice.go` on disk equals `git show HEAD:internal/billing/invoice.go`, the view's changes start at right lines 9, 18, 22 and 32 (none at line 11), the view is still shown and the panel still shows the Branch tab

#### Scenario: Commit diff is read-only and navigable
- **WHEN** the commit diff of `invoice.go` under `e325463` is shown, `<C-l>` is pressed twice from the panel, then `j`, `G`, `gg` and `x` in normal mode
- **THEN** the right window is current, its cursor moved with each motion while the left followed it, its lines are unchanged after `x`, its buffer has `modifiable` off and an active Tree-sitter highlighter for `go`, and no buffer of `invoice.go` was modified

#### Scenario: gf in a commit diff opens the working file
- **WHEN** the right window of the commit diff of `invoice.go` under `e325463` is current with its cursor on line 18 and `gf` is pressed in normal mode
- **THEN** no `gleb-diff` window remains, the current window edits the working-tree `internal/billing/invoice.go` with the cursor on line 18, and the `gleb-changes` window is still open on the Branch tab

#### Scenario: gf in a Branch diff preserves the working file after panel close
- **WHEN** a file that was not already open is reviewed on the Branch tab, `gf` opens its working-tree buffer, and the Changes panel is closed
- **THEN** the editor window and working-tree buffer opened by `gf` remain valid, loaded and current

## MODIFIED Requirements

### Requirement: Branch tab files
The Branch tab SHALL show its pull-request/branch header, commit summary, blank line and merge-base-to-HEAD file tree as before. When an open pull request also makes Comments available, the winbar SHALL append its cached open-thread count after Branch. File names, stats, directory compaction, nesting and the Local tab's tree conventions SHALL remain unchanged.

#### Scenario: Branch tab lists the branch files
- **WHEN** the Branch tab of a fresh copy of the `billing-branch` fixture is shown, the fake `gh` reporting pull request 482 with base `main`
- **THEN** the panel rows, with icons and padding removed, are in order `#482 feat/tax → main`, `3 commits · merge-base 4ccefde`, ``, `internal/billing 4`, `invoice.go +11 -2`, `invoice_test.go +20 -1`, `tax.go +41 -0`, `tax_test.go +33 -0`

#### Scenario: Branch tab header without a pull request
- **WHEN** the Branch tab of a fresh copy of the `billing-branch` fixture is shown and the fake `gh` reports no pull request
- **THEN** the first panel row reads `feat/tax → main` and has no `ChangesBranchHeader` extmark

#### Scenario: Branch tab colours committed files
- **WHEN** the Branch tab of the `billing-branch` fixture is shown with pull request 482
- **THEN** the name extmarks of the four file rows are `ChangesCommittedFile`, the `#482` extmark is `ChangesBranchHeader`, and no row has a `ChangesCheckbox` extmark

#### Scenario: Branch summary wording
- **WHEN** `require("gleb.git.changes.branch").summary(count, "4ccefde78a71")` is called with count 1 and 3
- **THEN** it returns `1 commit · merge-base 4ccefde` and `3 commits · merge-base 4ccefde`

#### Scenario: Branch tab matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing-branch` fixture with pull request 482 and the `changes.review` action runs twice
- **THEN** columns 1-36 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Branch tab, files", text and colour mask, except its winbar is `  Local 3   Branch 4   Comments 0  ` with Branch active and the other tabs inactive; columns 37-100 of screen rows 2-29 match the fix-changes-diff-interaction design.md "Proposed — Branch diff in kind colours", text and colour mask

### Requirement: Branch tab commit view
`changes.toggle_commits` SHALL switch the Branch tab between files and commits, and do nothing on another tab. The commit view SHALL show the header, an empty line, a collapsed `All changes` row with `<n> files` (expanding to the files tree), then `git log <merge-base>..HEAD` newest first as `<hash7> <subject> <age>`, subject cut with `…`, age right-aligned; the newest commit starts expanded, the cursor on its first file. A commit lists its files flat with stats.

#### Scenario: c shows the branch commits
- **WHEN** the Branch tab of the `billing-branch` fixture with pull request 482 is current, the panel clock reads 2026-01-02T01:00:00Z and `c` is pressed in normal mode
- **THEN** the rows, icons and padding removed, are `#482 feat/tax → main`, ``, `All changes 4 files`, `e325463 wire tax into Tot… 1h`, `invoice.go +11 -2`, `07cb52e add Rate and tax … 3h`, `b5435c5 add tax.go 1d`, and the cursor is on the `invoice.go` row

#### Scenario: c again shows the branch files
- **WHEN** the commit view of the `billing-branch` fixture is shown and `c` is pressed in normal mode
- **THEN** the rows are the files view's rows and the cursor is on the `invoice.go` row

#### Scenario: Expanding a commit lists its files
- **WHEN** the cursor is on the `07cb52e` row of the commit view and `za` is pressed in normal mode
- **THEN** the rows directly below it are `invoice_test.go +20 -1` and `tax_test.go +33 -0`, one level deeper

#### Scenario: Expanding All changes shows every branch file
- **WHEN** the cursor is on the `All changes` row of the commit view and `za` is pressed in normal mode
- **THEN** the rows directly below it are `internal/billing 4`, `invoice.go +11 -2`, `invoice_test.go +20 -1`, `tax.go +41 -0` and `tax_test.go +33 -0`

#### Scenario: c on the Local tab does nothing
- **WHEN** the Local tab of the `billing-branch` fixture is current and `c` is pressed in normal mode
- **THEN** the panel's buffer lines and the active tab are unchanged and no message is emitted

#### Scenario: Commit ages are short relative times
- **WHEN** `require("gleb.git.changes.branch").age(seconds)` is called with 30, 3599, 3600, 86399, 86400, 1209599, 1209600, 5183999, 5184000 and 31536000
- **THEN** it returns `now`, `59m`, `1h`, `23h`, `1d`, `13d`, `2w`, `8w`, `2mo` and `1y`

#### Scenario: Branch commits match the approved render
- **WHEN** a `100x30` screen shows the Branch tab of the `billing-branch` fixture with pull request 482, the panel clock reads 2026-01-02T01:00:00Z, `c` is pressed in normal mode and the diff view shows the commit's `invoice.go`
- **THEN** columns 1-36 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Branch tab, commits", text and colour mask, except its winbar is `  Local 3   Branch 4   Comments 0  ` with Branch active and the other tabs inactive; columns 37-100 of screen rows 2-29 match the fix-changes-diff-interaction design.md "Proposed — commit diff in kind colours", text and colour mask

### Requirement: Branch tab diffs
A Branch file row SHALL show `<merge-base>:<orig or path>` against the working-tree file loaded as the Local tab loads it (its own buffer; deleted or binary: read-only lines), labels `<hash7> · <base>` and `Your version`. A commit's file row SHALL show `<commit>^` against `<commit>`, read-only, labels `<parent7> · parent` and `<hash7> · <subject>`. An added or deleted side is empty. Both specs are `committed`, not actionable. `]f`, debounce, stale results and `<CR>` follow the Local tab.

#### Scenario: Branch tab shows the merge-base diff
- **WHEN** the cursor moves onto the `invoice.go` row of the Branch tab of the `billing-branch` fixture and 100 ms pass
- **THEN** the diff view's left lines equal `git show 4ccefde:internal/billing/invoice.go`, its right window shows the working-tree `invoice.go` buffer (`vim.fn.bufnr` of its path) whose lines equal the file on disk, the left winbar reads ` 4ccefde · main` and the right winbar contains `Your version`, and the shown spec has `committed = true` and `actionable = false`

#### Scenario: Branch tab shows a commit's diff
- **WHEN** the cursor is on the `invoice.go` row under `e325463` in the commit view and 100 ms pass
- **THEN** the diff view's left lines equal `git show e325463^:internal/billing/invoice.go`, its right lines equal `git show e325463:internal/billing/invoice.go` in a buffer with `modifiable` off that is not the working-tree `invoice.go` buffer, the left winbar reads ` 07cb52e · parent` and the right winbar contains `e325463 · wire tax into Total`

#### Scenario: Branch tab shows an added file
- **WHEN** the cursor moves onto the `tax.go` row of the Branch tab and 100 ms pass
- **THEN** the diff view's left side is empty and its right window shows the working-tree `internal/billing/tax.go` buffer, whose lines equal the file on disk

#### Scenario: Branch tab ]f steps through the branch files
- **WHEN** the Branch tab shows the diff of `invoice.go`, focus moves to the right diff window and `]f` is pressed three times in normal mode
- **THEN** the diff view shows `invoice_test.go`, `tax.go` and `tax_test.go` in that order and the panel cursor ends on the `tax_test.go` row

#### Scenario: Branch tab Enter opens the working file
- **WHEN** the Branch tab shows the diff of `tax.go` and `<CR>` is pressed in normal mode on the `tax.go` row
- **THEN** no `gleb-diff` window remains, the current window edits the working-tree `internal/billing/tax.go`, and the `gleb-changes` window is still open on the Branch tab

#### Scenario: Branch tab ignores staging keys
- **WHEN** the cursor is on the `invoice.go` row of the Branch tab and `<Space>`, `A` and `X` are pressed in normal mode
- **THEN** `git diff --cached --name-only` output is unchanged, no prompt opens and no file changes on disk
