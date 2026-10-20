# Spec Delta

## MODIFIED Requirements

### Requirement: Test harness deadlines scale with host load
The child-Neovim wait default, stack-harness deadlines and smoke startup budget SHALL be multiplied by the host load factor `max(1, 1-min load average / CPU count)` from `tests/helpers.lua`. Explicit asynchronous waits in affected performance and LSP tests SHALL use the same factor. An idle host keeps unscaled values exactly.

#### Scenario: The load factor is 1 on an idle host
- **WHEN** `H.load_factor()` is called in a child with `vim.uv.loadavg` returning `7, 7, 7` and `vim.uv.available_parallelism` returning `14`
- **THEN** it returns `1`

#### Scenario: The load factor is the load per CPU on a busy host
- **WHEN** `H.load_factor()` is called with `vim.uv.loadavg` returning `70, 60, 50` and `vim.uv.available_parallelism` returning `14`
- **THEN** it returns `5`

#### Scenario: Child wait default stretches with host load
- **WHEN** `child.wait` polls without an explicit timeout while the host load factor is 3
- **THEN** its 2000 ms default deadline is multiplied by 3

#### Scenario: The stack harness wait stretches with host load
- **WHEN** `M.wait_for` from `tests.shortcuts.stack` polls a predicate that turns true 600 ms after the call, with timeout 300 ms and `vim.uv.loadavg` returning a load of 3 times `available_parallelism()`
- **THEN** it returns without error

#### Scenario: The stack harness wait keeps its timeout on an idle host
- **WHEN** `M.wait_for` polls a predicate that turns true 600 ms after the call, with timeout 300 ms and `vim.uv.loadavg` returning `0, 0, 0`
- **THEN** it raises an error containing `stack: timed out waiting for`

#### Scenario: The smoke startup budget scales with host load only when busy
- **WHEN** `startup_budget(400)` from `tests/smoke/budget.lua` is called with a load factor of 1, then of 3
- **THEN** it returns `400`, then `1200`
