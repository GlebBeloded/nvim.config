## MODIFIED Requirements

### Requirement: Find Usages view opens on gr
Normal-mode `gr` SHALL request `textDocument/references` (declaration excluded) from the attached clients that support it and open the Find Usages view for the symbol under the cursor. A client that refuses the request SHALL count as returning no usages and SHALL NOT prevent accepted requests from completing. When no attached client supports references, or no usages are returned, it SHALL notify at INFO level (`No LSP references support` / `No usages found`) and open no window.

#### Scenario: gr opens the view in a Go module
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration, gopls attached, and `gr` is pressed in normal mode
- **THEN** a Find Usages view is open whose top border title is `Usages of Format · 4`

#### Scenario: gr with no usages notifies and opens nothing
- **WHEN** the cursor is on a local variable that has no usages and `gr` is pressed in normal mode
- **THEN** `No usages found` is notified at INFO level and the window count is unchanged

#### Scenario: gr without a references-capable client notifies
- **WHEN** a buffer with no attached LSP client is current and `gr` is pressed in normal mode
- **THEN** `No LSP references support` is notified at INFO level and the window count is unchanged

#### Scenario: gr continues when one client refuses the request
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration, two references-capable clients attached, one client refuses its `textDocument/references` request, and `gr` is pressed in normal mode
- **THEN** a Find Usages view is open whose top border title is `Usages of Format · 4`
