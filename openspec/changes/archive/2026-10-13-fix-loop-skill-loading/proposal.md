## Why
The superpowers skills that loop nodes declare almost never load. In Archon worktrees, 53 of 57 `superpowers:*` Skill calls returned `Unknown skill`, while every `openspec-*` call succeeded. The agents then carried on "manually", so plan, implement, review and explore ran without writing-plans, TDD, code review or debugging discipline (root cause: `artifacts/runs/ac9fca00-…/root-cause.md`).

There are two causes:
- The plugin is installed with `scope: project` for `~/.config/nvim-worktrees/local-loop`, a path that no longer exists. Every Archon worktree is a new project path, so `.claude/settings.json` enables a plugin that is not installed there.
- Archon 0.11.1 treats node `skills:` as an allowlist only. For `plugin:skill` names it only warns, so nothing fails when a declared skill is missing.

Kind: bug

## What Changes
- Install superpowers so it resolves in every loop worktree: `make loop-setup` installs `superpowers@superpowers-marketplace` at user scope when `claude plugin list --json` does not show it loaded.
- Add a preflight script (`.archon/scripts/skills_check.py`) that reads the node `skills:` of a workflow and fails with the names it cannot resolve. A project skill resolves when `.claude/skills/<name>/SKILL.md` exists. A `plugin:skill` resolves when `claude plugin list --json` in the worktree shows that plugin enabled with no `errors`, and `<installPath>/skills/<skill>/SKILL.md` exists. Every workflow runs this script as a `bash` node before its first AI node, and each AI node that declares a plugin skill depends on it.
- In each command, change "Use `superpowers:x`" to a mandatory first step: call the Skill tool for each declared skill before any other work, and stop with an error if one does not load. This covers plan, implement, review, explore-bug, explore-feature, queue-spec and spec-plugin-update.
- Every `superpowers:` skill that a command names must also be declared in its node's `skills:`. Every declared skill must be named in the command.
- `docs/workflow.md`, Setup facts: replace the false "the superpowers plugin … is active" claim with the decision and the preflight.

## Capabilities
### Modified Capabilities
- `loop`: new requirements "Loop commands load the skills their node declares", "Skill preflight fails a run with an unresolved skill" and "Loop setup installs the project's Claude plugins".

## Impact
- Code: `.archon/workflows/*.yaml`, `.archon/commands/*.md`, `.archon/scripts/skills_check.py` (new), `Makefile` (`loop-setup`), `docs/workflow.md`, `tests/unit/loop/`.
- Plugins: no Neovim plugin dependency changes. The Claude Code superpowers plugin moves from project scope to user scope, so it is also enabled in the user's other Claude Code sessions.
- Core keymaps: unchanged.
- Out of scope:
  - Injecting skill text through node `systemPrompt`. In Archon 0.11.1 a node `systemPrompt` replaces the whole `claude_code` preset rather than appending to it, and inlining SKILL.md would vendor a stale copy.
  - Removing Archon's "Claude skills not found on disk: superpowers:…" warning. Archon emits it for every `plugin:skill` name, and only a vendored copy in `.claude/skills/` silences it. It stays, documented as expected.
  - Changing which skills each node uses.

## Decision
Pending user confirmation (autonomous default: proceed). Install superpowers at **user** scope. Project and local scopes are recorded per path, and every Archon run has a new worktree path, so neither survives. The side effect is that superpowers is enabled in all of the user's Claude Code sessions.
