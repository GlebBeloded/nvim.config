## Why

Only Claude Code gets project instructions: the repo root has `CLAUDE.md -> docs/CLAUDE.md` but no `AGENTS.md`, so Pi, Codex and other AGENTS.md readers start blind. And `docs/CLAUDE.md` itself only points to other docs; it never names the loop entry points, the test layers, the sandbox-VM host-safety rule or where user decisions are recorded, so an agent can run e2e on the host or miss a recorded decision.

## What Changes

- Add a root `AGENTS.md` symlink to `docs/CLAUDE.md` (same file, no duplicated text).
- Extend `docs/CLAUDE.md` with how to operate the project: the loop entry points (`make fix`, `feature`, `queue`, `update`, `console`), the `auto`-branch rule, the test layers (`make quick` / `make check`, unit/integration/screen, stack, sandbox-VM e2e) with the rule that key events are never posted on the host, and that user decisions live in the `## Decision` sections of `openspec/changes/*/proposal.md`. It points to `docs/workflow.md` and `docs/testing.md` for detail instead of restating them (rule 10.1).
- Rule 10.3 in `docs/architecture.md` and the README link name the root `CLAUDE.md` and `AGENTS.md` symlinks as aliases of `docs/CLAUDE.md`.

Plugin dependencies: none added, removed or upgraded. Core keymaps: unchanged.

## Capabilities

### New Capabilities

### Modified Capabilities
- `loop`: adds a requirement that every coding agent gets the same project instructions, covering how the loop is operated.

## Impact

`AGENTS.md` (new symlink), `docs/CLAUDE.md`, `docs/architecture.md` (rule 10.3), `README.md`, a new unit test under `tests/unit/loop/`. No Lua config changes.

## Out of scope

- Tool-specific files such as `.pi/` or `.codex/` configs, and any agent other than via `AGENTS.md`.
- Rewriting `docs/workflow.md` or `docs/testing.md`.
- Changing the loop, the gate or the sandbox harness.
