## Why
The loop runs every AI node on Claude, which uses up the Claude subscription. Codex CLI 0.153.4 is logged in with ChatGPT, and Archon 0.11.1 has a `codex` provider. Switching the loop to Codex today would leave the nodes without the skills they rely on. Archon ignores `skills:` for codex and hides Codex's skill list. Codex has no Skill tool, cannot see `.claude/skills` or Claude plugins, and the Codex superpowers plugin is not installed. The skill preflight checks only the Claude side, so it would still pass (root cause: `artifacts/runs/172fb93c-…/root-cause.md`).

Kind: bug

## What Changes
- `.archon/config.yaml`: the default assistant becomes `codex`, with `assistants.codex.model: gpt-5.6-sol` and `modelReasoningEffort: medium`. The `claude` block stays. Switching back is the one line `assistant: claude`.
- The `review` node in `nvim-deliver.yaml` (`superpowers:requesting-code-review`) sets `provider: claude`, so review always runs on a different model from the code it reviews.
- Commands load their declared skills in a provider-neutral way. The first step names each skill as `$<name>` (Codex's explicit invocation, which Archon requires because it hides the skill list) and as `` `<name>` `` for Claude's Skill tool, and stops when one does not load. Skill names stay the same on both providers: the openspec skills are mirrored in `.agents/skills/`, and the Codex superpowers plugin names its skills `superpowers:<skill>`.
- Skill preflight (`.archon/scripts/skills_check.py`) resolves each node's skills for the provider that node runs on. That provider is the node's `provider:`, otherwise the `assistant:` in `.archon/config.yaml`.
  - **claude:** unchanged. A project skill needs `.claude/skills/<name>/SKILL.md`, and a plugin skill is resolved through `claude plugin list --json`.
  - **codex:** a project skill needs `.agents/skills/<name>/SKILL.md`. A `<plugin>:<skill>` needs `codex plugin list --json` to report the plugin installed and enabled, and `<root>/skills/<skill>/SKILL.md` to exist. `<root>` is `source.path` for a local plugin, else the Codex plugin cache `${CODEX_HOME:-~/.codex}/plugins/cache/<marketplaceName>/<name>/<version>` (remote plugins such as `superpowers@openai-curated-remote` report no `source.path`).
- `make loop-setup` also installs every Codex plugin the loop declares, with `codex plugin add superpowers@openai-curated-remote`, when it is not installed.
- `docs/workflow.md` (Setup facts and The loop): how to switch provider, that review stays on claude, how Codex loads skills, and that Archon runs Codex with no sandbox, network on and no approval prompts. So `make check E2E=1` and ssh to the sandbox VM need no extra config. There are no Codex hooks either.
- Before the default flips, a probe run on codex (`archon workflow run` of a one-node workflow, or `make fix` on a trivial queued change) must show that the skills load and `make quick` runs. Its result goes into the PR/merge message, not into the docs.
- New loop test: the configured provider is registered, and every declared skill resolves for its node's provider.

## Capabilities
### Modified Capabilities
- `loop`:
  - "Loop commands load the skills their node declares" becomes provider-neutral (Skill tool or `$name`).
  - "Skill preflight fails a run with an unresolved skill" resolves skills per node provider.
  - "Loop setup installs the project's Claude plugins" also covers Codex plugins.
  - New requirement: "Loop runs on the configured provider with cross-model review".

## Impact
- Code: `.archon/config.yaml`, `.archon/workflows/nvim-deliver.yaml` (review `provider:`), `.archon/commands/*.md` (first step), `.archon/scripts/skills_check.py`, `Makefile` (`loop-setup`), `docs/workflow.md`, `tests/unit/loop/test_skills.lua` and a new provider test in `tests/unit/loop/`.
- Plugins: no Neovim plugin dependency changes. The Codex plugin `superpowers@openai-curated-remote` is installed in the user's Codex config, so it is also available in their other Codex sessions.
- Core keymaps: unchanged.
- AGENTS.md: already loaded by Codex through the `AGENTS.md -> docs/CLAUDE.md` symlink (verified with `codex debug prompt-input`). No change.
- Out of scope:
  - Restricting Codex tools or sandboxing nodes. Archon 0.11.1 has no codex sandbox, tool or hook config: it hardcodes `danger-full-access`, network on and approval `never`.
  - Model tiers or per-node models other than review.
  - Vendoring superpowers `SKILL.md` copies into `.agents/skills/`: they would go stale.
  - Changing which skills each node uses.

## Decision
User decision (from the request):
- The default assistant is codex with `gpt-5.6-sol` and `modelReasoningEffort: medium`.
- Review stays on claude.
- The provider is a one-line switch.

Autonomous default (proceed): superpowers for Codex comes from the official Codex plugin `superpowers@openai-curated-remote`, installed by `make loop-setup`. It is not vendored or symlinked from the Claude plugin cache.

Decision (2026-10-13, internal, decided by the loop owner): the Codex plugin root is `source.path` when present, else `${CODEX_HOME:-~/.codex}/plugins/cache/<marketplaceName>/<name>/<version>` from `codex plugin list --json`. The codex scenario stubs cover a remote plugin entry. `make loop-setup` is not run from a worktree (`loop-register` would repoint the Archon registration).
