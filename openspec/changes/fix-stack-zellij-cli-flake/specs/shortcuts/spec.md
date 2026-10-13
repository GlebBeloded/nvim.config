## ADDED Requirements

### Requirement: The stack harness retries transient zellij CLI failures
The stack harness SHALL read zellij state through `zellij action` calls that retry zellij's transient CLI failures (`There is no active session!`, or `list-clients` with no client row) until a valid answer or a bounded deadline, so a case fails only when the session or its client is really gone.

#### Scenario: The stack harness retries a transient zellij CLI failure
- **WHEN** `focused_pane()` of a `tests.shortcuts.stack` Stack is called with `zellij` stubbed on `PATH` so that `action list-clients` first exits 1 printing `There is no active session!`, then exits 0 with only the header line, then prints a client row on `terminal_0`
- **THEN** it returns `terminal_0` and the stub was called 3 times

#### Scenario: The stack harness fails when the zellij session stays gone
- **WHEN** `focused_pane()` is called with `zellij` stubbed on `PATH` so that every `action list-clients` exits 1 printing `There is no active session!`
- **THEN** it raises an error containing `There is no active session!` within the harness deadline
