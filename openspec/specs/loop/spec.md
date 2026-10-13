# loop Specification

## Purpose

The local AI loop's make targets (`make fix`, `feature`, `queue`, `update`): each runs one Archon workflow on a `loop/*` branch cut from `auto` and tidies up after it.

## Requirements

### Requirement: Loop run report consolidates persisted run evidence
`make loop-report [RUN=<id>]` SHALL select the named run, or the latest run for this codebase when `RUN` is omitted, print a short text summary and write `artifacts/runs/<id>/report.html`. The self-contained report SHALL show run identity and outcome, one row per workflow node with status and duration, each approval gate's reason and decision comment, each attempt's failing checks, and the shipped merge commit with its final diff stat when present.

#### Scenario: Named run report contains the complete run history
- **WHEN** `make loop-report RUN=<id>` is called via `vim.system` against a fixture Archon database, artifact directory and Git repository containing completed, failed and retried nodes, approval gates with comments, two gate attempts with failing checks, and a shipped merge commit
- **THEN** it exits 0, stdout identifies the run, final status and report path, and `artifacts/runs/<id>/report.html` exists with no external asset dependency and contains exactly one row per workflow node with its status and duration (aggregating repeated loop invocations and showing their count), every gate reason and approve/reject comment, the failing checks grouped by attempt, the available run artifacts, and the merge commit and diff stat

#### Scenario: Report without a run selects the latest run for this codebase
- **WHEN** `make loop-report` is called via `vim.system` with no `RUN` against a fixture database containing an older and a newer run for this codebase and a still newer run for another codebase
- **THEN** it exits 0, writes `artifacts/runs/<newer-id>/report.html`, and stdout identifies `<newer-id>` and that report path

#### Scenario: Running run report tolerates incomplete evidence
- **WHEN** `make loop-report RUN=<id>` is called via `vim.system` for a running fixture run with a started but unfinished node and no gate, check or ship result yet
- **THEN** it exits 0, shows the node as running with its elapsed duration, marks unavailable attempt and merge evidence as pending, and writes a self-contained report without inventing a final outcome

### Requirement: Loop status links to the latest run report
`make loop-status` SHALL retain the Archon active-status and recent-run output, generate the latest report for this codebase, and print a local link to it.

#### Scenario: Loop status prints a usable report link
- **WHEN** `make loop-status` is called via `vim.system` with `ARCHON` set to a logging stub and fixture data for a latest run
- **THEN** the stub records `workflow status` and `workflow runs --limit 10`, `artifacts/runs/<latest-id>/report.html` exists, and stdout contains its `file://` link

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
- **WHEN** `make queue` is run without `CHANGE` (via `vim.system`) in a repo on `auto` whose stub `openspec list --json` lists two changes, the older of which already has a `loop/<change>` branch and a running Archon run working it (an `ARCHON_DB` with that row), with `ARCHON` set to a stub that logs its `workflow run` arguments
- **THEN** make exits 0, its output contains `Working on <newer change>` and no `JSONDecodeError`, and the stub was called with `--branch loop/<newer change>`, while `python3 .archon/scripts/queue_pick.py` run in the same repo prints a stdout that `vim.json.decode` parses as one object with `change` equal to the newer change

### Requirement: Ship merges into auto one at a time and never leaves it mid-merge
`.archon/scripts/ship.py` SHALL merge into the `auto` checkout only while it holds a host-side lock: a pid file in the repo's common git dir. A lock whose pid is no longer alive SHALL be taken over, and the lock SHALL be released on every exit. After any failed merge, ship SHALL leave `auto` at its pre-merge commit with no `MERGE_HEAD` and no staged or modified tracked files.

#### Scenario: Concurrent ships merge one at a time
- **WHEN** `python3 .archon/scripts/ship.py` is started via `vim.system`, all at once, in four worktrees of a throwaway repo whose main checkout is on `auto`, each worktree on a `loop/*` branch with one commit that does not conflict with the others
- **THEN** all four exit 0, `git log --first-parent auto` shows four new merges (one per branch), the `auto` checkout has no `MERGE_HEAD`, `git status --porcelain --untracked-files=no` there is empty, and no ship lock file remains

#### Scenario: Ship waits for a dirty auto checkout
- **WHEN** `.archon/scripts/ship.py` runs while the `auto` checkout has a tracked edit that is reverted 1.5 s later
- **THEN** it prints that it is waiting, then merges the branch into `auto`

#### Scenario: Ship gives up on an auto checkout that stays dirty
- **WHEN** `.archon/scripts/ship.py` runs with `SHIP_DIRTY_WAIT=1` while the `auto` checkout keeps a tracked edit
- **THEN** it exits non-zero and says to merge the branch by hand

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
Every AI node in `.archon/workflows/*/*.yaml` with `skills:` SHALL use a command that names each declared skill. As its first step, the command SHALL load them all on either provider: with the Skill tool on Claude, and as `$<skill>` on Codex. It SHALL stop when one does not load.

#### Scenario: Every declared skill is named and loaded by its command
- **WHEN** each `.archon/workflows/*/*.yaml` is parsed (via `python3 -c 'yaml.safe_load'` in `vim.system`) and, for every node (loop nodes included) with `skills:` and a `command:`, `.archon/commands/<command>.md` is read with `vim.fn.readfile`
- **THEN** the command:
  - names every declared skill in backticks and as `$<skill>`;
  - tells the agent to load them with the Skill tool before any other step and to stop when one does not load;
  - and every `` `superpowers:<x>` `` it names is in that node's `skills:`.

### Requirement: Skill preflight fails a run with an unresolved skill
Every workflow SHALL run `.archon/scripts/skills_check.py` before its first skill-declaring AI node. The script SHALL fail when a declared skill does not resolve for the provider of its node. That provider is the node's `provider:`, else its loop node's `provider:`, else the `assistant:` of `.archon/config.yaml`.

#### Scenario: Skill preflight runs before every skill-declaring node
- **WHEN** each `.archon/workflows/*/*.yaml` is parsed
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
- **WHEN** `python3 .archon/scripts/skills_check.py .archon/workflows/*/*.yaml` is run via `vim.system` in this checkout, with no stubs
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

### Requirement: Loop runs on the configured provider with cross-model review
`.archon/config.yaml` SHALL name the loop's default provider in its one `assistant:` line. With `assistant: codex` it SHALL configure `assistants.codex` with model `gpt-5.6-sol` and `modelReasoningEffort: medium`, and SHALL keep an `assistants.claude` block, so changing that line is the whole switch. The `review` node of `nvim-deliver.yaml` SHALL run on `claude` regardless of the default.

#### Scenario: Default provider is codex with the chosen model
- **WHEN** `.archon/config.yaml` is parsed (via `python3 -c 'yaml.safe_load'` in `vim.system`)
- **THEN** `assistant` is `codex`, `assistants.codex.model` is `gpt-5.6-sol`, `assistants.codex.modelReasoningEffort` is `medium`, and `assistants` also has a `claude` key

#### Scenario: Review runs on claude
- **WHEN** `.archon/workflows/nvim-deliver/nvim-deliver.yaml` is parsed and its `review` node is found (loop nodes included)
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

### Requirement: Agents start with durable loop lessons
The fix workflow's exploration prompt and every implementation pass SHALL read the curated `Loop lessons` section in `docs/workflow.md` after loading required skills and before investigating or changing the project.

#### Scenario: Fix and implement prompts read loop lessons
- **WHEN** the fix/explore and implement command sources are read in a headless child Neovim
- **THEN** both direct the agent to read the `Loop lessons` section of `docs/workflow.md` before starting their task

### Requirement: Corrected attempt failures become bounded lessons
The build verdict/escalation path SHALL append a supplied one-line lesson only for a failure from an earlier attempt that a later attempt reports fixed. It SHALL normalize whitespace, compare lessons case-insensitively, retain only one copy, and keep at most the 10 newest lesson lines without changing other workflow documentation.

#### Scenario: Passing retry records its corrected failure
- **WHEN** a later build attempt passes after an earlier failed attempt and supplies the one-line lesson `Under host load, scale startup budgets before diagnosing a regression`
- **THEN** the `Loop lessons` section contains that lesson exactly once

#### Scenario: Exhausted run retains a corrected earlier failure
- **WHEN** the build loop exhausts its final attempt but supplies a one-line lesson for a different earlier-attempt failure that the later attempt fixed
- **THEN** the escalation path records that lesson in the `Loop lessons` section before reporting the exhausted run

#### Scenario: Repeated lessons stay deduplicated and bounded
- **WHEN** the verdict/escalation path is invoked in a throwaway checkout with a lesson that differs from an existing lesson only by case or repeated whitespace, followed by enough distinct fixed lessons to exceed the limit
- **THEN** the equivalent lesson occurs once, the section contains the 10 newest lesson lines, and text outside the section is unchanged

#### Scenario: Unfixed failures do not become lessons
- **WHEN** an attempt fails and no later attempt supplies a lesson saying that failure was fixed
- **THEN** the verdict/escalation path does not add a lesson for that failure

### Requirement: Small steps with a script judge
The delivery loop SHALL implement one task per fresh agent session from a script-built context pack, count only real checkbox list items as tasks, send only a failing pass's findings to the next fix step, and decide shipping by script: reject partial or rule-breaking work, ask the user only for breaking changes, and ship everything else.

#### Scenario: An abandoned run's branch does not take its change
- **WHEN** `.archon/scripts/queue_pick.py` runs where change `c` has a `loop/c` branch but no running or paused Archon run works it
- **THEN** it picks `c` (`make queue` then adopts that branch on a new one)

#### Scenario: Plan header prose is not an unchecked task
- **WHEN** `.archon/scripts/tasks.py` runs on a tasks.md whose only `- [ ]` text is inside a plan header sentence and every list item is checked
- **THEN** it exits 0 (the task loop is done)

#### Scenario: A make check item does not hold the task loop
- **WHEN** `.archon/scripts/tasks.py` runs on a tasks.md whose only unchecked item says to run `make check`
- **THEN** it exits 0 (agents never run `make check`; the gate ticks that item once the check is green)

#### Scenario: Task loop continues while a task is unchecked
- **WHEN** `.archon/scripts/tasks.py` runs on a tasks.md with an unchecked `- [ ]` list item
- **THEN** it exits 1

#### Scenario: Task loop reads the change the pack saved
- **WHEN** `.archon/scripts/context_pack.py` ran for a change with an unchecked task and `.archon/scripts/tasks.py` then runs with only `ARTIFACTS_DIR` set (as in `until_bash`, which gets no `INPUTS_*` env)
- **THEN** it exits 1 (a task is left)

#### Scenario: Plan is skipped when the spec wrote tasks
- **WHEN** `.archon/scripts/tasks.py --plan-needed` runs for a change whose tasks.md has a task, and for one with no tasks.md
- **THEN** it prints `{"needed": false, "has_change": true}` and then `{"needed": false, "has_change": false}` (no change folder: an adopted change that is already archived, so plan, tasks and implement are skipped)

#### Scenario: Context pack names installed plugin sources
- **WHEN** `.archon/scripts/context_pack.py` runs for a change whose proposal mentions a plugin listed in `lazy-lock.json`
- **THEN** the pack has an `Installed plugin sources` section with that plugin's lazy.nvim install path and no other plugin

#### Scenario: Small change packs all remaining tasks
- **WHEN** `.archon/scripts/context_pack.py` runs for a change with at most 4 tasks, the first one ticked
- **THEN** the pack's `## Next task` section holds every remaining task, so one implement session does them all

#### Scenario: Gate ignores unchanged scenarios a modified requirement repeats
- **WHEN** `.archon/scripts/scenarios.py <change>` runs where a MODIFIED requirement repeats one scenario unchanged and edits another, and no test names either
- **THEN** it prints only the edited scenario and exits 1

#### Scenario: Gate checks scenarios named by tasks when the spec has no delta
- **WHEN** `.archon/scripts/scenarios.py <change>` runs for a change with no spec delta whose tasks.md names `x: lonely` on a Scenarios line, and no test has that name
- **THEN** it prints `x: lonely` and exits 1

#### Scenario: Spec gate catches main specs a change would break
- **WHEN** `.archon/scripts/spec_trial.py <change>` runs for a change that is valid on its own but whose MODIFIED requirement is longer than 500 characters
- **THEN** it exits 1 and prints the main-spec warning (spec-gate runs it before implement)

#### Scenario: Spec gate rejects a task naming an unknown scenario
- **WHEN** `.archon/scripts/scenarios.py --unknown <change>` runs where tasks.md names `x: real` (a scenario in openspec/specs) and `x: invented` (in no spec)
- **THEN** it lists only `x: invented` and exits 1

#### Scenario: Gate names a change scenario without a test
- **WHEN** `.archon/scripts/scenarios.py <change>` runs where the change adds two scenarios and a test names only one, and a REMOVED section lists a third
- **THEN** it prints only the untested scenario as `<capability>: <title>` and exits 1

#### Scenario: Context pack names the next task
- **WHEN** `.archon/scripts/context_pack.py` runs for a change whose first task is ticked and second is not
- **THEN** `$ARTIFACTS_DIR/context.md` has a `## Next task` section holding the second task and includes the Loop lessons

#### Scenario: Judge rejects an xfail without a queued change
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that adds `H.xfail("<id>", …)` for an id with no `openspec/changes/<id>`
- **THEN** its JSON `decision` is `reject`

#### Scenario: Judge asks only for a breaking change
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that adds a `vim.keymap.set` line to `lua/gleb/keymaps.lua`
- **THEN** its JSON `decision` is `ask`

#### Scenario: Judge ignores REMOVED Requirements mentioned in prose
- **WHEN** `.archon/scripts/escalation.py` runs on a branch whose change delta only mentions `## REMOVED Requirements` inside a scenario sentence
- **THEN** its JSON `decision` is `ship`

#### Scenario: Judge ships an internal change without asking
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that only adds an internal Lua module
- **THEN** its JSON is `{decision = "ship", escalate = false, reasons = "- none"}`

#### Scenario: Verdict sends hard-rule violations back to fix
- **WHEN** `.archon/scripts/verdict.py` runs with every gate green on a branch that removes a test case
- **THEN** it reports `passed` false, `done` false, `failed_gates` `rules`, and `feedback` names the removed case

#### Scenario: A rejected judge never ships
- **WHEN** `.archon/scripts/decide.py` runs with `INPUTS_VERDICT=reject` and no gate decision
- **THEN** its JSON `go` is false

### Requirement: Active change scenarios participate in traceability
Traceability SHALL count scenarios added by active change deltas while excluding archived changes and
scenarios under `## REMOVED Requirements`.

#### Scenario: Trace counts scenarios an active change adds
- **WHEN** `make trace` runs where an active change (`openspec/changes/<id>/specs/<capability>/spec.md`) adds a scenario that a test names, and an archived change and a `## REMOVED Requirements` section list other scenarios
- **THEN** the added scenario is tested, the archived and removed ones are not scenarios, and nothing is orphan
