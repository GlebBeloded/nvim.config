# Spec Delta

## MODIFIED Requirements

### Requirement: Changes tab actions
The three Show actions SHALL remain unbound `View | Tool Windows` actions that open their named tab, with Branch actions warning when unavailable. `changes.toggle_commits` SHALL remain `Toggle Commits` on `c`. The Changes-panel action catalog SHALL NOT contain `changes.copy_commit_url`.

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
- **WHEN** the populated action catalog is read after startup and Find Action opens from the `e325463` row in the populated Branch commit view
- **THEN** `changes.copy_commit_url` is absent from the catalog and the picker

#### Scenario: Copy Commit URL is absent away from commit rows
- **WHEN** Find Action opens from a file row or from the Branch files view
- **THEN** `changes.copy_commit_url` is absent

## ADDED Requirements

### Requirement: File URL action
The catalog SHALL contain an unbound `git.copy_file_url` action titled `Copy File URL` in category `Git`. Find Action SHALL list it in normal and visual file-buffer contexts whether it has no shortcut or an assigned shortcut.

#### Scenario: Copy File URL remains listed with and without a shortcut
- **WHEN** `<M-A>` opens Find Action from a normal or visual file buffer before and after a shortcut is assigned to `git.copy_file_url`
- **THEN** the picker lists `git.copy_file_url` as `Copy File URL` in category `Git` and shows the assigned shortcut only when present

### Requirement: Branch file URL copying
`git.copy_file_url` SHALL copy to register `+` an `origin` GitHub-style blob URL for the current repository-relative file, attached local branch, and current line or inclusive visual line range. It SHALL normalize HTTPS, `ssh://`, and SCP-like remotes without allowlisting hosts and SHALL preserve `/` separators while URL-encoding unsafe branch and path bytes.

#### Scenario: github.com current-line branch URL is copied
- **WHEN** `git.copy_file_url` runs through the real picker in normal mode on line 2 of tracked file `a.txt`, on branch `feature/share`, with `origin` set to `git@github.com:owner/repo.git`
- **THEN** register `+` is `https://github.com/owner/repo/blob/feature/share/a.txt#L2`

#### Scenario: Enterprise GitHub current-line branch URL is copied
- **WHEN** `git.copy_file_url` runs through the real picker in normal mode on line 10 of tracked file `internal/billing/invoice.go`, on branch `feat/tax`, with `origin` set to `git@pgw.dev:finteqhub/billing.git`
- **THEN** register `+` is `https://pgw.dev/finteqhub/billing/blob/feat/tax/internal/billing/invoice.go#L10`

#### Scenario: Visual selection copies an ordered line range
- **WHEN** lines 5 through 3 of a tracked file are selected in visual mode and `git.copy_file_url` runs through the real picker
- **THEN** register `+` contains the attached-branch blob URL ending in `#L3-L5`

#### Scenario: A branch without an upstream is copied
- **WHEN** `git.copy_file_url` runs on attached local branch `topic/local-only` with an `origin` remote but no configured upstream
- **THEN** register `+` contains a blob URL whose branch component is `topic/local-only`

### Requirement: Unavailable branch file URL
If `origin`, an attached branch, the repository-relative file, or a tracked file is unavailable, `git.copy_file_url` SHALL notify at ERROR with the unavailable input, leave register `+` unchanged, and SHALL NOT require or create an upstream.

#### Scenario: Unavailable file URL input preserves the clipboard
- **WHEN** `git.copy_file_url` runs through the real picker with register `+` set, once without `origin`, once at detached HEAD, and once on an untracked file
- **THEN** each run leaves register `+` unchanged and emits an ERROR notification identifying the unavailable input

## REMOVED Requirements

### Requirement: Commit URL copying
**Reason**: The user requested a current-file URL at the attached branch rather than a Changes-panel commit URL.

**Migration**: Use `git.copy_file_url` from Find Action in a normal or visual file buffer.
