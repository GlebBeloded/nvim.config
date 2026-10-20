## ADDED Requirements

### Requirement: Pull request component
Section b SHALL show, right after the branch, U+F407 ` #<n>` in `PrStatuslineNumber` (purple) when the root of the current file (else of the cwd) has an open pull request, then two spaces and U+F0188 ` <k>` in `PrStatuslineThreads` (yellow) when its cached review has k > 0 open threads; without a pull request, nothing. Both groups SHALL use the bar background. The component SHALL read caches only and run no command on redraw.

#### Scenario: Statusline shows the pull request and its open threads
- **WHEN** `internal/billing/invoice.go` of the `billing-branch` fixture is edited with the `pr482` responses served and `GlebPrThreads` has fired
- **THEN** the statusline row contains `feat/tax` followed by U+F407 ` #482  ` U+F0188 ` 3`

#### Scenario: Statusline shows the number before the threads load
- **WHEN** the same file is edited while the fake `gh` answers `query ReviewThreads` only after 3 s, and the base has resolved
- **THEN** the statusline row contains U+F407 ` #482` and no U+F0188

#### Scenario: Statusline hides the pull request component without a PR
- **WHEN** the fake `gh` reports no pull request and `internal/billing/invoice.go` of the `billing-branch` fixture is edited
- **THEN** the statusline row contains `feat/tax` and neither U+F407 nor U+F0188

#### Scenario: Statusline pull request component runs nothing on redraw
- **WHEN** the component is shown, `vim.system` is wrapped with a counter in the child and `:redrawstatus` runs ten times
- **THEN** the counter is 0

#### Scenario: Statusline pull request colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `PrStatuslineNumber` has `fg` purple and `PrStatuslineThreads` `fg` yellow, both with the `bg` of `lualine_b_normal`

#### Scenario: Statusline with a pull request matches the approved render
- **WHEN** the approved peek screen of the pr-comments-view design.md is shown
- **THEN** its statusline row matches the approved render "Proposed — statusline (r3_status_threads)", text and colour mask
