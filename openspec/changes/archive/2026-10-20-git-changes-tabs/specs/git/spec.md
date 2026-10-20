## ADDED Requirements

### Requirement: Changes panel tabs
The panel's winbar SHALL show one pill per available tab, ` <Title> <count> `, one space apart from column 2: the active tab in `ChangesTab<Title>`, the others in `ChangesTabInactive`. `Local` (count: file rows) is always available; `Branch` (count: files changed from the merge-base to HEAD) only when `gleb.git.base` resolves a base for the current branch, never on the default branch. Tabs come from one ordered list, so a later tab is appended to it.

#### Scenario: Changes tabs show Local and Branch on a feature branch
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing-branch` fixture is edited and the `changes.toggle` action runs
- **THEN** the panel's winbar renders as `  Local 3   Branch 4 `, with `Local 3` in `ChangesTabLocal` and `Branch 4` in `ChangesTabInactive`, and the panel's first buffer line is the `Changes 2 files` row

#### Scenario: Changes tabs show only Local on the default branch
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing` fixture (on `main`) is edited and the `changes.toggle` action runs
- **THEN** the panel's winbar renders as `  Local 6 ` and holds no `Branch` text

#### Scenario: Changes tab colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `ChangesTabLocal` has `fg` bg0, `bg` blue and bold; `ChangesTabBranch` has `fg` bg0, `bg` purple and bold; `ChangesTabInactive` has `fg` grey1 and `bg` bg1; `ChangesBranchHeader` has `fg` purple and bold; `ChangesCommittedFile` and `ChangesCommitIcon` have `fg` purple; `ChangesCommitHash` has `fg` yellow

#### Scenario: Local tab matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing-branch` fixture and the `changes.review` action runs once
- **THEN** columns 1-36 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Local tab", text and colour mask

### Requirement: Changes tab cycle
With the panel closed, `changes.review` SHALL open it on Local, or on Branch when Local has no file rows and Branch is available. With the panel open in the current tab page, wherever focus is, it SHALL activate the next available tab, focus the panel and show the diff of the row under the cursor; on the last available tab it SHALL close the panel and its diff view. Local, Branch, close on a feature branch; Local, close on the default branch.

#### Scenario: Cmd+G cycles Local, Branch, then closes
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing-branch` fixture is edited and the `changes.review` action runs three times, waiting for the diff view after each of the first two
- **THEN** after the first run the Local tab is active and the diff view's right side is the working-tree `invoice.go`; after the second the Branch tab is active, the panel is current and the diff view shows `invoice.go` from `4ccefde` to `e325463`; after the third no `gleb-changes` or `gleb-diff` window remains

#### Scenario: Async Branch activation reviews a Branch row
- **WHEN** `web/src/price.ts` is current in the `billing-branch` fixture and `changes.review` opens Local then activates Branch before Branch rows have loaded
- **THEN** the Branch tab reviews its selected Branch file without requesting a Branch diff for the previous Local row

#### Scenario: First review opens Branch when nothing is uncommitted
- **WHEN** in a fresh copy of the `billing-branch` fixture `git checkout -- .` runs and `notes.md` is deleted, `:enew` is current and the `changes.review` action runs twice
- **THEN** after the first run the Branch tab is active with its cursor on the `invoice.go` row; after the second no `gleb-changes` window remains

#### Scenario: Review on the default branch opens only Local
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing` fixture is edited and the `changes.review` action runs twice
- **THEN** after the first run the Local tab is active and the diff view shows `internal/billing/invoice.go`; after the second no `gleb-changes` or `gleb-diff` window remains

#### Scenario: Review from the diff window advances the tab
- **WHEN** the Local tab of the `billing-branch` fixture shows the diff of `invoice.go`, `:wincmd l` focuses its right diff window and the `changes.review` action runs
- **THEN** the Branch tab is active, the current window is the `gleb-changes` window and the window count of the tab page is unchanged

#### Scenario: Cycle rules
- **WHEN** `require("gleb.git.changes.tabs").next(state)` is called with the active tab `local` or `branch` and the available tabs `{ "local", "branch" }`, `{ "local" }`, and `first(state)` with a Local count of 0 or 3
- **THEN** `next` returns `branch` then `close` for the two-tab list and `close` for `{ "local" }`; `first` returns `branch` for count 0 with Branch available, `local` for count 3, and `local` for count 0 without Branch

#### Scenario: Real Cmd+G presses cycle the changes tabs
- **WHEN** Neovim runs in a fresh copy of the `billing-branch` fixture and Cmd+G is pressed three times as real key presses
- **THEN** the first press shows the panel with `Local 3` active, the second with `Branch 4` active and the `3 commits · merge-base 4ccefde` row, and after the third no changes panel remains

### Requirement: Branch tab files
The Branch tab SHALL show a header (`ChangesBranchHeader` PR icon and `#<n>`, then ` <branch> → <base>` in `ChangesCount`; without a PR only `<branch> → <base>`), `<n> commit(s) · merge-base <hash7>`, an empty line, then the files of `git diff --name-status -z -M <merge-base> HEAD` as a `ui/tree` tree with the Local tab's directory compaction and nesting, names in `ChangesCommittedFile`, stats from `--numstat` and no checkboxes.

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
- **THEN** columns 1-100 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Branch tab, files", text and colour mask

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
- **THEN** columns 1-100 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Branch tab, commits", text and colour mask

### Requirement: Branch tab hint row
While the Branch tab is active, the panel's last two screen rows SHALL show a `─` rule (`PickerBorder`) across the panel and, right-aligned with one column margin, `Commits <key> · Next tab <key>` in the files view or `Files <key> · Next tab <key>` in the commit view (`PickerHint`), keys from `settings/keymap.json` in Find Action's glyphs. The last tree row SHALL scroll into view above the rule. Other tabs SHALL show no hint row.

#### Scenario: Branch tab hint names the commit view key
- **WHEN** a `100x30` screen shows the Branch tab of the `billing-branch` fixture, then `c` is pressed in normal mode
- **THEN** columns 1-35 of screen row 28 are all `─`, and columns 1-35 of screen row 29 end with `Commits c · Next tab ⌘G ` before `c` and with `Files c · Next tab ⌘G ` after it

#### Scenario: Branch tab hint follows a reassigned key
- **WHEN** `settings/keymap.json` assigns `C` instead of `c` to `changes.toggle_commits` and the Branch tab of the `billing-branch` fixture is shown
- **THEN** the hint reads `Commits C · Next tab ⌘G` and `C` toggles the commit view

#### Scenario: Branch tab keeps the last row above the hint
- **WHEN** a `100x12` screen shows the Branch tab of the `billing-branch` fixture and `G` is pressed in normal mode in the panel
- **THEN** the `tax_test.go` row is drawn on a screen row above the rule row

#### Scenario: Local tab has no hint row
- **WHEN** a `100x30` screen shows the Local tab of the `billing-branch` fixture
- **THEN** columns 1-35 of screen row 28 hold no `─` and columns 1-35 of screen row 29 hold no `Next tab`

### Requirement: Branch tab diffs
Selecting a Branch file row SHALL show in the panel's diff view `git show <merge-base>:<orig or path>` against `git show HEAD:<path>` (labels `<hash7> · <base>` and `<hash7> · HEAD`); a commit's file row `<commit>^` against `<commit>` (labels `<parent7> · parent` and `<hash7> · <subject>`); an added or deleted side is empty. The spec SHALL be `committed`, not actionable, with no `right_buf`. `]f`, debounce and stale-result rules are the Local tab's. `<CR>` opens the working file.

#### Scenario: Branch tab shows the merge-base diff
- **WHEN** the cursor moves onto the `invoice.go` row of the Branch tab of the `billing-branch` fixture and 100 ms pass
- **THEN** the diff view's left lines equal `git show 4ccefde:internal/billing/invoice.go`, its right lines equal `git show HEAD:internal/billing/invoice.go`, the left winbar reads ` 4ccefde · main` and the right winbar contains `e325463 · HEAD`, the shown spec has `committed = true` and `actionable = false`, and neither diff window shows the buffer of the working-tree `invoice.go`

#### Scenario: Branch tab shows a commit's diff
- **WHEN** the cursor is on the `invoice.go` row under `e325463` in the commit view and 100 ms pass
- **THEN** the diff view's left lines equal `git show e325463^:internal/billing/invoice.go`, its right lines equal `git show e325463:internal/billing/invoice.go`, the left winbar reads ` 07cb52e · parent` and the right winbar contains `e325463 · wire tax into Total`

#### Scenario: Branch tab shows an added file
- **WHEN** the cursor moves onto the `tax.go` row of the Branch tab and 100 ms pass
- **THEN** the diff view's left side is empty and its right lines equal `git show HEAD:internal/billing/tax.go`

#### Scenario: Branch tab ]f steps through the branch files
- **WHEN** the Branch tab shows the diff of `invoice.go`, focus moves to the right diff window and `]f` is pressed three times in normal mode
- **THEN** the diff view shows `invoice_test.go`, `tax.go` and `tax_test.go` in that order and the panel cursor ends on the `tax_test.go` row

#### Scenario: Branch tab Enter opens the working file
- **WHEN** the Branch tab shows the diff of `tax.go` and `<CR>` is pressed in normal mode on the `tax.go` row
- **THEN** no `gleb-diff` window remains, the current window edits the working-tree `internal/billing/tax.go`, and the `gleb-changes` window is still open on the Branch tab

#### Scenario: Branch tab ignores staging keys
- **WHEN** the cursor is on the `invoice.go` row of the Branch tab and `<Space>`, `A` and `X` are pressed in normal mode
- **THEN** `git diff --cached --name-only` output is unchanged, no prompt opens and no file changes on disk

### Requirement: Branch tab refresh
The Branch tab SHALL rebuild with the Local tab's refresh triggers and whenever `gleb.git.base` reports a new HEAD, base or pull request, keeping the cursor on the same path and the fold and view state; stale results SHALL be dropped by generation.

#### Scenario: Branch tab refreshes after a commit
- **WHEN** the Branch tab of the `billing-branch` fixture is shown and `git add notes.md && git commit -m "notes"` runs in the repository, followed by `:checktime`
- **THEN** within the integration async wait budget the strip reads `Local 2` and `Branch 5`, the summary row reads `4 commits · merge-base 4ccefde`, and `notes.md` is a file row of the Branch tab

#### Scenario: Branch refresh preserves expanded commit files
- **WHEN** an older commit is expanded in the Branch commit view and `FocusGained` refreshes the panel
- **THEN** the commit stays expanded with all of its file rows

#### Scenario: Branch tab follows the current branch base
- **WHEN** the Branch tab of the `billing-branch` fixture is shown, changes are stashed, `main` is checked out and `:checktime` runs, then `feat/tax` is checked out and `:checktime` runs again
- **THEN** the panel switches to Local and removes Branch on `main`, then makes Branch available with its current count on `feat/tax`

### Requirement: Changes tab actions
`changes.show_local` ("Show Local Changes"), `changes.show_branch` ("Show Branch Changes") and `changes.show_branch_commits` ("Show Branch Commits") SHALL be in category `View | Tool Windows` with no key, opening or focusing the panel on that tab (the last with the commit view). Without a Branch tab the latter two SHALL notify `No branch changes on <branch>` at WARN and change nothing. `changes.toggle_commits` ("Toggle Commits", `gleb-changes`) SHALL be on `c`.

#### Scenario: Tab actions are in the catalog
- **WHEN** the action catalog is read after startup
- **THEN** it holds `changes.show_local`, `changes.show_branch` and `changes.show_branch_commits` with the titles above in category `View | Tool Windows` and no `settings/keymap.json` assignment, and `changes.toggle_commits` titled `Toggle Commits` in category `Changes` scoped to `gleb-changes` and assigned `c`

#### Scenario: Show Branch Commits opens the commit view
- **WHEN** `internal/billing/invoice.go` of the `billing-branch` fixture is edited, no panel is open and the `changes.show_branch_commits` action runs
- **THEN** the `gleb-changes` window is current, the Branch tab is active and its third row is the `All changes` row

#### Scenario: Show Branch on the default branch
- **WHEN** the Local tab of the `billing` fixture (on `main`) is open and the `changes.show_branch` action runs
- **THEN** `No branch changes on main` is notified at WARN, the Local tab is still active and the panel's lines are unchanged

### Requirement: Changes tab state
While Neovim runs, the active tab, the Branch tab's view (files or commits) and its fold states SHALL be kept per repository root and reused when the panel reopens there through `changes.toggle` or a tab action; `changes.review` on a closed panel SHALL still apply the first-tab rule.

#### Scenario: Toggle reopens the last tab
- **WHEN** the commit view of the `billing-branch` fixture's Branch tab is shown, `q` is pressed in normal mode in the panel and the `changes.toggle` action runs
- **THEN** the Branch tab is active and its third row is the `All changes` row

#### Scenario: Review starts the cycle again after a close
- **WHEN** the Branch tab of the `billing-branch` fixture is shown, `q` closes the panel and the `changes.review` action runs
- **THEN** the Local tab is active

#### Scenario: Tab actions reopen saved state
- **WHEN** a commit is collapsed in the commit view of the `billing-branch` fixture, `q` closes the panel and each Changes tab action reopens it
- **THEN** `changes.show_branch` and `changes.show_branch_commits` reuse the commit view and collapsed commit, while `changes.show_local` reuses the saved folds on the Local tab

## MODIFIED Requirements

### Requirement: Changes panel review
The `changes.review` action SHALL open the changes panel when it is closed, on the tab chosen by "Changes tab cycle" (cursor on the current file's row, else the first file row), and show the diff of the row under the cursor at once. When the panel is open, it SHALL move to the next tab or close the panel as "Changes tab cycle" requires.

#### Scenario: Changes panel review shows the current file's diff
- **WHEN** `internal/billing/invoice.go` of the `billing` fixture is edited and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current with its cursor on `invoice.go`, and within 100 ms the editor area shows the diff view of `internal/billing/invoice.go`

#### Scenario: Changes panel review without a changed current file
- **WHEN** `:enew` is current in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the panel cursor is on the `c.lua` row and the diff view shows `lib/c.lua`

#### Scenario: Changes panel review replaces the dashboard
- **WHEN** Neovim starts on the Alpha dashboard in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current, the diff view shows `lib/c.lua`, and no window displays an `alpha` buffer

### Requirement: Changes panel diff view
After a 50 ms debounce, the panel SHALL asynchronously build a full `gleb.diff.view.Spec` for the selected file, with normalized root, repo-relative path, filetype, final-newline state and left text from `HEAD:<orig or path>`. Root and selection generations SHALL drop stale results. One panel-owned view SHALL be reused without changing focus or tab; other rows keep the last diff.

#### Scenario: Changes panel j shows the next file in the diff view
- **WHEN** the changes panel on the `billing` fixture has its cursor on `invoice.go`, `j` is pressed in normal mode and 100 ms pass
- **THEN** the editor area shows the diff view of `internal/billing/invoice_test.go` (left: its `HEAD` lines, right: its working-tree lines), the tab page count is unchanged and the current window's filetype is `gleb-changes`

#### Scenario: Changes panel debounces rapid moves
- **WHEN** the cursor is on `invoice.go` and `j` is pressed twice within 50 ms in normal mode in the changes panel on the `billing` fixture, and 100 ms pass
- **THEN** the diff view shows `internal/billing/tax.go` and was never shown for `invoice_test.go`

#### Scenario: Changes panel shows an untracked file as added
- **WHEN** the cursor moves onto the `new.txt` row of the changes panel on the `dirty` fixture and 100 ms pass
- **THEN** the diff view's left side is empty and its right side holds `new`, `untracked`, `file`

#### Scenario: Changes panel shows a deleted file
- **WHEN** in a repository whose committed `a.txt` holds `one`, `a.txt` is deleted from disk, the changes panel is opened, the cursor moves onto the `a.txt` row and 100 ms pass
- **THEN** the diff view's left side holds `one` and its right side is empty

#### Scenario: Changes panel keeps the diff on a directory row
- **WHEN** the diff view shows `lib/c.lua` of the `dirty` fixture and `k` moves the panel cursor onto the `lib 1` row
- **THEN** after 100 ms the diff view still shows `lib/c.lua`

#### Scenario: Changes panel with the diff view matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing` fixture and the `changes.review` action runs
- **THEN** columns 1-36 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Local only on main", text and colour mask, and columns 37-100 equal the same diff shown in a regular 64-column editor window

#### Scenario: Changes panel drops a stale diff result
- **WHEN** loading `a.txt` from HEAD is delayed, the panel cursor moves to `b.txt`, and both asynchronous loads finish
- **THEN** the diff view shows `b.txt` and is never replaced by the stale `a.txt` result

#### Scenario: Changes panel skips an unchanged selection
- **WHEN** the diff view already shows `a.txt` and refresh keeps the panel cursor on the same `a.txt` path
- **THEN** the diff view's show function is not called again

### Requirement: Changes panel screen
The changes panel SHALL match the approved IntelliJ commit-tree render, under its tab strip.

#### Scenario: Changes panel matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh copy of the `billing` fixture and the `changes.toggle` action runs
- **THEN** columns 1-36 of screen rows 2-12 match rows 2-12 of the git-changes-tabs design.md "Proposed — Local only on main", text and colour mask
