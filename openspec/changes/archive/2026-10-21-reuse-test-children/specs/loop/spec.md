# Spec Delta

## MODIFIED Requirements

### Requirement: Test tooling the agents run is exact
a test child SHALL exit when its test worker is gone, `make test FILE=<directory>` SHALL run that directory's test files, and the hard-rule checks (`.archon/scripts/integrity.py`) SHALL stage into a private index, leaving the worktree's index as the agent left it. Test sets SHALL start a fresh child per case by default and MAY explicitly reuse one child when the harness restores buffers, tabs, cwd and test globals before every later case.

#### Scenario: A test child outlives no killed worker
- **WHEN** a worker Neovim starts a test child through `tests/helpers.lua` and the worker is killed with SIGKILL
- **THEN** the child process exits within 10 s

#### Scenario: A test worker outlives no killed run
- **WHEN** `tests/parallel.lua` runs one worker (`JOBS=1`) on a test file whose case waits forever, and the run is killed with SIGKILL
- **THEN** the worker process exits within 10 s

#### Scenario: A test directory runs its files
- **WHEN** `tests/runner.lua` collects with `FILE` set to a directory holding a nested test file and a non-test file
- **THEN** it returns the test files under it, sorted, and not the other file

#### Scenario: Hard-rule checks leave the real index alone
- **WHEN** `integrity.py` diffs a repo with a new untracked test file
- **THEN** the diff includes the new file and `git diff --cached` in the repo stays empty

#### Scenario: Reusable child resets case state
- **WHEN** a test set opts into one child per file and its first case opens buffers and tabs, changes cwd, and sets test globals
- **THEN** its next case runs in the same child process with the original cwd, one clean tab and buffer, and no globals left by the first case

#### Scenario: Fresh child remains the default
- **WHEN** two cases run in a test set that does not opt into child reuse
- **THEN** each case runs in a different child process

## ADDED Requirements

### Requirement: Config enables cached Lua loading first
The configuration SHALL enable Neovim's cached Lua loader before it requires any configuration module.

#### Scenario: Cached loader precedes configuration modules
- **WHEN** a full-config child records cached-loader activation and the first configuration module load during startup
- **THEN** cached-loader activation is recorded first
