## MODIFIED Requirements

### Requirement: Go references workflow
In a Go module, `gr` in Normal mode SHALL open the Find Usages view for the symbol under the cursor, listing every reference reported by gopls across all packages of the module except the declaration, and opening a usage SHALL open its file with the cursor on the reference.

#### Scenario: References of a Go function list call sites across packages
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration and gopls attached, and `g` `r` is pressed as a real key press
- **THEN** the Find Usages view is open and its usage rows are exactly the fixture manifest's locations of `Format` except the declaration: the call sites in `internal/money/money_test.go`, `billing/invoice.go` (two) and `report/summary.go`

#### Scenario: Selecting a reference opens its file at the call site
- **WHEN** in that view the cursor is moved to the usage row in `report/summary.go` and Return is pressed as real key presses
- **THEN** the view is closed, the current buffer is `report/summary.go` of the fixture copy, and the cursor is at the manifest's line and column of the `Format` call in that file
