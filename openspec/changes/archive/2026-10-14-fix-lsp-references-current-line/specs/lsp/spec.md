# Spec Delta

## MODIFIED Requirements

### Requirement: Go references workflow
In a Go module, `gr` in Normal mode SHALL open the Telescope references picker for the symbol under the cursor, listing the declaration and every reference reported by gopls across all packages of the module, including reported locations on the cursor's current line, and selecting an entry SHALL open its file with the cursor on the reference.

#### Scenario: References of a Go function list call sites across packages
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration and gopls attached, and `g` `r` is pressed as a real key press
- **THEN** the Telescope references picker is open and its entries are exactly the fixture manifest's locations of `Format`: the declaration under the cursor plus the call sites in `internal/money/money_test.go`, `billing/invoice.go` (two) and `report/summary.go`

#### Scenario: Selecting a reference opens its file at the call site
- **WHEN** in that picker `summary` is typed into the prompt and Return is pressed as real key presses
- **THEN** the picker is closed, the current buffer is `report/summary.go` of the fixture copy, and the cursor is at the manifest's line and column of the `Format` call in that file
