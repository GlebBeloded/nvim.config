# Loop on Codex with cross-model review: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the loop on Codex (`gpt-5.6-sol`, medium) by default with review pinned to Claude. Every declared skill must load and resolve for the provider that runs its node.

**Architecture:** `skills_check.py` resolves skills per node provider and installs missing Codex plugins at setup. Commands name each skill as `` `<skill>` `` (Claude Skill tool) and `$<skill>` (Codex explicit invocation). The default flips in `.archon/config.yaml` only after a probe run on Codex.

**Tech Stack:** Archon 0.11.1, Codex CLI 0.153.4, Claude Code, Python 3 + PyYAML, mini.test (unit layer, `vim.system` via `H.system`).

**Spec:** `openspec/changes/fix-loop-codex-provider/` (proposal.md with `## Decision`, design.md, specs/loop/spec.md)

## Global Constraints

- Default: `assistant: codex`, `assistants.codex.model: gpt-5.6-sol`, `assistants.codex.modelReasoningEffort: medium`, and the `assistants.claude` block is kept. Rollback is the one line `assistant: claude`.
- The `review` node of `nvim-deliver.yaml` sets `provider: claude` and no `model:`.
- Node provider: `node.provider`, else the parent loop node's `provider`, else `assistant:` in `.archon/config.yaml`, else `claude`.
- Codex project skill: `.agents/skills/<name>/SKILL.md`. Codex plugin skill: `codex plugin list --json` → `installed[]` entry with `name == <plugin>`, `installed` and `enabled` true, and `<source.path>/skills/<skill>/SKILL.md`.
- Codex plugin marketplace is the one constant `openai-curated-remote` (`codex plugin add <plugin>@openai-curated-remote`).
- `claude plugin list --json` runs only when a claude node declares a plugin skill. `codex plugin list --json` runs only when a codex node does.
- Superpowers for Codex comes only from the Codex plugin: do not vendor or symlink `SKILL.md` copies into `.agents/skills/`.
- Test names are exactly `"loop: <scenario title>"`. Never weaken the existing loop tests.

## Review Focus

1. **Archon substitution of `$superpowers:<x>` in command text.** Archon expands `$INPUTS.*`, `$BASE_BRANCH` and `$<node>.output`. The `$<skill>` mention must reach Codex verbatim. The probe in Task 4 checks the transcript for the literal `$superpowers:systematic-debugging`.
2. **`provider:` on a loop-group inner node.** `review` sits inside a `loop_group`. `make loop-validate` must accept it, and the preflight must take provider from the inner node first and the loop node second. The Task 1 test "loop: Skill preflight resolves skills for each node's provider" puts the claude node inside a `loop_group`.
3. **`make loop-setup` with no workflows, or with `codex` missing on a claude-only repo.** An unmatched `.archon/workflows/*.yaml` glob reaches the script literally. It must skip non-existent paths and never call `codex`. The existing "loop: Loop setup installs a missing enabled plugin" test (no config, no workflows, no codex stub) covers this and must stay green in Task 2.
4. **`codex plugin list --json` fails or `codex` is not on PATH while a codex node declares a plugin skill.** Preflight exits non-zero with a message naming `codex`, not a Python traceback. Add the assertion in Task 1 (case 3).
5. **The same plugin is installed but disabled.** It counts as unresolved in the preflight. `--install-plugins` does not `plugin add` it again (`add` cannot enable it), but it prints that the plugin is disabled. Covered by Task 1 (case 4).

---

### Task 1: Provider-aware skill preflight

Scenarios: "Skill preflight fails on an unresolved plugin skill", "Skill preflight passes when every declared skill resolves", "Skill preflight fails on a plugin skill Codex does not have", "Skill preflight resolves skills for each node's provider".

**Files:**
- Modify: `.archon/scripts/skills_check.py` (module docstring and resolver functions)
- Test: `tests/unit/loop/test_skills.lua`

**Interfaces:**
- Produces (Python, `skills_check.py`):
  - `configured_assistant() -> str`: `assistant:` of `.archon/config.yaml`, else `"claude"`.
  - `declared_skills_by_provider(workflow: dict, default: str) -> dict[str, list[str]]` replaces `declared_skills`. Loop nodes are included, and each inner node inherits its loop node's `provider`.
  - `claude_plugins() -> dict[str, dict]` (renamed `loaded_plugins`) and `codex_plugins() -> dict[str, dict]`: installed+enabled entries keyed by `name`. Both `sys.exit` with a message naming the CLI when it is missing or exits non-zero.
  - `unresolved(provider: str, names: list[str]) -> list[str]`.
- Produces (Lua, `test_skills.lua`): `write_codex_stub(bin: string, installed: table[]): string` writes `{installed = installed, available = {}}` for `plugin list --json`, logs arguments to `bin/codex.log` and returns the log path. `make_skill_repo(skills, opts?: { assistant?: string, extra_yaml?: string[] })` writes `.archon/config.yaml` with `assistant: <opts.assistant or "claude">`.

- [x] **Step 1: Write the failing tests** in `tests/unit/loop/test_skills.lua`:
  1. Add `write_codex_stub` and the `make_skill_repo` options. Pass `assistant = "claude"` explicitly in the two existing preflight tests and change nothing else in them.
  2. `T["loop: Skill preflight fails on a plugin skill Codex does not have"]`:
     - repo `assistant = "codex"` declares `superpowers:writing-plans`;
     - the claude stub reports `PLUGIN_ID` enabled with an install containing `skills/writing-plans/SKILL.md`;
     - the codex stub's `installed = {}`;
     - assert `code ~= 0` and stderr contains `superpowers:writing-plans`.
  3. `T["loop: Skill preflight resolves skills for each node's provider"]`:
     - `assistant = "codex"`;
     - node `n` declares `superpowers:writing-plans, openspec-propose`;
     - a second top-level node `l` has `provider: claude` and a `loop_group.nodes` with one inner node `r` declaring `superpowers:requesting-code-review`;
     - `.agents/skills/openspec-propose/SKILL.md` exists and `.claude/skills/openspec-propose` does not;
     - the codex stub has `{ name = "superpowers", installed = true, enabled = true, source = { path = <dir with skills/writing-plans/SKILL.md> } }`;
     - the claude stub has `PLUGIN_ID` enabled with an install containing `skills/requesting-code-review/SKILL.md` only;
     - assert `code == 0`.
  4. Review Focus 4: in the Codex-missing test, add a case where the `codex` stub exits 1 for `plugin list --json`. Assert non-zero and stderr contains `codex`, with no `Traceback`. The real `codex` sits in `/opt/homebrew/bin` next to `python3`, so a stub stands in for "missing". `codex_plugins` also catches `FileNotFoundError`.
  5. Review Focus 5: an extra assertion with a codex stub entry `enabled = false`. Assert non-zero and stderr names the skill.

- [x] **Step 2: Run to verify they fail**
  Run: `make test FILE=tests/unit/loop/test_skills.lua`
  Expected: the two new cases FAIL (exit 0 / wrong provider). The existing cases PASS.

- [x] **Step 3: Implement the interfaces above in `skills_check.py`.**
  - The project-skill dir is `.claude/skills` for claude and `.agents/skills` for codex.
  - The claude plugin skill path is `installPath`, and the codex path is `source.path`.
  - `main` merges `declared_skills_by_provider` over all paths and calls each provider's plugin list only if that provider has a `:` name.
  - The error message lists `<skill> (<provider>)`.
  - Update the docstring to describe both resolvers.

- [x] **Step 4: Verify**
  Run: `make test FILE=tests/unit/loop/test_skills.lua`
  Expected: all cases PASS.

- [x] **Step 5: Commit**: `git commit -m "fix(loop): skill preflight resolves per node provider"`

### Task 2: Loop setup installs Codex plugins

Scenarios: "Loop setup installs a missing Codex plugin" (and "Loop setup installs a missing enabled plugin" stays green).

**Files:**
- Modify: `.archon/scripts/skills_check.py` (`install_plugins`, `main`, usage line)
- Modify: `Makefile:137` (`loop-setup`)
- Test: `tests/unit/loop/test_skills.lua`

**Interfaces:**
- Consumes: `configured_assistant`, `declared_skills_by_provider`, `codex_plugins`, `claude_plugins` (Task 1); `write_codex_stub` (Task 1).
- Produces: CLI `skills_check.py --install-plugins [workflow.yaml...]`. Non-existent paths are ignored. The constant is `CODEX_MARKETPLACE = "openai-curated-remote"`.

- [x] **Step 1: Write the failing test** `T["loop: Loop setup installs a missing Codex plugin"]`:
  - `make_setup_repo()` plus `.archon/config.yaml` (`assistant: codex`) and `.archon/workflows/w.yaml` with one node declaring `superpowers:writing-plans`;
  - the claude stub reports `PLUGIN_ID` loaded;
  - the codex stub has `installed = {}`;
  - `ARCHON` stub, then `make loop-setup`;
  - assert `code == 0` and the codex log contains `plugin add superpowers@openai-curated-remote`.

- [x] **Step 2: Run to verify it fails**
  Run: `make test FILE=tests/unit/loop/test_skills.lua CASE="Loop setup"`
  Expected: the new case FAILS (no codex log line). "Loop setup installs a missing enabled plugin" PASSES.

- [x] **Step 3: Implement**
  - `install_plugins(paths: list[str]) -> int`: the Claude part is unchanged. For each unique `<plugin>` of a codex-provider `:` skill that is not in `codex_plugins()`, run `codex plugin add <plugin>@openai-curated-remote`, unless the plugin is installed but disabled: then print a hint to enable it. Import `yaml` only when a path exists.
  - `Makefile`: `@python3 .archon/scripts/skills_check.py --install-plugins .archon/workflows/*.yaml`.

- [x] **Step 4: Verify**
  Run: `make test FILE=tests/unit/loop/test_skills.lua`
  Expected: all PASS.

- [x] **Step 5: Commit**: `git commit -m "fix(loop): loop-setup installs declared Codex plugins"`

### Task 3: Commands load skills on both providers

Scenario: "Every declared skill is named and loaded by its command".

**Files:**
- Modify: `tests/unit/loop/test_skills.lua` (`command_violations`)
- Modify: all 10 skill-declaring `.archon/commands/*.md` (first step only; `grep -l "Skill tool" .archon/commands/*.md`)

- [x] **Step 1: Make the test fail.** In `command_violations`, for each declared skill also require the plain-text `"$" .. skill`. Add `violation "does not name $<skill>"`. Keep `LOAD_FIRST_NEEDLES` as they are.

- [x] **Step 2: Run to verify it fails**
  Run: `make test FILE=tests/unit/loop/test_skills.lua CASE="Every declared skill"`
  Expected: FAIL listing every command with `does not name $…`.

- [x] **Step 3: Rewrite the first step of each command** in this form (exact copy; skills listed in the node's `skills:` order):

  ```
  First, load each of these skills before any other step: `superpowers:writing-plans`.
  On Claude, load each with the Skill tool. On Codex, invoke each by name: $superpowers:writing-plans.
  Report each skill as it loads. If one does not load, stop and report the error naming it.
  ```

- [x] **Step 4: Verify**
  Run: `make test FILE=tests/unit/loop/test_skills.lua`
  Expected: all PASS.

- [x] **Step 5: Commit**: `git commit -m "fix(loop): commands load skills via Skill tool or \$skill"`

### Task 4: Install the Codex plugin and probe a Codex run (no commit)

Scenarios: none (a gate before Task 5; the design's Decision 6).

- [x] **Step 1:** Run `make loop-setup`, then `codex plugin list --json`. Expected: `superpowers` with `installed: true, enabled: true`.
- [ ] **Step 2:** With `assistant: claude` still set, write the uncommitted `.archon/workflows/probe-codex.yaml`. It has one node with `provider: codex`, `model: gpt-5.6-sol`, and a prompt that:
  - invokes `$superpowers:systematic-debugging` and `$openspec-explore`;
  - reports which loaded;
  - runs `make quick` and `tests/sandbox/sandbox.sh status`.

  Run it with `$(ARCHON) workflow run probe-codex --base auto --branch loop/probe-codex "probe"`.
- [ ] **Step 3:** Read the transcript.
  Expected:
  - both skills report loaded;
  - the literal `$superpowers:systematic-debugging` reached the prompt unsubstituted (Review Focus 1);
  - `make quick` and `sandbox.sh status` both ran.

  Save a short result for the merge message. If a check fails, stop and escalate: do not flip the default.
- [ ] **Step 4:** Delete `probe-codex.yaml` and the probe branch/worktree.

### Task 5: Default to Codex, review on Claude

Scenarios: "Default provider is codex with the chosen model", "Review runs on claude", "Configured provider resolves every declared skill here".

**Files:**
- Create: `tests/unit/loop/test_provider.lua`
- Modify: `.archon/config.yaml`, `.archon/workflows/nvim-deliver.yaml` (`review` node)

**Interfaces:**
- Consumes: the YAML-to-JSON pattern of `test_skills.lua` (`YAML_TO_JSON` via `H.system`). Copy the 3-line helper and do not export it.

- [ ] **Step 1: Write the failing tests** in `test_provider.lua`:
  - `T["loop: Default provider is codex with the chosen model"]`: parse `.archon/config.yaml`. `eq(cfg.assistant, "codex")`, `eq(cfg.assistants.codex.model, "gpt-5.6-sol")`, `eq(cfg.assistants.codex.modelReasoningEffort, "medium")`, `eq(cfg.assistants.claude ~= nil, true)`.
  - `T["loop: Review runs on claude"]`: parse `nvim-deliver.yaml`, find node `id == "review"` across top-level and `loop_group.nodes`, then `eq(review.provider, "claude")`.
  - `T["loop: Configured provider resolves every declared skill here"]`: if `vim.fn.executable("codex") == 0 or vim.fn.executable("claude") == 0` (checked in the child), `MiniTest.skip("codex or claude not on PATH")`. Otherwise run `python3 .archon/scripts/skills_check.py <all workflow paths>` in `H.root` with real HOME, and `eq(code, 0, { fail_reason = stderr })`.

- [ ] **Step 2: Run to verify they fail**
  Run: `make test FILE=tests/unit/loop/test_provider.lua`
  Expected: the first two FAIL. The third PASSES or skips (Task 4 installed the plugin).

- [ ] **Step 3: Implement**
  - `.archon/config.yaml`: `assistant: codex`, plus `assistants.codex: { model: gpt-5.6-sol, modelReasoningEffort: medium }` next to the kept `claude` block. Add a comment that `assistant: claude` switches back.
  - `nvim-deliver.yaml`: `provider: claude # cross-model review` on the `review` node.

- [ ] **Step 4: Verify**
  Run: `make test FILE=tests/unit/loop/test_provider.lua && make loop-validate`
  Expected: 3 PASS, and validate reports no errors.

- [ ] **Step 5: Commit**: `git commit -m "fix(loop): default to codex gpt-5.6-sol, review on claude"`. Put the Task 4 probe result in the body.

### Task 6: Document the provider switch

Scenario: "Provider switch is documented".

**Files:**
- Modify: `docs/workflow.md` (`## The loop` line 10 and `### Setup facts`)
- Test: `tests/unit/loop/test_provider.lua`

- [ ] **Step 1: Write the failing test** `T["loop: Provider switch is documented"]`: read `docs/workflow.md` with `vim.fn.readfile`, then for each of `assistant: codex`, `assistant: claude`, `provider: claude` assert `text:find(needle, 1, true) ~= nil`.

- [ ] **Step 2: Run to verify it fails**
  Run: `make test FILE=tests/unit/loop/test_provider.lua CASE="documented"`
  Expected: FAIL.

- [ ] **Step 3: Edit `docs/workflow.md`.** No restating of code (rule 10).
  - "The loop" no longer says Claude Code only.
  - Setup facts gain:
    - the one-line `assistant: codex` / `assistant: claude` switch;
    - review pinned with `provider: claude`;
    - Codex loads skills from `.agents/skills` and the `superpowers@openai-curated-remote` plugin, invoked as `$<skill>`;
    - Archon runs Codex with no sandbox, network on and no approval prompts, so `make check E2E=1` and ssh to the sandbox VM need nothing extra, and there are no Codex hooks;
    - `skills-check` checks each node's provider, and `make loop-setup` installs the Codex plugins.

- [ ] **Step 4: Verify**
  Run: `make check`
  Expected: green.

- [ ] **Step 5: Commit**: `git commit -m "docs(workflow): codex provider, cross-model review"`

## Blocked

The spec's Codex plugin resolver is wrong for the plugin it targets (found in Task 4 Step 1, 2026-10-13).
- `codex plugin add superpowers@openai-curated-remote` succeeded (6.4.2, `installed: true, enabled: true`). It was run directly, not through `make loop-setup`: run from a worktree, `loop-register` repoints the Archon registration to that worktree.
- `codex plugin list --json` reports this plugin as `source: {"source": "remote", "id": "plugins~Plugin_…"}`, with no `path`. Only local/bundled plugins carry `source.path`.
- Its skills live in `~/.codex/plugins/cache/openai-curated-remote/superpowers/6.4.2/skills/<skill>/SKILL.md`, which is `$CODEX_HOME/plugins/cache/<marketplaceName>/<name>/<version>` with fields the list does report (`marketplaceName`, `name`, `version`).
- So "a `<plugin>:<skill>` needs … `<source.path>/skills/<skill>/SKILL.md`" (specs/loop/spec.md, design Decision 3, Global Constraints) never resolves `superpowers:*` on Codex. After the flip, every run's preflight would fail, and "loop: Configured provider resolves every declared skill here" would fail.

Proposed spec fix (needs a decision): the codex plugin root is `source.path` when present, else `${CODEX_HOME:-~/.codex}/plugins/cache/<marketplaceName>/<name>/<version>`. The stubs in the codex scenarios would then also cover a remote entry. Tasks 1–3 are done and committed; Task 4 Steps 2–4 (probe), 5 and 6 wait on this.
