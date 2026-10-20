# Spec Delta

## MODIFIED Requirements

### Requirement: Tests are robust under load
Every test SHALL pass the same way on a loaded host: event or state waits, never fixed sleeps or bare wall-clock windows; performance by operation counts or CPU time inside one call; load-scaled timeouts; product timing driven through test hooks. implement.md and fix.md SHALL state it, review.md SHALL make a violating new or edited test `[must-fix]`, and a flaky case SHALL be fixed or deleted with its scenario, never kept on reruns.

#### Scenario: Agents keep tests robust under load
- **WHEN** implement.md, fix.md, review.md and docs/testing.md are read
- **THEN** implement.md and fix.md say a flaky case is a bug to fix, never a rerun to rely on; review.md lists test robustness as a check; docs/testing.md has a `Robust tests` section that allows deleting a case with its scenario only when its intent cannot be tested deterministically

#### Scenario: Known flaky cases use deterministic readiness
- **WHEN** the scenario-named actions, references, file-tree, diff, git, and keymaps cases in this change run under the parallel gate's loaded-host conditions
- **THEN** every case passes by observing its required event or settled state with load-scaled unavoidable timeouts, without fixed sleeps, bare wall-clock windows, rerun dependence, or weakened assertions
