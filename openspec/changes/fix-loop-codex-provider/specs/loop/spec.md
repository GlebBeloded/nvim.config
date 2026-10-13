## ADDED Requirements

### Requirement: Loop runs on the configured provider with cross-model review
`.archon/config.yaml` SHALL name the loop's default provider in its one `assistant:` line. With `assistant: codex` it SHALL configure `assistants.codex` with model `gpt-5.6-sol` and `modelReasoningEffort: medium`, and SHALL keep an `assistants.claude` block, so changing that line is the whole switch. The `review` node of `nvim-deliver.yaml` SHALL run on `claude` regardless of the default.

#### Scenario: Default provider is codex with the chosen model
- **WHEN** `.archon/config.yaml` is parsed (via `python3 -c 'yaml.safe_load'` in `vim.system`)
- **THEN** `assistant` is `codex`, `assistants.codex.model` is `gpt-5.6-sol`, `assistants.codex.modelReasoningEffort` is `medium`, and `assistants` also has a `claude` key

#### Scenario: Review runs on claude
- **WHEN** `.archon/workflows/nvim-deliver.yaml` is parsed and its `review` node is found (loop nodes included)
- **THEN** that node has `provider: claude`

#### Scenario: Provider switch is documented
- **WHEN** `docs/workflow.md` is read with `vim.fn.readfile`
- **THEN** it contains `assistant: codex`, `assistant: claude` and `provider: claude`

### Requirement: Skill preflight resolves a skill for its node's provider
On `claude`, `skills_check.py` SHALL resolve a project skill at `.claude/skills/<name>/SKILL.md`, and a `<plugin>:<skill>` at `<installPath>/skills/<skill>/SKILL.md` of a plugin `claude plugin list --json` reports enabled without `errors`. On `codex`, it SHALL use `.agents/skills/<name>/SKILL.md`, and `<root>/skills/<skill>/SKILL.md` of a plugin `codex plugin list --json` reports `installed` and `enabled`. `<root>` is that plugin's root (next requirement).

#### Scenario: Skill preflight fails on a plugin skill Codex does not have
- **WHEN** the check is run in a throwaway repo:
  - its `.archon/config.yaml` has `assistant: codex`;
  - its workflow declares `superpowers:writing-plans`;
  - a stub `claude` reports the plugin loaded;
  - a stub `codex` has a `plugin list --json` whose `installed` list has no `superpowers` entry.
- **THEN** it exits non-zero and its stderr names `superpowers:writing-plans`

#### Scenario: Skill preflight fails on a Claude plugin with no install path
- **WHEN** the check is run in a throwaway repo:
  - its `.archon/config.yaml` has `assistant: claude`;
  - its workflow declares `superpowers:writing-plans`;
  - a stub `claude` reports the plugin enabled with no `errors` and no `installPath`.
- **THEN** it exits non-zero, its stderr names `superpowers:writing-plans`, and it prints no traceback

#### Scenario: Skill preflight resolves skills for each node's provider
- **WHEN** the check is run in a throwaway repo:
  - its `.archon/config.yaml` has `assistant: codex`;
  - a node declares `superpowers:writing-plans` and `openspec-propose`;
  - a loop node with `provider: claude` holds a node that declares `superpowers:requesting-code-review`;
  - a stub `codex` reports `superpowers` installed and enabled with a `source.path` that contains `skills/writing-plans/SKILL.md`;
  - the repo has `.agents/skills/openspec-propose/SKILL.md`;
  - a stub `claude` reports the plugin enabled with an `installPath` that contains `skills/requesting-code-review/SKILL.md`.
- **THEN** it exits 0

### Requirement: Codex plugin root falls back to the plugin cache
On `codex`, a plugin's root SHALL be the `codex plugin list --json` entry's `source.path` when present (a local plugin), else `${CODEX_HOME:-~/.codex}/plugins/cache/<marketplaceName>/<name>/<version>` of that entry (a remote plugin, which reports no `source.path`). A missing root or skill file SHALL count as unresolved and SHALL NOT end in a traceback.

#### Scenario: Skill preflight resolves a remote Codex plugin from the plugin cache
- **WHEN** the check is run in a throwaway repo:
  - its `.archon/config.yaml` has `assistant: codex`;
  - its workflow declares `superpowers:writing-plans`;
  - a stub `codex` reports `superpowers` installed and enabled with `marketplaceName: openai-curated-remote`, `version: 6.4.2` and `source: {source: remote, id: …}` (no `path`);
  - `CODEX_HOME` is a temp dir holding `plugins/cache/openai-curated-remote/superpowers/6.4.2/skills/writing-plans/SKILL.md`.
- **THEN** it exits 0

#### Scenario: Skill preflight fails on a remote Codex plugin missing from the plugin cache
- **WHEN** the same check is run, but the `CODEX_HOME` temp dir has no plugin cache
- **THEN** it exits non-zero, its stderr names `superpowers:writing-plans`, and it has no `Traceback`

## MODIFIED Requirements

### Requirement: Loop commands load the skills their node declares
Every AI node in `.archon/workflows/*.yaml` with `skills:` SHALL use a command that names each declared skill. As its first step, the command SHALL load them all on either provider: with the Skill tool on Claude, and as `$<skill>` on Codex. It SHALL stop when one does not load.

#### Scenario: Every declared skill is named and loaded by its command
- **WHEN** each `.archon/workflows/*.yaml` is parsed (via `python3 -c 'yaml.safe_load'` in `vim.system`) and, for every node (loop nodes included) with `skills:` and a `command:`, `.archon/commands/<command>.md` is read with `vim.fn.readfile`
- **THEN** the command:
  - names every declared skill in backticks and as `$<skill>`;
  - tells the agent to load them with the Skill tool before any other step and to stop when one does not load;
  - and every `` `superpowers:<x>` `` it names is in that node's `skills:`.

### Requirement: Skill preflight fails a run with an unresolved skill
Every workflow SHALL run `.archon/scripts/skills_check.py` before its first skill-declaring AI node. The script SHALL fail when a declared skill does not resolve for the provider of its node. That provider is the node's `provider:`, else its loop node's `provider:`, else the `assistant:` of `.archon/config.yaml`.

#### Scenario: Skill preflight runs before every skill-declaring node
- **WHEN** each `.archon/workflows/*.yaml` is parsed
- **THEN** it has a `bash` node that runs `.archon/scripts/skills_check.py`, and every node with a `<plugin>:<skill>` in `skills:` reaches that node through `depends_on` (a loop node through its parent node)

#### Scenario: Skill preflight fails on an unresolved plugin skill
- **WHEN** `python3 .archon/scripts/skills_check.py <workflow>` is run via `vim.system` in a throwaway repo:
  - its `.archon/config.yaml` has `assistant: claude`;
  - its workflow declares `superpowers:writing-plans`;
  - `PATH` puts first a stub `claude` whose `plugin list --json` reports `superpowers@superpowers-marketplace` with a non-empty `errors`.
- **THEN** it exits non-zero and its stderr names `superpowers:writing-plans`

#### Scenario: Skill preflight passes when every declared skill resolves
- **WHEN** the same check is run, but:
  - the stub reports the plugin enabled with no `errors` and an `installPath` that contains `skills/writing-plans/SKILL.md`;
  - the repo has `.claude/skills/openspec-propose/SKILL.md` for a declared `openspec-propose`.
- **THEN** it exits 0

#### Scenario: Configured provider resolves every declared skill here
- **WHEN** `python3 .archon/scripts/skills_check.py .archon/workflows/*.yaml` is run via `vim.system` in this checkout, with no stubs
- **THEN** it exits 0 (the test skips with its reason when `codex` or `claude` is not on `PATH`)

### Requirement: Loop setup installs the project's Claude plugins
`make loop-setup` SHALL install every plugin that `.claude/settings.json` enables at user scope when `claude plugin list --json` does not report it loaded, because project-scope installs are per path and each Archon run has a new worktree path. It SHALL also run `codex plugin add <plugin>@openai-curated-remote` for every `<plugin>` of a `<plugin>:<skill>` that a codex node declares and `codex plugin list --json` does not report installed.

#### Scenario: Loop setup installs a missing enabled plugin
- **WHEN** `make loop-setup` is run via `vim.system` in a throwaway repo:
  - its `.claude/settings.json` enables `superpowers@superpowers-marketplace`;
  - a stub `claude` logs its arguments, and its `plugin list --json` reports that plugin with a non-empty `errors`;
  - `ARCHON` is set to a stub.
- **THEN** the stub log contains `plugin install superpowers@superpowers-marketplace --scope user`

#### Scenario: Loop setup installs a missing Codex plugin
- **WHEN** `make loop-setup` is run via `vim.system` in a throwaway repo:
  - its `.archon/config.yaml` has `assistant: codex`;
  - a workflow declares `superpowers:writing-plans`;
  - a stub `codex` logs its arguments, and its `plugin list --json` has no installed `superpowers`;
  - a stub `claude` reports every plugin loaded;
  - `ARCHON` is set to a stub.
- **THEN** the codex stub log contains `plugin add superpowers@openai-curated-remote`
