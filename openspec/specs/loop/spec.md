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

### Requirement: Queue picker prints one JSON document
`.archon/scripts/queue_pick.py` SHALL write exactly one JSON document to stdout in every case (with or without `INPUTS_CHANGE`, whether or not any `loop/<change>` branch exists, found or not found), so `make queue` without `CHANGE` can always read the picked change.

#### Scenario: Queue skips a taken change
- **WHEN** `make queue` is run without `CHANGE` (via `vim.system`) in a repo on `auto` whose stub `openspec list --json` lists two changes, the older of which already has a `loop/<change>` branch, with `ARCHON` set to a stub that logs its `workflow run` arguments
- **THEN** make exits 0, its output contains `Working on <newer change>` and no `JSONDecodeError`, and the stub was called with `--branch loop/<newer change>`, while `python3 .archon/scripts/queue_pick.py` run in the same repo prints a stdout that `vim.json.decode` parses as one object with `change` equal to the newer change

### Requirement: Ship merges into auto one at a time and never leaves it mid-merge
`.archon/scripts/ship.py` SHALL merge into the `auto` checkout only while it holds a host-side lock: a pid file in the repo's common git dir. A lock whose pid is no longer alive SHALL be taken over, and the lock SHALL be released on every exit. After any failed merge, ship SHALL leave `auto` at its pre-merge commit with no `MERGE_HEAD` and no staged or modified tracked files.

#### Scenario: Concurrent ships merge one at a time
- **WHEN** `python3 .archon/scripts/ship.py` is started via `vim.system`, all at once, in four worktrees of a throwaway repo whose main checkout is on `auto`, each worktree on a `loop/*` branch with one commit that does not conflict with the others
- **THEN** all four exit 0, `git log --first-parent auto` shows four new merges (one per branch), the `auto` checkout has no `MERGE_HEAD`, `git status --porcelain --untracked-files=no` there is empty, and no ship lock file remains

#### Scenario: Stale ship lock is taken over
- **WHEN** the ship lock file already exists and holds the pid of a process that has exited, and `ship.py` is run via `vim.system` in a worktree on a `loop/*` branch with one commit
- **THEN** ship exits 0 within its timeout, `auto` contains the merge of that branch, and no ship lock file remains

#### Scenario: Failed merge leaves auto clean
- **WHEN** `ship.py` is run via `vim.system` in a worktree on a `loop/*` branch with one commit, and the repo has a `pre-merge-commit` hook that exits 1, which stops the merge after it is staged
- **THEN** ship exits non-zero, `auto` still points at its pre-merge commit, the `auto` checkout has no `MERGE_HEAD` and `git status --porcelain --untracked-files=no` there is empty, the `loop/*` branch still exists, and no ship lock file remains

### Requirement: Ship reports a conflict for reconcile
When the merge into `auto` conflicts and the input `on_conflict` is `report`, `ship.py` SHALL leave `auto` untouched, exit 0 and print a JSON result with `merged` false, `conflict` true and the conflicting files, so the deliver workflow can reconcile the run branch and re-run the gate.

#### Scenario: Conflicting ship is reported for reconcile
- **WHEN** `ship.py` is run via `vim.system` with `INPUTS_ON_CONFLICT=report` in a worktree whose `loop/*` branch changes the same line of a file that `auto` has also changed since the branch was cut
- **THEN** ship exits 0 and prints one JSON object with `merged` false, `conflict` true and `files` listing that file; `auto` is unchanged, the `auto` checkout has no `MERGE_HEAD` and no staged or modified tracked files, and no ship lock file remains

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
