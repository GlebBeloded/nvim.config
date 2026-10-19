## MODIFIED Requirements

### Requirement: Changes panel review
The `changes.review` action SHALL open the changes panel when it is closed (cursor on the current file's row, else the first file row), focus it when open, and show the diff of the row under the cursor at once. When run from the dashboard, the panel-owned diff SHALL replace the dashboard window.

#### Scenario: Changes panel review shows the current file's diff
- **WHEN** `internal/billing/invoice.go` of the `billing` fixture is edited and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current with its cursor on `invoice.go`, and within 100 ms the editor area shows the diff view of `internal/billing/invoice.go`

#### Scenario: Changes panel review without a changed current file
- **WHEN** `:enew` is current in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the panel cursor is on the `c.lua` row and the diff view shows `lib/c.lua`

#### Scenario: Changes panel review replaces the dashboard
- **WHEN** Neovim starts on the Alpha dashboard in a copy of the `dirty` fixture and the `changes.review` action runs
- **THEN** the `gleb-changes` window is current, the diff view shows `lib/c.lua`, and no window displays an `alpha` buffer
