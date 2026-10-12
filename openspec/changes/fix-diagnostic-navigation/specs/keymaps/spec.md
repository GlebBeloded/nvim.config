## MODIFIED Requirements

### Requirement: Diagnostic navigation
The config SHALL map `<A-w>` and `ge` in normal mode to jump to the next diagnostic and `[d` to jump to the previous diagnostic, using `vim.diagnostic.jump` with `count` `1` / `-1` and an `on_jump` callback that opens the diagnostic float, so that each jump opens the float and calls no deprecated API.

#### Scenario: ge jumps to next diagnostic
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 1, and `ge` is pressed in normal mode
- **THEN** the cursor is on line 2

#### Scenario: Alt-w jumps to next diagnostic
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 2, and `<A-w>` is pressed in normal mode
- **THEN** the cursor is on line 4

#### Scenario: [d jumps to previous diagnostic
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 4, and `[d` is pressed in normal mode
- **THEN** the cursor is on line 2

#### Scenario: Diagnostic jump opens float
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 1, and `ge` is pressed in normal mode
- **THEN** a floating window (`relative ~= ""` in `nvim_win_get_config`) exists whose buffer contains the line-2 diagnostic message

#### Scenario: Diagnostic jump is not deprecated
- **WHEN** `vim.deprecate` is replaced by a function that records its first argument, the buffer has diagnostics on lines 2 and 4, the cursor is on line 1, and `ge`, `<A-w>` and `[d` are pressed in normal mode
- **THEN** no call was recorded and the output of `:messages` does not contain `deprecated`
