## ADDED Requirements

### Requirement: Loop commands load the skills their node declares
Every AI node in `.archon/workflows/*.yaml` with `skills:` SHALL use a command that names each declared skill and loads them all with the Skill tool as its first step, stopping when one does not load.

#### Scenario: Every declared skill is named and loaded by its command
- **WHEN** each `.archon/workflows/*.yaml` is parsed (via `python3 -c 'yaml.safe_load'` in `vim.system`) and, for every node (loop nodes included) with `skills:` and a `command:`, `.archon/commands/<command>.md` is read with `vim.fn.readfile`
- **THEN** the command names every declared skill in backticks and tells the agent to load them with the Skill tool before any other step and to stop when one does not load, and every `` `superpowers:<x>` `` the command names is in that node's `skills:`

### Requirement: Skill preflight fails a run with an unresolved skill
Every workflow SHALL run `.archon/scripts/skills_check.py` before its first skill-declaring AI node, and it SHALL fail when a declared skill does not resolve in the worktree: a project skill needs `.claude/skills/<name>/SKILL.md`, and a `<plugin>:<skill>` needs that plugin reported enabled without `errors` by `claude plugin list --json` and `<installPath>/skills/<skill>/SKILL.md`.

#### Scenario: Skill preflight runs before every skill-declaring node
- **WHEN** each `.archon/workflows/*.yaml` is parsed
- **THEN** it has a `bash` node that runs `.archon/scripts/skills_check.py`, and every node with a `<plugin>:<skill>` in `skills:` reaches that node through `depends_on` (a loop node through its parent node)

#### Scenario: Skill preflight fails on an unresolved plugin skill
- **WHEN** `python3 .archon/scripts/skills_check.py <workflow>` is run via `vim.system` in a throwaway repo whose workflow declares `superpowers:writing-plans`, with `PATH` putting first a stub `claude` whose `plugin list --json` reports `superpowers@superpowers-marketplace` with a non-empty `errors`
- **THEN** it exits non-zero and its stderr names `superpowers:writing-plans`

#### Scenario: Skill preflight passes when every declared skill resolves
- **WHEN** the same check is run, but the stub reports the plugin enabled with no `errors` and an `installPath` that contains `skills/writing-plans/SKILL.md`, and the repo has `.claude/skills/openspec-propose/SKILL.md` for a declared `openspec-propose`
- **THEN** it exits 0

### Requirement: Loop setup installs the project's Claude plugins
`make loop-setup` SHALL install every plugin that `.claude/settings.json` enables at user scope when `claude plugin list --json` does not report it loaded, because project-scope installs are per path and each Archon run has a new worktree path.

#### Scenario: Loop setup installs a missing enabled plugin
- **WHEN** `make loop-setup` is run via `vim.system` in a throwaway repo whose `.claude/settings.json` enables `superpowers@superpowers-marketplace`, with a stub `claude` that logs its arguments and whose `plugin list --json` reports that plugin with a non-empty `errors`, and `ARCHON` set to a stub
- **THEN** the stub log contains `plugin install superpowers@superpowers-marketplace --scope user`
