## ADDED Requirements

### Requirement: Concurrent sandbox runs never share the guest
Every `tests/sandbox/sandbox.sh` command that changes the guest (`up`, `provision`, `down`, `e2e`, `ssh`) SHALL hold one host-side lock (`$SANDBOX_STATE/lock`, an `mkdir` lock that records its owner) for its whole run, so an e2e run's sync, guest restore and `make e2e-local` all see only its own checkout. A run that finds the lock held waits and says so. A lock whose owner process no longer exists is reclaimed.

#### Scenario: The sandbox lock is taken when free and released by its owner
- **WHEN** `sandbox_lock <dir>` from `tests/sandbox/lock.sh` runs in a bash process with no lock at `<dir>`, and that process then exits
- **THEN** while it runs, `<dir>` exists and its `owner` file names that process's pid; after it exits, `<dir>` no longer exists

#### Scenario: A second sandbox lock waits for the first and says so
- **WHEN** one bash process holds `sandbox_lock <dir>` and a second process calls `sandbox_lock <dir>`, and the first process exits 2 s later
- **THEN** the second process prints `sandbox: waiting for` and the first's pid on stderr, does not return from `sandbox_lock` before the first exits, and then holds `<dir>` with its own pid as owner

#### Scenario: A sandbox lock left by a dead process is reclaimed
- **WHEN** `<dir>` exists with an `owner` file naming a pid that no longer runs, and `sandbox_lock <dir>` is called
- **THEN** it returns within 2 s, prints `sandbox: reclaiming stale lock` on stderr, and `<dir>/owner` names the caller's pid

#### Scenario: A sandbox lock wait gives up after SANDBOX_LOCK_TIMEOUT
- **WHEN** a live process holds `<dir>` and another calls `sandbox_lock <dir>` with `SANDBOX_LOCK_TIMEOUT=1`
- **THEN** the caller exits non-zero within 5 s, with the holder's pid in its stderr, and `<dir>/owner` still names the holder

#### Scenario: sandbox.sh e2e holds the sandbox lock from the sync to the end of the e2e layer
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with `lume`, `ssh` and `rsync` stubbed (VM running, provisioned, GUI session up), and the stubs log whether `$SANDBOX_STATE/lock` exists at each call
- **THEN** the lock exists at the repo sync and at `make -s e2e-local`, and after `sandbox.sh` exits it no longer exists

#### Scenario: sandbox.sh e2e waits while another checkout holds the sandbox lock
- **WHEN** a live process holds `$SANDBOX_STATE/lock` and `tests/sandbox/sandbox.sh e2e` starts with the same stubs, and the holder exits 2 s later
- **THEN** no `rsync` is logged while the holder lives, stderr says `sandbox: waiting for`, and after the holder exits the run syncs, restores and runs `make -s e2e-local`, then exits 0

### Requirement: Test harness deadlines scale with host load
The stack harness deadlines (`M.wait_for` default, zellij CLI retry) and the smoke startup budget SHALL be multiplied by the host load factor `max(1, 1-min load average / CPU count)` from `tests/helpers.lua`. An idle host (load ≤ CPU count) keeps the unscaled values exactly.

#### Scenario: The load factor is 1 on an idle host
- **WHEN** `H.load_factor()` is called in a child with `vim.uv.loadavg` returning `7, 7, 7` and `vim.uv.available_parallelism` returning `14`
- **THEN** it returns `1`

#### Scenario: The load factor is the load per CPU on a busy host
- **WHEN** `H.load_factor()` is called with `vim.uv.loadavg` returning `70, 60, 50` and `vim.uv.available_parallelism` returning `14`
- **THEN** it returns `5`

#### Scenario: The stack harness wait stretches with host load
- **WHEN** `M.wait_for` from `tests.shortcuts.stack` polls a predicate that turns true 600 ms after the call, with timeout 300 ms and `vim.uv.loadavg` returning a load of 3 times `available_parallelism()`
- **THEN** it returns without error

#### Scenario: The stack harness wait keeps its timeout on an idle host
- **WHEN** `M.wait_for` polls a predicate that turns true 600 ms after the call, with timeout 300 ms and `vim.uv.loadavg` returning `0, 0, 0`
- **THEN** it raises an error containing `stack: timed out waiting for`

#### Scenario: The smoke startup budget scales with host load only when busy
- **WHEN** `startup_budget(400)` from `tests/smoke/budget.lua` is called with a load factor of 1, then of 3
- **THEN** it returns `400`, then `1200`
