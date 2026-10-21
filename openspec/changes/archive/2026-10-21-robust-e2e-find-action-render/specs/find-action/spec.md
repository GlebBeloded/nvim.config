## MODIFIED Requirements

### Requirement: Find Action survives restart
The complete physical-key workflow SHALL open, search, run, assign, and use an action through the real terminal stack. Its palette expectations SHALL derive registry-dependent rows and totals from the live child action catalog while preserving checks of the stable workflow chrome. A saved shortcut SHALL still run the action after Neovim restarts.

#### Scenario: Physical Find Action workflow persists an assignment
- **WHEN** real keys open Find Action, search and run an action, assign another physical shortcut, use it, restart Neovim, and use it again
- **THEN** every action runs, the assignment survives the restart, and captured workflow states match expectations derived from the live action registry
