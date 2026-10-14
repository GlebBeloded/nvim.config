## ADDED Requirements

### Requirement: Quick routes reference existing config files
Every literal `lua/gleb` file path routed by `tests/quick.sh` SHALL exist in the repository.

#### Scenario: Literal quick routes exist
- **WHEN** the literal `lua/gleb` file routes in `tests/quick.sh` are checked against the worktree
- **THEN** every routed file exists
