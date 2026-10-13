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

#### Scenario: Queue adopts the branch a follow-up names
- **WHEN** `make queue CHANGE=followup-x` runs where `openspec/changes/followup-x/proposal.md` has the line `Adopt: loop/x-rejected` (written by followup.py) followed by a second `Adopt: loop/x-other` line, both branches exist, with `ARCHON` stubbed
- **THEN** Archon is asked to run work-queue with `--input adopt=loop/x-rejected` (the first `Adopt:` line; the rejected run's work is merged first)

#### Scenario: Queue prefers the Adopt branch over loop/<change>
- **WHEN** `make queue CHANGE=x` runs, with `ARCHON` stubbed, where branch `loop/x` exists and `openspec/changes/x/proposal.md` has `Adopt: loop/x-20260101` (the newer rejected run), once with that branch present and once without it
- **THEN** with the branch present Archon is asked for `--input adopt=loop/x-20260101`; without it, for `--input adopt=loop/x`; both runs use a `--branch loop/x-<stamp>` branch

#### Scenario: Queue skips a taken change
- **WHEN** `make queue` is run without `CHANGE` (via `vim.system`) in a repo on `auto` whose stub `openspec list --json` lists two changes, the older of which already has a `loop/<change>` branch and a running Archon run working it (an `ARCHON_DB` with that row), with `ARCHON` set to a stub that logs its `workflow run` arguments
- **THEN** make exits 0, its output contains `Working on <newer change>` and no `JSONDecodeError`, and the stub was called with `--branch loop/<newer change>`, while `python3 .archon/scripts/queue_pick.py` run in the same repo prints a stdout that `vim.json.decode` parses as one object with `change` equal to the newer change

### Requirement: Rejected run is re-queued once
After a judge reject, `.archon/scripts/followup.py` SHALL re-queue the work on `auto` under the ship lock with no second change for the same work: when `openspec/changes/<change>/proposal.md` is on `auto`, it SHALL rewrite that proposal to hold one `Adopt: <rejected branch>` line and one `## Rejected run` section with the judge's reasons; otherwise it SHALL queue a new change `followup-<change>` that adopts the branch. It prints `{queued, change}`.

#### Scenario: Rejected active change is re-queued in place
- **WHEN** `python3 .archon/scripts/followup.py` runs with `INPUTS_CHANGE=x` and `INPUTS_REASONS` in a worktree on `loop/x-20260101` of a throwaway repo whose main checkout is on `auto` and holds `openspec/changes/x/proposal.md` with `Kind: bug`, an `Adopt: loop/x` line and an old `## Rejected run` section
- **THEN** it prints `queued` true and `change` `x`, no `openspec/changes/followup-x` exists on `auto`, the proposal's only `Adopt:` line is `Adopt: loop/x-20260101`, it has one `## Rejected run` section holding the new reasons and not the old ones, the latest `auto` commit is `chore(openspec): re-queue x from loop/x-20260101`, and no ship lock file remains

#### Scenario: Adopt line is added to a proposal without one
- **WHEN** followup.py re-queues a change whose proposal has a `Kind:` line and no `Adopt:` line, and one whose proposal has neither (only `## Why` and `## What Changes`)
- **THEN** the first gets `Adopt: <branch>` on the line after `Kind:`, the second at the end of `## Why`, before `## What Changes`

#### Scenario: Rejected archived change gets a follow-up change
- **WHEN** followup.py runs with `INPUTS_CHANGE=x` where `auto` has no `openspec/changes/x/proposal.md`
- **THEN** it prints `queued` true and `change` `followup-x`, and `openspec/changes/followup-x/proposal.md` on `auto` has the line `Adopt: <branch>` and the reasons

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

### Requirement: Codex wrapper trims the fixed context of every call
`.archon/scripts/codex-loop.sh` SHALL pass its `-c` overrides after the subcommand, turning off sub-agents, hooks, apps, tool suggestions, the skills catalog, the collaboration-mode and multi-agent hints, and the GUI and MCP tools. It SHALL run Codex with a `CODEX_HOME` that links every entry of the user's Codex home except `AGENTS.md` and `AGENTS.override.md`, so global instructions are not loaded while sessions still land in `~/.codex/sessions`.

#### Scenario: Codex wrapper passes its overrides after the subcommand
- **WHEN** the wrapper is run as `codex-loop.sh exec --experimental-json` with `CODEX_LOOP_BIN` set to a stub that logs its arguments
- **THEN** the stub's first argument is `exec`, `--experimental-json` follows the overrides, and the overrides include `skills.include_instructions=false`, `features.apps=false`, `features.tool_suggest=false`, `include_collaboration_mode_instructions=false`, `agents.enabled=false` and `features.hooks=false`

#### Scenario: Codex wrapper home mirrors the user's Codex home without global instructions
- **WHEN** the wrapper runs the stub with `CODEX_LOOP_USER_HOME` set to a directory holding `AGENTS.md`, `auth.json`, `config.toml` and `sessions/`, and `CODEX_LOOP_HOME` set to an empty directory
- **THEN** the stub sees `CODEX_HOME` equal to that `CODEX_LOOP_HOME`, whose `auth.json`, `config.toml` and `sessions` resolve to the user's entries, and which has no `AGENTS.md`

### Requirement: Codex wrapper refuses an untested Codex or a GUI or MCP tool
Before running Codex, `codex-loop.sh` SHALL run `codex_preflight.py`, which reads `codex --version`, the user's `config.toml` and the plugin cache's `.mcp.json` files without a model call. It SHALL exit 2, naming every reason on stderr and never running Codex, when the version is outside the tested range or an MCP server or GUI plugin stays enabled after the wrapper's `enabled=false` overrides.

#### Scenario: Codex wrapper refuses an untested Codex version
- **WHEN** the wrapper runs `exec` against a stub codex whose `--version` prints `codex-cli 0.99.0`
- **THEN** it exits 2, stderr names `0.99.0` and the tested range, and the stub never ran `exec`

#### Scenario: Codex wrapper refuses an MCP server or GUI plugin it does not turn off
- **WHEN** the wrapper runs `exec` with a user `config.toml` holding `[mcp_servers.extra]` and `[plugins."chrome-pilot@m"]` with `enabled = true`
- **THEN** it exits 2, stderr names `MCP server extra` and `GUI plugin chrome-pilot@m`, and the stub never ran `exec`

#### Scenario: Codex wrapper refuses a plugin's bundled MCP server
- **WHEN** the wrapper runs `exec` with a cached plugin `plugins/cache/m/tool/1.0/.mcp.json` declaring an enabled server `tool-server`
- **THEN** it exits 2, stderr names `MCP server tool-server (plugin tool@m)`, and the stub never ran `exec`

#### Scenario: Codex wrapper runs when every GUI tool and MCP server is off
- **WHEN** the user `config.toml` holds `[mcp_servers.computer-use]`, `[mcp_servers.idle]` with `enabled = false`, and `[plugins."browser@openai-bundled"]` with `enabled = true`, and the stub reports `codex-cli 0.153.4`
- **THEN** the wrapper exits 0 and the stub ran `exec`

### Requirement: Loop never opens anything on the host
No file under `.archon/` SHALL run `open`, `osascript`, `xdg-open` or a browser launcher, or pass `OPEN=1`. Every `preview` node SHALL run `make -s preview` with `OPEN=` (which beats an exported `OPEN`), and `make preview` SHALL print the absolute path of `preview.html`. Every `design-gate` message SHALL show `$preview.output` and say that nothing opens on the host.

#### Scenario: Loop automation launches no host application
- **WHEN** every file under `.archon/` is scanned line by line for host launchers
- **THEN** none matches, while the same scanner flags `open "$out"`, `subprocess.run(["open", p])`, `osascript -e x`, `xdg-open x`, `python3 -m webbrowser x` and `make preview OPEN=1`, and does not flag `open(path)`

#### Scenario: Design gate prints the preview path
- **WHEN** every workflow under `.archon/workflows/` is parsed and its `preview` and `design-gate` nodes are found (loop nodes included)
- **THEN** each `preview` node runs `make -s preview` with `OPEN=` as its last argument, and each `design-gate` message contains `$preview.output` and `nothing opens on the host`

#### Scenario: Preview prints the absolute preview path and opens nothing
- **WHEN** `make -s preview CHANGE=<a change in openspec/changes/> OPEN=` runs with `OPEN=1` in the environment and an `open` stub first on `PATH`
- **THEN** it prints one absolute path ending in `/openspec/changes/<change>/preview.html` and the `open` stub never ran

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

### Requirement: Codex skill preflight does not depend on the network
`codex plugin list --json` exits 0 but omits every remote plugin when its catalog request fails, warning `failed to list remote marketplace plugins` on stderr. On that warning, the codex preflight SHALL add each remote plugin of the plugin cache (`plugins/cache/<market>/<name>/` with `.codex-remote-plugin-install.json`) at its newest cached version, installed and enabled.

#### Scenario: Skill preflight resolves a cached Codex plugin when the remote catalog fails
- **WHEN** the check of a codex repo declaring `superpowers:writing-plans` runs with a stub `codex` that lists no plugin and prints that warning, `CODEX_HOME` holding the remote superpowers 6.4.2 cache with `writing-plans` and its install marker, and `AGENTS_SKILLS_DIR` holding `writing-plans/SKILL.md`
- **THEN** it exits 0

### Requirement: Agents start with durable loop lessons
The fix workflow's exploration prompt and every implementation pass SHALL read the curated `Loop lessons` section in `docs/workflow.md` after loading required skills and before investigating or changing the project.

#### Scenario: Fix and implement prompts read loop lessons
- **WHEN** the fix/explore and implement command sources are read in a headless child Neovim
- **THEN** both direct the agent to read the `Loop lessons` section of `docs/workflow.md` before starting their task

### Requirement: Corrected attempt failures become bounded lessons
The judge (escalation) after the build loop SHALL append a supplied one-line lesson only for a failure from an earlier attempt that a later attempt reports fixed; a build pass's verdict SHALL never edit docs/workflow.md. It SHALL normalize whitespace, compare lessons case-insensitively, retain only one copy, keep at most the 10 newest lesson lines without changing other workflow documentation, and clear the persisted candidates.

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

#### Scenario: Build passes leave workflow docs unchanged
- **WHEN** `.archon/scripts/verdict.py` runs in a throwaway checkout while `lesson-candidates.txt` holds a lesson
- **THEN** `docs/workflow.md` is unchanged and the checkout has no uncommitted change

#### Scenario: Persisted lesson candidates are cleared
- **WHEN** the judge persists a lesson candidate and runs again on a workflow doc without that lesson
- **THEN** `lesson-candidates.txt` is empty after the first run and the second run adds no lesson

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

#### Scenario: Judge ignores a plugin spec moved into dependencies
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that moves plugin `a/dap-ui` from its own spec into `a/dap`'s `dependencies`
- **THEN** its JSON `decision` is `ship` (plugin names compared, not lines)

#### Scenario: Judge ships an internal change without asking
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that only adds an internal Lua module
- **THEN** its JSON is `{decision = "ship", escalate = false, reasons = "- none"}`

#### Scenario: Verdict sends hard-rule violations back to fix
- **WHEN** `.archon/scripts/verdict.py` runs with every gate green on a branch that removes a test case
- **THEN** it reports `passed` false, `done` false, `failed_gates` `rules`, and `feedback` names the removed case

#### Scenario: A rejected judge never ships
- **WHEN** `.archon/scripts/decide.py` runs with `INPUTS_VERDICT=reject` and no gate decision
- **THEN** its JSON `go` is false

### Requirement: Loop keeps the user's contract
The loop SHALL leave the user's contract to the user: no step changes a requirement's bounds or the `## Decision` text unasked, main specs change only by archive, and a `## Blocked` section in a change's proposal.md or tasks.md stops agent work on it, is quoted to the user, and never ships.

#### Scenario: Queue spec prompt keeps the user's contract
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** it forbids changing a requirement's numbers or bounds, removing a requirement to add it again and rewording `## Decision`, and keeps any `## Blocked` section

#### Scenario: Judge asks when a change re-adds a removed requirement
- **WHEN** `.archon/scripts/escalation.py` runs on a branch whose change delta REMOVES requirement `Server readiness` and ADDS `Server readiness.` (a near name)
- **THEN** its JSON `decision` is `ask` and `reasons` names the re-added requirement

#### Scenario: Judge asks when a change rewrites the user's Decision
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that rewords the `## Decision` section of a proposal on `auto`, and on one that edits only its `## Why`
- **THEN** the first JSON `decision` is `ask` with a reason naming the proposal, and the second is `ship`

#### Scenario: Adopt reverts main spec edits
- **WHEN** `.archon/scripts/adopt.py` merges a branch that edits and adds files under `openspec/specs/` and edits another file
- **THEN** `openspec/specs/` equals the pre-merge state in a new commit, the other edit is kept, and the summary names the reverted spec

#### Scenario: Blocked queued change goes straight to the user
- **WHEN** `.archon/scripts/blocked.py` runs for a change whose proposal.md has a `## Blocked` section, and for one without
- **THEN** the first prints `blocked` true with the section text and writes an `ask` escalation.md quoting it; the second prints `blocked` false

#### Scenario: Verdict ends the build loop on a Blocked section
- **WHEN** `.archon/scripts/verdict.py` runs on the first red pass for a change whose tasks.md has a `## Blocked` section
- **THEN** it reports `done` true, `blocked` true and `exhausted` false

#### Scenario: Judge quotes a Blocked section and asks
- **WHEN** `.archon/scripts/escalation.py` runs with `exhausted` true for a change whose tasks.md has a `## Blocked` section
- **THEN** its JSON `decision` is `ask` and escalation.md quotes the Blocked text

#### Scenario: A blocked run never ships
- **WHEN** `.archon/scripts/decide.py` runs with `INPUTS_BLOCKED=true`, verdict `ask` and gate decision `approve`
- **THEN** its JSON `go` is false and `decision` is `reject` (followup re-queues it)

### Requirement: Active change scenarios participate in traceability
Traceability SHALL count scenarios added by active change deltas while excluding archived changes and
scenarios under `## REMOVED Requirements`.

#### Scenario: Trace counts scenarios an active change adds
- **WHEN** `make trace` runs where an active change (`openspec/changes/<id>/specs/<capability>/spec.md`) adds a scenario that a test names, and an archived change and a `## REMOVED Requirements` section list other scenarios
- **THEN** the added scenario is tested, the archived and removed ones are not scenarios, and nothing is orphan

### Requirement: Trace rejects duplicate case names
Traceability SHALL fail when one case name is used in more than one test file and list that name with every file that uses it.

#### Scenario: Trace fails on a case name in two test files
- **WHEN** `make trace` runs where a unit and an integration test file both define a case with the same scenario name
- **THEN** it exits non-zero and lists the name with both file paths under duplicate cases

### Requirement: Red gates send every failed section to fix
The build gate SHALL save the check log without ANSI codes and send the next fix pass the exact log path, the status lines, the head of every failed target section in log order (lint first) and the failing test cases (`FAIL in …`), within the feedback budget. LuaLS progress lines SHALL not appear in the types output.

#### Scenario: Gate failures keep an early lint section
- **WHEN** `.archon/scripts/gate.py` runs where `make check` prints a red log whose lint section comes first and whose test section ends in many lines of output
- **THEN** its `failures` name `check-1.log`, the status lines, the lint error, every failing test case and no ANSI codes

#### Scenario: Types output drops LuaLS progress lines
- **WHEN** `tests/types.sh` runs where lua-language-server prints `>>>>=== 12/369 [Found 5 problems in 1 files]` progress lines and a diagnostic
- **THEN** the output holds the diagnostic and no progress line

### Requirement: Loop test runs give language servers a long timeout
Tests that wait for a real language server SHALL take their timeout from `H.lsp_timeout(default)`: `$LSP_TIMEOUT_MS` when it is a positive integer, else the default, so interactive runs keep their timeout. The build gate SHALL run `make check` with `LSP_TIMEOUT_MS=120000` unless it is already set, since gopls can take minutes to load.

#### Scenario: Gate gives language servers a long timeout
- **WHEN** `.archon/scripts/gate.py` runs without `LSP_TIMEOUT_MS` set and a stubbed `make`
- **THEN** `make` sees `LSP_TIMEOUT_MS=120000`

#### Scenario: LSP waits in tests honor LSP_TIMEOUT_MS
- **WHEN** `H.lsp_timeout(10000)` is called with `LSP_TIMEOUT_MS` unset, empty, `abc`, `0` and `120000`
- **THEN** it returns 10000, 10000, 10000, 10000 and 120000

### Requirement: Fix pass reruns failed files and guards references
The fix command SHALL rerun every test file named in a `FAIL in …` line of the latest check log plus `tests/screen/<area>` of the touched area (never make check), read only the latest check log with bounded context, and regenerate a reference screenshot only when the cell diff is limited to UI a named merged or base commit changed.

#### Scenario: Fix prompt reruns failed files and names reference commits
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it reruns every file named by `FAIL in` plus `tests/screen/<area>`, forbids `check-*.log` globs and broad `rg` over `lua tests`, and allows a reference regeneration only for UI a named commit changed

### Requirement: Task loop skips implement when no task is left
The context pack SHALL report whether a task is left (`has_task`), and the task loop SHALL run the implement session only when one is.

#### Scenario: Context pack reports when no task is left
- **WHEN** `.archon/scripts/context_pack.py` runs on a change whose tasks are all ticked, and on one with an unchecked task
- **THEN** it prints `has_task` false for the first and true for the second, and the nvim-deliver implement node runs only when `has_task` is true

### Requirement: Smoke startup fails on a startup error
The smoke startup timing SHALL fail when a timed start exits non-zero or writes an error to stderr, instead of reporting only its time.

#### Scenario: Startup timing fails on a startup error
- **WHEN** `make smoke-startup` runs with a config whose init.lua raises an error
- **THEN** it exits non-zero and prints the error
