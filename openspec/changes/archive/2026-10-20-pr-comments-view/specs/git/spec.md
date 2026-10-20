## MODIFIED Requirements

### Requirement: Changes panel tabs
The panel winbar SHALL show one pill per available tab from its ordered descriptor list. Local is always available; Branch is available when the branch has a base; Comments is appended after Branch when it has an open pull request. A pill is ` <Title> <count> `, with `ChangesTab<Title>` while active and `ChangesTabInactive` otherwise. Comments counts cached open review threads, including outdated threads, and starts at 0.

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
- **THEN** columns 1-36 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Local tab", text and colour mask, except its winbar is `  Local 3   Branch 4   Comments 0  ` with Local active and the other tabs inactive

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
- **THEN** columns 1-100 of screen rows 2-29 match the git-changes-tabs design.md "Proposed — Branch tab, files", text and colour mask, except its winbar is `  Local 3   Branch 4   Comments 0  ` with Branch active and the other tabs inactive
