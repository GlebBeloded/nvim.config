# loop Specification

## Purpose

The local AI loop's make targets (`make fix`, `feature`, `queue`, `update`): each runs one Archon workflow on a `loop/*` branch cut from `auto` and tidies up after it.

## Requirements

### Requirement: Shipped run is cleaned up
After its Archon workflow returns, each loop target SHALL run the merged cleanup against a `local/auto` that includes every merge into `auto` made during the run, so the worktree and `loop/*` branch of a run that shipped are removed.

#### Scenario: Cleanup sees the merge the run shipped
- **WHEN** `make fix BUG=x` (and likewise `feature`, `queue`, `update`) is run in a repo with the self-remote `local`, `ARCHON` set to a stub whose `workflow run` merges the run branch into `auto` with `--no-ff`
- **THEN** when the stub is called with `isolation cleanup --merged`, `local/auto` equals `auto` and `git branch --merged local/auto` lists the run's `loop/*` branch

### Requirement: Agents share the project instructions
The repo root SHALL expose the agent rules as both `CLAUDE.md` and `AGENTS.md`, each a symlink to `docs/CLAUDE.md`, and `docs/CLAUDE.md` SHALL tell an agent how to operate the project: the loop entry points, the `auto`-branch rule, the test layers including the sandbox-VM e2e and its host-safety rule, and where user decisions are recorded.

#### Scenario: AGENTS.md resolves to the agent rules
- **WHEN** `vim.uv.fs_readlink` and `vim.uv.fs_realpath` are called on `AGENTS.md` and `CLAUDE.md` at the repo root
- **THEN** both are symlinks and both real paths equal the real path of `docs/CLAUDE.md`

#### Scenario: Agent rules cover how to operate the loop
- **WHEN** `docs/CLAUDE.md` is read with `vim.fn.readfile`
- **THEN** it contains `make fix`, `make feature`, `make queue`, `make update`, `make console`, the integration branch `` `auto` ``, `make quick`, `make check`, `make e2e`, the sandbox VM with the rule that key events are never posted on the host, and `openspec/changes/*/proposal.md` with its `Decision` sections
