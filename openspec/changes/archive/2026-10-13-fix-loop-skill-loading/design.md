## Context
This is a structural change to the loop's plugin wiring. No UI is involved, so there are no renders. The facts below were checked against the Archon 0.11.1 binary and Claude Code 2.1.296:
- Node `skills:` is passed to the SDK as `options.skills`, which is an allowlist (`Skill github is not in this session's skills allowlist`). Archon checks only `.claude/skills/<n>/SKILL.md`. For `plugin:skill` names it only pushes the warning `claude_skills_unresolved`.
- A node `systemPrompt` (string) becomes `{type: "custom", prompt}`. That replaces the `claude_code` preset; it is not an append.
- Archon does not expose the SDK `plugins` option or `--plugin-dir` to nodes.
- `claude plugin list --json` reports per plugin `scope`, `enabled`, `installPath`, `projectPath` and `errors` (`plugin-not-installed` here).

## Decision: fix the install, enforce with a preflight, load first
Options considered:
- **A. Inject SKILL.md into a node `systemPrompt`.** Rejected. It drops the Claude Code preset (tool guidance, CLAUDE.md), and it needs a copy of the skill text in the repo that goes stale when the plugin updates.
- **B. Vendor the skills into `.claude/skills/`.** Rejected for the same staleness reason. The bug input forbids it.
- **C. User-scope install, a deterministic preflight node, and a mandatory first Skill call in each command.** Picked. The plugin stays the single source. The preflight fails the run in seconds without an LLM call, and the first-step instruction makes loading explicit instead of optional.

The preflight resolves skills from the same data Claude uses (`claude plugin list --json` in the worktree), so it catches scope and path problems like this one. It reads every node's `skills:`, including loop nodes, and reports every unresolved name in a single error.

## Risks
- A user-scope install enables superpowers in every Claude Code session on the machine. This is recorded in the proposal Decision.
- Archon's not-found warning remains. The docs say it is expected and that the preflight is the real check.
