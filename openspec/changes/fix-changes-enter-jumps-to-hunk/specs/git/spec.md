## MODIFIED Requirements

### Requirement: Changes panel nesting
Under one root and directory, a changed file that the file-tree nesting rules (`settings/file_tree.json`) nest under another listed file SHALL be its child row. The parent gets an expander and starts expanded. `za` on a root, directory or nest parent, and `<CR>` on a structural root or directory, SHALL toggle its fold across refreshes. `<CR>` on a file SHALL enter its diff even when it is a nest parent.

#### Scenario: Changes panel nests tests under their file
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the `invoice_test.go` row directly follows the `invoice.go` row one level deeper, `tax_test.go` follows `tax.go` the same way, and `invoice.go` and `tax.go` show the expanded expander U+F47C

#### Scenario: Changes panel keeps a lone test file flat
- **WHEN** the changes panel is opened on a repository where only `pkg/a_test.go` changed and `pkg/a.go` did not
- **THEN** `a_test.go` is a file row directly under the `pkg 1` directory row, without a parent row

#### Scenario: Changes panel za folds a nest
- **WHEN** the cursor is on the `invoice.go` row of the changes panel on the `billing` fixture and `za` is pressed in normal mode, then the panel refreshes after `:checktime`
- **THEN** no row shows `invoice_test.go`, `invoice.go` shows the collapsed expander U+F460, and the state holds after the refresh

#### Scenario: Changes panel Enter folds a directory
- **WHEN** the cursor is on the `web/src 1` row of the changes panel on the `billing` fixture and `<CR>` is pressed in normal mode
- **THEN** no row shows `price.ts` and no file is opened

#### Scenario: Changes panel Enter on a nest parent enters the diff
- **WHEN** the Local tab shows the diff of `invoice.go` on the `billing` fixture and `<CR>` is pressed in normal mode on its foldable file row
- **THEN** the diff stays open and expanded, its right window is current with its cursor on the first line of the first change, and `invoice_test.go` remains visible

### Requirement: Changes panel open and close
`<CR>` on an actionable file row SHALL keep the panel-owned diff open and focus its right window at the first change. Its working-tree buffer SHALL become independent and survive panel close. `q` SHALL close only the panel and its view; editor restoration SHALL remain in `windows.restore`. Other buffers loaded only by the panel SHALL be unloaded on close when unmodified.

#### Scenario: Changes panel Enter opens the file
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** the `gleb-diff` view remains, its right window editing `b.txt` is current with its cursor on the first line of the first change, and the `gleb-changes` window is still open

#### Scenario: Changes panel Enter while the diff loads enters it once shown
- **WHEN** the Local tab starts loading the diff of `b.txt` and `<CR>` is pressed in normal mode on its file row before that load finishes
- **THEN** once the diff is shown, its right window editing `b.txt` is current with its cursor on the first line of the first change

#### Scenario: Changes panel file is an independent normal buffer
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** the current buffer is listed, has empty `buftype`, has the absolute path of `b.txt`, and remains a valid file buffer after the Changes panel closes

#### Scenario: Changes panel q closes the panel and the diff view
- **WHEN** `a.txt` was edited, the changes panel was opened, the diff view shows `b.txt`, and `q` is pressed in normal mode in the panel
- **THEN** no `gleb-changes` or `gleb-diff` window remains, the tab page count is unchanged, and the current window edits `a.txt`

#### Scenario: Changes panel close preserves another diff view
- **WHEN** another diff view exists and `q` closes a Changes panel with its own diff view
- **THEN** the panel-owned view closes and the other diff view remains valid

#### Scenario: Changes panel unloads its clean file buffer
- **WHEN** the panel loaded an otherwise unloaded file for review, the file remains unmodified and `q` closes the panel
- **THEN** that file buffer is unloaded

### Requirement: Branch tab diffs
A Branch file row SHALL compare `<merge-base>:<orig or path>` with the working-tree file; a commit file row SHALL compare `<commit>^` with `<commit>`. Their labels, added/deleted sides, read-only state and actionability SHALL remain as specified. `]f`, debounce and stale-result handling SHALL follow Local. `<CR>` SHALL focus the shown right pane at its first change for Branch and commit rows.

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
- **THEN** the `gleb-diff` view remains, its right window editing the working-tree `internal/billing/tax.go` is current with its cursor on the first line of the first change, and the `gleb-changes` window is still open on the Branch tab

#### Scenario: Branch commit Enter enters the diff
- **WHEN** the Branch tab commit view shows the diff of `invoice.go` under `e325463` and `<CR>` is pressed in normal mode on its file row
- **THEN** the read-only diff remains open, its right window is current with its cursor on the first line of the first change, and the panel remains open on the Branch tab

#### Scenario: Branch tab ignores staging keys
- **WHEN** the cursor is on the `invoice.go` row of the Branch tab and `<Space>`, `A` and `X` are pressed in normal mode
- **THEN** `git diff --cached --name-only` output is unchanged, no prompt opens and no file changes on disk
