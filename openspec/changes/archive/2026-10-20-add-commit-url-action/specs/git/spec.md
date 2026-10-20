## MODIFIED Requirements

### Requirement: Changes tab actions
The three Show actions SHALL remain unbound `View | Tool Windows` actions that open their named tab, with Branch actions warning when unavailable. `changes.toggle_commits` SHALL remain `Toggle Commits` on `c`. `changes.copy_commit_url` SHALL be an unbound `Changes` action named `Copy Commit URL`, scoped to `gleb-changes` and available only when a Branch commit row is selected.

#### Scenario: Tab actions are in the catalog
- **WHEN** the action catalog is read after startup
- **THEN** it holds `changes.show_local`, `changes.show_branch` and `changes.show_branch_commits` with the titles above in category `View | Tool Windows` and no `settings/keymap.json` assignment, and `changes.toggle_commits` titled `Toggle Commits` in category `Changes` scoped to `gleb-changes` and assigned `c`

#### Scenario: Show Branch Commits opens the commit view
- **WHEN** `internal/billing/invoice.go` of the `billing-branch` fixture is edited, no panel is open and the `changes.show_branch_commits` action runs
- **THEN** the `gleb-changes` window is current, the Branch tab is active and its third row is the `All changes` row

#### Scenario: Show Branch on the default branch
- **WHEN** the Local tab of the `billing` fixture (on `main`) is open and the `changes.show_branch` action runs
- **THEN** `No branch changes on main` is notified at WARN, the Local tab is still active and the panel's lines are unchanged

#### Scenario: Copy Commit URL is offered for a commit row
- **WHEN** Find Action opens from the `e325463` row in the populated Branch commit view
- **THEN** it offers `changes.copy_commit_url` as `Copy Commit URL` in category `Changes` with no assigned shortcut

#### Scenario: Copy Commit URL is absent away from commit rows
- **WHEN** Find Action opens from a file row or from the Branch files view
- **THEN** `changes.copy_commit_url` is absent

## ADDED Requirements

### Requirement: Commit URL copying
`changes.copy_commit_url` SHALL read the selected commit's full hash and the repository's `origin`, normalize HTTPS, `ssh://` and SCP-like remotes to `https://<host>[:port]/<owner>/<repo>`, append `/commit/<full-sha>`, and copy the result to register `+`. Hostnames SHALL not be allowlisted. If `origin` is absent or unsupported, it SHALL notify at ERROR and leave register `+` unchanged.

#### Scenario: github.com commit URL is copied
- **WHEN** `changes.copy_commit_url` runs on a commit row in a repository whose `origin` is `git@github.com:octo/example.git`
- **THEN** register `+` is `https://github.com/octo/example/commit/<full-sha>` for that row

#### Scenario: Enterprise GitHub commit URL is copied
- **WHEN** `changes.copy_commit_url` runs on the `e325463` row of the `billing-branch` fixture whose `origin` is `git@pgw.dev:finteqhub/billing.git`
- **THEN** register `+` is `https://pgw.dev/finteqhub/billing/commit/<full-sha>` for that row

#### Scenario: Missing origin preserves the clipboard
- **WHEN** `changes.copy_commit_url` runs on a commit row in a repository without an `origin` remote
- **THEN** register `+` is unchanged and an ERROR notification explains that the commit URL could not be copied
