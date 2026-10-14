## ADDED Requirements

### Requirement: Pending file tree work does not override a toggle
The smart neo-tree toggle SHALL preserve the requested close or source switch when work from an earlier filesystem open or refresh completes afterward.

#### Scenario: Toggle wins over pending filesystem render
- **WHEN** the focused neo-tree `filesystem` window still has a pending render and `<A-e>` or `<A-G>` is pressed in normal mode
- **THEN** after the pending render completes, `<A-e>` leaves no neo-tree window and `<A-G>` leaves the focused neo-tree source as `git_status`
