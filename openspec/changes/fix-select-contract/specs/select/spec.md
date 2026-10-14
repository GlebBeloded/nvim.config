# Spec Delta

## ADDED Requirements

### Requirement: Selection completion contract
The selection interface SHALL accept omitted options and SHALL complete a cancelled code-action selection by invoking its choice callback exactly once with both arguments `nil`.

#### Scenario: Selection accepts omitted options
- **WHEN** `vim.ui.select({ "x" }, nil, on_choice)` is called
- **THEN** the selection request proceeds without raising an error

#### Scenario: Cancelling a code action completes selection
- **WHEN** a code-action selection opened by `vim.ui.select(items, { kind = "codeaction" }, on_choice)` receives `<Esc>` in Normal mode
- **THEN** `on_choice` is called exactly once with `(nil, nil)`
