## MODIFIED Requirements

### Requirement: Probe runs Lua in a test child
`make probe` SHALL run a Lua snippet (`SCRIPT=<file>` or `PROBE=<code>`) in a headless full-config child started like the tests' (`H.new_child` + `start_config`), print its prints and return values, exit non-zero on error and after a timeout. implement, fix and explore-bug prompts and the context pack SHALL point probes at it and say LSP restart and tree and panel renders are async: wait for the end state.

#### Scenario: Probe prints the snippet's return value
- **WHEN** `make probe PROBE='return vim.g.mapleader'` runs
- **THEN** it exits 0 and prints the leader through `vim.inspect`

#### Scenario: Probe exits non-zero on an error
- **WHEN** `make probe SCRIPT=<file>` runs a script that prints a line and then errors
- **THEN** it prints the line, writes the error to stderr and exits non-zero

#### Scenario: Agent prompts and context pack point probes at make probe
- **WHEN** implement.md, fix.md, explore-bug.md and a built context pack are read
- **THEN** each names `make probe` and says LSP restart and tree and panel renders are async: wait for the end state, not for attachment
