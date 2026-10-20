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
After a judge reject, `.archon/scripts/followup.py` SHALL re-queue the work on `auto` under the ship lock with no second change for the same work: when `openspec/changes/<change>/proposal.md` is on `auto`, it SHALL rewrite that proposal to hold one `Adopt: <rejected branch>` line and one `## Rejected run` section with the judge's reasons; otherwise it SHALL queue a new change `followup-<change>` that adopts the branch, and leave no worktree of its own on any exit. It prints `{queued, change}`.

#### Scenario: Rejected active change is re-queued in place
- **WHEN** `python3 .archon/scripts/followup.py` runs with `INPUTS_CHANGE=x` and `INPUTS_REASONS` in a worktree on `loop/x-20260101` of a throwaway repo whose main checkout is on `auto` and holds `openspec/changes/x/proposal.md` with `Kind: bug`, an `Adopt: loop/x` line and an old `## Rejected run` section
- **THEN** it prints `queued` true and `change` `x`, no `openspec/changes/followup-x` exists on `auto`, the proposal's only `Adopt:` line is `Adopt: loop/x-20260101`, it has one `## Rejected run` section holding the new reasons and not the old ones, the latest `auto` commit is `chore(openspec): re-queue x from loop/x-20260101`, and no ship lock file remains

#### Scenario: Rejected run quotes the review findings
- **WHEN** followup.py re-queues active change `x` with `INPUTS_REASONS` holding `- review findings:` and indented finding lines, one of them `  ## Removed assert`
- **THEN** the proposal's `## Rejected run` section holds each finding line as given and the proposal has no heading beyond `## Why`, `## What Changes`, `## Impact` and `## Rejected run`, and findings over 4000 characters are cut between findings, never inside one

#### Scenario: Adopt line is added to a proposal without one
- **WHEN** followup.py re-queues a change whose proposal has a `Kind:` line and no `Adopt:` line, and one whose proposal has neither (only `## Why` and `## What Changes`)
- **THEN** the first gets `Adopt: <branch>` on the line after `Kind:`, the second at the end of `## Why`, before `## What Changes`

#### Scenario: Rejected archived change gets a follow-up change
- **WHEN** followup.py runs with `INPUTS_CHANGE=x` where `auto` has no `openspec/changes/x/proposal.md`
- **THEN** it prints `queued` true and `change` `followup-x`, and `openspec/changes/followup-x/proposal.md` on `auto` has the line `Adopt: <branch>` and the reasons

#### Scenario: Follow-up leaves no worktree when checkout fails
- **WHEN** followup.py runs where `auto` is checked out in no worktree and a `post-checkout` hook exits 1, then again without the hook
- **THEN** the first run exits non-zero with empty stdout, leaves `auto`, `git worktree list` and the ship lock as before; the second queues `followup-x` and leaves `git worktree list` as before

### Requirement: Queue waits for a change's dependencies
`.archon/scripts/queue_pick.py` SHALL not pick a change whose proposal.md has a `Depends: <change>[, <change>]` line until every named change is archived under `openspec/changes/archive/`, whether it is picked automatically or named by `INPUTS_CHANGE`.

#### Scenario: Queue waits for archived dependencies
- **WHEN** `python3 .archon/scripts/queue_pick.py` runs in a throwaway repo where the older change `t-a` has `Depends: t-b` and the newer `t-b` is active, without and with `INPUTS_CHANGE=t-a`, then again without it after `t-b` moved to `openspec/changes/archive/2026-01-03-t-b/`
- **THEN** the first run picks `t-b`, the named run finds nothing and its stderr names `t-b`, and the last run picks `t-a`

### Requirement: Drain works the queue one run at a time
`make drain [N=<max runs>]` SHALL work queued changes one at a time through a foreground `make queue CHANGE=<id>` (never `--detach`), read each run's status from the newest row of its run in the Archon DB, run a change with a `## Blocked` section like any other (its unblock step settles it), go on after a failed run, run no change twice, and stop when the queue is empty, after N runs, at a paused run (no node pauses: a defensive stop), or (exit 1) at a run the stop-infra node cancelled.

#### Scenario: Drain works queued changes until the queue is empty
- **WHEN** `make drain` runs via `vim.system` in a throwaway repo with `ARCHON` stubbed to record runs in a throwaway `ARCHON_DB` and changes `t-a`, `t-b` (with a `## Blocked` section) and `t-c`, oldest first, where the run of `t-a` fails and the run of `t-c` completes
- **THEN** it exits 0, Archon is asked for foreground work-queue runs of `t-a`, `t-b` and `t-c`, each once, and the output reports `t-a` failed and the queue empty

#### Scenario: Drain stops after N runs
- **WHEN** `make drain N=1` runs with the same stubs and two runnable changes
- **THEN** it exits 0 after exactly one work-queue run, of the older change

#### Scenario: Drain stops at a paused run
- **WHEN** `make drain` runs where the first run is recorded `paused` and a second change is queued
- **THEN** it exits 0, starts no second run and its output names the paused change as a loop bug

#### Scenario: Drain stops when the sandbox infra fails
- **WHEN** `make drain` runs where the first run is cancelled, the second is cancelled by the stop-infra node (its `workflow_cancelled` event) and a third change is queued
- **THEN** it goes on after the first, starts no third run, exits non-zero and prints one line naming the second change and the sandbox infra

#### Scenario: Drain runs each change in the foreground
- **WHEN** `make drain` runs with the same stubs and one runnable change
- **THEN** it exits 0, no Archon call gets `--detach`, and the run's output and `completed` status appear in drain's output

### Requirement: Drains run lanes in parallel
`make drains [LANES=2]` SHALL run that many drains at once with output lines prefixed `[lane <k>]`, never start one change in two lanes (a pick lock held until the run is recorded, a shared skip list), let a lane whose pick is empty wait while a live run works a change the remaining changes depend on, and first print each `Depends:` edge whose two changes share no `## Impact` path. More than `DRAIN_MAX_LANES` (default 2) lanes SHALL be refused.

#### Scenario: Drains run two lanes and never take one change twice
- **WHEN** `make drains` runs with the drain stubs on `t-a` (a 3 s run recorded `running` first, then `failed`, Impact `lua/gleb/a/{x,y}.lua`), `t-b`, `t-c`, and `t-d` (`Depends: t-a`, Impact `lua/gleb/d/z.lua`)
- **THEN** it exits 0, `t-a`, `t-b` and `t-c` each run once, lane 1 starts `t-a` while lane 2 starts `t-b`, both lanes end on an empty queue, and the output names `t-d Depends: t-a` as sharing no Impact path; no run sees `DRAIN_SKIP_FILE`; `make drains LANES=3` exits non-zero with `at most 2 lanes`

### Requirement: Done loop runs are cleaned up
`.archon/scripts/loop_clean.py` SHALL remove the worktree and branch of each `loop/*` branch whose tip is on `auto` (shipped or superseded), and keep and list `auto`/`main`, branches with commits not on `auto` or at its tip, branches a running or paused Archon run holds, and dirty worktrees. `make loop-clean` is a dry run unless `APPLY=1`; ship starts the cleanup of its own run.

#### Scenario: Loop clean dry run lists and removes nothing
- **WHEN** `make loop-clean` runs via `vim.system` in a throwaway repo with a shipped `loop/t-a` with a worktree, a superseded `loop/t-b`, an unmerged `loop/t-c`, a shipped `loop/t-d` whose worktree has uncommitted changes and a shipped `loop/t-e` a running Archon run holds (`ARCHON_DB`)
- **THEN** it exits 0, lists `t-a` and `t-b` to remove and `t-c`, `t-d` and `t-e` kept with their reasons, and every branch and worktree still exists

#### Scenario: Loop clean apply removes only done runs
- **WHEN** `make loop-clean APPLY=1` runs in that repo, and `loop_clean.py --branch auto --apply` runs after it
- **THEN** `loop/t-a` with its worktree and `loop/t-b` are gone, `loop/t-c`, `loop/t-d` with its edit and `loop/t-e` remain, and `auto` is kept

#### Scenario: Ship cleans up its run after the run ends
- **WHEN** `ship.py` merges a run from its worktree, once with no Archon DB and a parent shell that exits, and once with `ARCHON_DB` holding a running run in that worktree and `LOOP_CLEAN_WAIT=2`
- **THEN** the first run's worktree and branch are removed; the second's remain and `nvim-loop-clean.log` reports the run still live

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

### Requirement: Ship gates a merge onto a moved auto
When `auto` has commits the run's branch lacks, `.archon/scripts/ship.py` SHALL make the merge in a temporary worktree and run `make -s lint trace specs` on it before updating `auto`; when they fail it SHALL leave `auto` unchanged and report `merged` false, `conflict` true, `gate_failed` true and the gate output in `log`, so the deliver flow reconciles the branch.

#### Scenario: Ship does not merge a result that fails the static gates
- **WHEN** `ship.py` runs with `INPUTS_ON_CONFLICT=report` in a throwaway repo whose Makefile's `trace` fails on a duplicated case name, for a branch adding case `dup` after `auto` added the same case in another file, and then for a second branch with a distinct case
- **THEN** the first exits 0 with `merged` false, `conflict` true, `gate_failed` true and a `log` naming `dup`, and `auto` is unchanged and clean; the second merges

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
`.archon/scripts/codex-loop.sh` SHALL pass its `-c` overrides after the subcommand, turning off sub-agents, hooks, apps, tool suggestions, the skills catalog, the collaboration-mode and multi-agent hints, and the GUI and MCP tools, and cap each tool output at 6000 tokens. It SHALL run Codex with a `CODEX_HOME` that links every entry of the user's Codex home except `AGENTS.md` and `AGENTS.override.md`, so global instructions are not loaded while sessions still land in `~/.codex/sessions`.

#### Scenario: Codex wrapper passes its overrides after the subcommand
- **WHEN** the wrapper is run as `codex-loop.sh exec --experimental-json` with `CODEX_LOOP_BIN` set to a stub that logs its arguments
- **THEN** the stub's first argument is `exec`, `--experimental-json` follows the overrides, and the overrides include `skills.include_instructions=false`, `features.apps=false`, `features.tool_suggest=false`, `include_collaboration_mode_instructions=false`, `agents.enabled=false`, `features.hooks=false` and `tool_output_token_limit=6000`

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
No file under `.archon/` SHALL run `open`, `osascript`, `xdg-open` or a browser launcher, or pass `OPEN=1`. Every `preview` node SHALL run `make -s preview` with `OPEN=` (which beats an exported `OPEN`), and `make preview` SHALL print the absolute path of `preview.html`. No workflow node SHALL be an `approval` gate: the preview is an artifact, never a pause.

#### Scenario: Loop automation launches no host application
- **WHEN** every file under `.archon/` is scanned line by line for host launchers
- **THEN** none matches, while the same scanner flags `open "$out"`, `subprocess.run(["open", p])`, `osascript -e x`, `xdg-open x`, `python3 -m webbrowser x` and `make preview OPEN=1`, and does not flag `open(path)`

#### Scenario: Preview prints its path and no node pauses
- **WHEN** every workflow under `.archon/workflows/` is parsed and its nodes are walked (loop nodes included)
- **THEN** each `preview` node runs `make -s preview` with `OPEN=` as its last argument, and no node has an `approval` key

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
The judge SHALL append a supplied one-line lesson only for an earlier attempt's failure a later attempt reports fixed; a pass's verdict SHALL never edit docs/workflow.md. It SHALL normalize whitespace, let a candidate replace an exact or near duplicate (80% word overlap), drop `loop:` candidates and those of a pass whose review rejected the change, keep the 15 newest lessons without changing other docs, and clear persisted candidates.

#### Scenario: Passing retry records its corrected failure
- **WHEN** a later build attempt passes after an earlier failed attempt and supplies the one-line lesson `Under host load, scale startup budgets before diagnosing a regression`
- **THEN** the `Loop lessons` section contains that lesson exactly once

#### Scenario: Exhausted run retains a corrected earlier failure
- **WHEN** the build loop exhausts its final attempt but supplies a one-line lesson for a different earlier-attempt failure that the later attempt fixed
- **THEN** the escalation path records that lesson in the `Loop lessons` section before reporting the exhausted run

#### Scenario: Repeated lessons stay deduplicated and bounded
- **WHEN** the verdict/escalation path is invoked in a throwaway checkout with a lesson that differs from an existing lesson only by case or repeated whitespace, followed by enough distinct fixed lessons to exceed the limit
- **THEN** the equivalent lesson occurs once, the section contains the 15 newest lesson lines, and text outside the section is unchanged

#### Scenario: Unfixed failures do not become lessons
- **WHEN** an attempt fails and no later attempt supplies a lesson saying that failure was fixed
- **THEN** the verdict/escalation path does not add a lesson for that failure

#### Scenario: Build passes leave workflow docs unchanged
- **WHEN** `.archon/scripts/verdict.py` runs in a throwaway checkout while `lesson-candidates.txt` holds a lesson
- **THEN** `docs/workflow.md` is unchanged and the checkout has no uncommitted change

#### Scenario: Near-duplicate and loop tooling lessons are not kept
- **WHEN** the judge persists a candidate whose words nearly match an existing lesson, and candidates starting with `loop:` or `LOOP:`
- **THEN** the candidate replaces the near duplicate at the end of the section and no `loop:` candidate is written

#### Scenario: Lessons of a pass the review rejected are not kept
- **WHEN** a verdict with review approval false ends a pass that appended a candidate, and a later approved pass appends another
- **THEN** the rejected pass's candidate is removed from `lesson-candidates.txt` and the judge persists only the earlier and the approved candidates

#### Scenario: Persisted lesson candidates are cleared
- **WHEN** the judge persists a lesson candidate and runs again on a workflow doc without that lesson
- **THEN** `lesson-candidates.txt` is empty after the first run and the second run adds no lesson

### Requirement: Small steps with a script judge
The delivery loop SHALL implement one task per fresh agent session from a script-built context pack, count only real checkbox list items as tasks, send only a failing pass's findings to the next fix step, and decide shipping by script: reject partial or rule-breaking work, never ask the user, and ship everything else (a breaking change with a note).

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

#### Scenario: Judge resolves an xfail reason held in a local
- **WHEN** escalation.py runs on a branch whose test file has `local WHY = "queued-x: reason"` and an `H.xfail(` call split over lines that passes `WHY`, once with `openspec/changes/queued-x/` present and once without
- **THEN** the first decision is not `reject` and the second is `reject`

#### Scenario: Judge ships a breaking change with a note
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that adds a `vim.keymap.set` line to `lua/gleb/keymaps.lua`
- **THEN** its JSON `decision` is `ship`, `escalate` is false and `reasons` has `- note: breaking: changes core keymaps`

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

### Requirement: Hard rules run first and spare moved test files
`.archon/scripts/gate.py` SHALL check the hard rules before `make check`: a violation is a red gate whose failures are its `hard rule:` lines, with no `make check` and no review, and verdict SHALL not repeat them. A deleted test file SHALL be no violation when every case it held still exists by name in another test file and no case is lost.

#### Scenario: Gate checks hard rules before make check
- **WHEN** gate.py runs on a branch that empties a test file, with a `make` stub that records being called, and verdict.py runs on its failures
- **THEN** gate's `green` is false, its failures name `hard rule: 1 test case(s) removed: a: one`, make never ran, and verdict's feedback names the removed case once

#### Scenario: Judge ships a deleted test file whose cases all moved
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that deletes a test file whose case `c: kept` now lives in another test file, and on one where the other file holds only `c: other`
- **THEN** the first `decision` is `ship`; the second is `reject` with `test files deleted:` naming the file

#### Scenario: A title-only REMOVED requirement plans its main-spec scenarios
- **WHEN** `integrity.planned_removals` reads a change delta whose `## REMOVED Requirements` names a requirement by title with only Reason and Migration lines
- **THEN** it returns that requirement's scenarios from the main spec as `<capability>: <scenario>`, and no other requirement's; a REMOVED requirement that lists scenarios removes only those

#### Scenario: Judge ships a test the change's spec delta removes
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that deletes a test file whose only case `c: dropped` is a scenario a change's spec delta lists under `## REMOVED Requirements`, and on one where the deleted file also held `c: kept`
- **THEN** the first has neither `test files deleted` nor `test case(s) removed`; the second is `reject` naming `c: kept` and not `c: dropped`

### Requirement: Fix pass stays on its findings
verdict.py SHALL snapshot the change's proposal.md, `.openspec.yaml` and spec deltas at the end of each pass; the next gate.py SHALL list in `$ARTIFACTS_DIR/fix-scope.md` those the fix pass changed, for the review (and verdict feedback when no review ran). The fix prompt SHALL keep to the listed findings and load no skill when every finding is a hard rule.

#### Scenario: Gate lists planning files a fix pass edited
- **WHEN** verdict.py ends a pass of change `c`, then proposal.md and tasks.md are edited and gate.py runs, then verdict.py and gate.py run again with no edit
- **THEN** fix-scope.md names proposal.md and not tasks.md, the red verdict's feedback carries it, the second gate removes it, and review.md reads it

#### Scenario: Gate skips the fix-scope check once the change is archived
- **WHEN** gate.py runs after verdict snapshotted change `c` and the change folder has since been archived (moved away)
- **THEN** it writes no `fix-scope.md`

#### Scenario: Gate names the overlong delta requirement and its repro
- **WHEN** gate.py runs for change `c` whose session delta requirement `Restore on bare startup` is over 500 characters and `openspec validate` fails
- **THEN** its failures name the reproduce command `python3 .archon/scripts/spec_trial.py c` and that requirement with its length and the 500 limit

#### Scenario: Fix prompt stays on the listed findings
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it loads no skill when every finding starts with `hard rule:` and never edits proposal.md, .openspec.yaml or spec deltas unless a finding is about them

### Requirement: Build keeps the test cases it added
verdict.py SHALL snapshot the test case names at the end of each pass. The next gate.py SHALL report each snapshot name in neither the worktree's tests nor the base as the hard rule `test added then removed during build: <names>` and record it; the judge SHALL reject while a recorded name is still missing.

#### Scenario: Gate flags a test case added then removed during build
- **WHEN** verdict.py ends a pass on a branch that adds case `a: new` to a test file holding base case `a: old`, both are then removed and gate.py runs, then verdict.py and gate.py run again and the judge runs
- **THEN** the first gate is red naming `hard rule: test added then removed during build: a: new` and not `a: old`, the second gate does not repeat it, and the judge rejects with that reason

#### Scenario: Judge ships once a dropped test case is restored
- **WHEN** gate.py recorded `a: new` as dropped and the case is back in a test file when the judge runs
- **THEN** the judge's decision is `ship`

### Requirement: Test runs record the cases they collect
With `ARTIFACTS_DIR` set, tests/parallel.lua SHALL add each collected case (file, name) to `$ARTIFACTS_DIR/case-seen.json`. gate.py SHALL treat the names of case-snapshot.json and case-seen.json alike, so a case added and removed within one pass that is on neither the base nor the branch is the dropped-case hard rule; verdict.py SHALL clear case-seen.json when it snapshots.

#### Scenario: Test run records the cases it collected
- **WHEN** tests/parallel.lua runs one test file holding `seen: probe` with `ARTIFACTS_DIR` holding a case-seen.json that lists `a: earlier`
- **THEN** it exits 0 and case-seen.json lists `a: earlier`, then `seen: probe` with its file

#### Scenario: Gate flags a test case added and removed within one pass
- **WHEN** verdict.py snapshots a branch holding base case `a: old`, case-seen.json then lists `a: old` and `a: tmp`, and gate.py, verdict.py and gate.py run
- **THEN** the first gate is red naming `hard rule: test added then removed during build: a: tmp` and not `a: old`, verdict removes case-seen.json, and the second gate does not repeat it; a seen case its file still names as a quoted string (a variable-keyed `T[scenario]["…"]`) a case from a file outside tests/, and a case of a file that names nested cases from data (`T[s][language.name] = function`) are never flagged

### Requirement: Gate merges a moved auto first
The build loop's gate SHALL first merge `auto` into the run's branch when `auto` has commits the branch lacks, the worktree has no tracked edits and the merge is clean (`.archon/scripts/sync_base.py`); a conflicting merge SHALL be aborted and the gate SHALL run on the branch as it is.

#### Scenario: An auditor Decision runs the spec step
- **WHEN** `spec_ready.py` runs on a finished folder whose proposal.md has a `## Decision (auditor, …)` section, and `.archon/commands/queue-spec.md` is read
- **THEN** the folder is not ready (the spec step runs) and queue-spec applies the Decision's scenarios to the delta and its task splits, tests and gates to tasks.md without dropping any

#### Scenario: An unfinished spec pass reruns the spec step
- **WHEN** `spec_ready.py` routes a change to the spec step, `spec_gate.py` runs while the `spec-pending` marker is left, and `.archon/commands/queue-spec.md` and the work-queue spec nodes are read
- **THEN** spec_ready.py writes `$ARTIFACTS_DIR/spec-pending`, the gate is red with "the spec step did not finish", queue-spec removes the marker as its last step, and `complete` and `spec-retry` set `idle_timeout: 900000`

#### Scenario: Each task's context pack merges a moved auto first
- **WHEN** the nvim-deliver `pack` node and `.archon/scripts/context_pack.py` are read
- **THEN** the pack passes `sync_base: "true"` and context_pack.py calls `sync()` before it reads the change

#### Scenario: Gate merges a moved auto first
- **WHEN** the nvim-deliver gate node and `.archon/scripts/gate.py` are read, and `sync_base.py` runs in a repo whose `auto` moved after the branch forked: once clean, once with a tracked edit, once with a conflicting commit
- **THEN** the gate passes `sync_base: "true"` and gate.py calls `sync()` before any check; the clean branch then contains `auto`'s commit, the edited one is left unmerged, and the conflicting merge is aborted with a clean worktree

### Requirement: Gate skips a Blocked change
gate.py SHALL check for a blocking `## Blocked` section (blocked.py) before anything else and then print a red verdict with `blocked` true and the Blocked text as failures, with no `make check` and without counting the pass as an attempt; nvim-deliver's review node SHALL run only when the gate's `blocked` is false.

#### Scenario: Gate reports a Blocked change before make check
- **WHEN** gate.py runs for a change whose tasks.md has a `## Blocked` section, with a `make` stub that records being called
- **THEN** `green` is false, `blocked` is true, failures quote the Blocked section, make never ran, a second run reports the same `attempt`, and the review node's `when:` requires `$gate.output.blocked == false`

### Requirement: Stuck attempts keep the red test
The fix and implement commands SHALL run one headless probe before editing for a non-obvious failure and cap attempts at 2; when the second fails they SHALL save its non-test diff to `$ARTIFACTS_DIR/stuck-attempt-<task>.diff` (one file per stuck task) for the next pass, revert only non-test edits, write `## Stuck` with the probe output and both attempts, and commit the failing test with it.

#### Scenario: The task loop ends when only gates wait on a stuck task
- **WHEN** `tasks.py`'s loop check runs on a tasks.md whose only unticked work besides a stuck task is a task with no `Scenarios:` line whose every item runs `make` (a final gates task), then on the same file without the Stuck section
- **THEN** the first ends the task loop and the second does not

#### Scenario: Stuck attempts keep the red test
- **WHEN** `.archon/commands/fix.md` and `implement.md` are read
- **THEN** each asks for the probe first, caps attempts at 2, saves the second attempt, new files included (`git add -N`), to `stuck-attempt-<task>.diff` (fix may `git apply` that task's file), never stubs a task that needs the stuck task's code, reverts only non-test edits, writes `## Stuck` with the probe output and both attempts, commits the failing test with tasks.md, and no longer says to revert the uncommitted edits

### Requirement: Fix pass probes before it edits
The fix command SHALL run one headless scratch-file probe logging the relevant state before editing code for a non-obvious failure, allow at most 2 implementation attempts per pass and then write `## Stuck` with the probe evidence, and forbid production timers or sleeps that race a plugin's internals unless the proposal's `## Decision` allows them.

#### Scenario: Fix feedback keeps a failing case's message
- **WHEN** `check_log.summarize` reads a red test section with 30 passed nested sets (`: oooo`) and one `FAIL in` line whose message runs past 160 characters, and `.archon/commands/fix.md` is read
- **THEN** the summary holds the whole message and none of the passed sets, and fix.md never lets an owned failing case pass as transient without a commit: it reruns that case 5 times, then its file and its directory once each, or writes `## Stuck`

#### Scenario: Fix prompt probes first and caps attempts
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it asks for one headless probe before editing a non-obvious failure, caps attempts at 2 per pass then `## Stuck` with the probe output, forbids timers or sleeps against plugin internals without a `## Decision`, and lets a `## Decision` override any review finding it covers, carried-over ones too

### Requirement: Bug root cause carries evidence
The spec prompts SHALL give a bug proposal an `## Evidence` section of `file:line` refs or probe output for its root cause; context_pack.py SHALL carry that section into context.md, and the implement prompt SHALL not re-read plugin source the Evidence covers.

#### Scenario: Context pack carries the proposal's evidence
- **WHEN** `.archon/scripts/context_pack.py` runs for a change whose proposal.md has an `## Evidence` section, and for one without
- **THEN** the first context.md has an `## Evidence` section with its refs before the Loop lessons; the second has none

#### Scenario: Spec prompts require root-cause evidence
- **WHEN** `.archon/commands/queue-spec.md`, `spec-bug.md` and `implement.md` are read
- **THEN** both spec prompts require an `## Evidence` section of `file:line` refs or probe output, and implement does not re-read plugin source the Evidence covers

### Requirement: Judge lists minor review findings as notes
verdict.py SHALL pass on the last review's findings even when it approves; on ship the judge SHALL list each finding marked minor or non-blocking (`[minor]`, or under a `Minor (non-blocking):` heading) as a `- note:` line of escalation.md, never as a reason.

#### Scenario: Judge notes minor review findings on ship
- **WHEN** verdict.py passes with an approving review whose findings hold a `[minor]` line and a `Minor (non-blocking):` heading with one item, and the judge runs on verdict's `review_findings`
- **THEN** the decision is `ship` and escalation.md has a `- note: review (minor):` line for each of the two, and none for the summary line

### Requirement: Gate runs a quick tier first
gate.py SHALL first run `make check CHECK_TARGETS="lint types trace specs test"` with `CAPS` the capabilities the branch diff touches (`lua/gleb/<area>`, `tests/<layer>/<cap>`; `loop` plus `loop-test` for `.archon/`; empty for an unmapped file); red (after reruns) ends the gate, green runs the full `make check E2E=1`. Planning and docs only, or a shortcut-layer or sandbox path, runs the full check alone.

#### Scenario: Gate runs the quick tier before the full check
- **WHEN** gate.py runs with a recording `make` stub on branches editing `lua/gleb/pr/` and its tests (quick tier red, then green), `.archon/`, `init.lua`, only docs and a change folder, and `lua/gleb/pr/` with `tests/e2e/`
- **THEN** the red quick tier is the only call (`CAPS=pr`, noted in the check log); green adds `make check E2E=1` and keeps `quick-1.log`; `.archon/` adds `loop-test` with `CAPS=loop`; `init.lua` runs `CAPS=` empty; the last two run only the full check

### Requirement: Gate reruns known flaky cases up to three times
A failing case listed in `tests/flaky.txt` (`<file> | <case>`, by name prefix) that gate.py would rerun SHALL rerun up to 3 times, serially, and count as flaky on its first pass; other cases rerun once. A branch adding a case to `tests/flaky.txt` SHALL be a hard rule.

#### Scenario: Gate reruns a known flaky case up to three times
- **WHEN** gate.py runs with a `make` stub whose check fails one case listed in the base's `tests/flaky.txt`, its rerun passing on the 3rd try, then never; then the case unlisted, passing on the 2nd try; then a branch adding it to `tests/flaky.txt`
- **THEN** the first is green after 3 reruns with the case in `flaky`; the second red after 3; the third red after 1; the fourth red with `hard rule: tests/flaky.txt gains a case on this branch`

### Requirement: Gate reruns failed test cases once
When `make check` fails only in `test`, `test-readiness` or `e2e`, gate.py SHALL rerun each `FAIL in` case once, serially (`make test FILE=<file> CASE=<name>`, `make test-readiness CASE=<name>`); e2e only when its log has no `FAIL in` and only sandbox/Lume infra lines (`make e2e E2E=1`). All passing: green, listed in `flaky` and the check log, a judge note. A rerun failing stays red; other targets never rerun.

#### Scenario: Gate passes a test case that passes on rerun
- **WHEN** gate.py runs with a `make` stub whose check fails in `test` on one case and whose rerun passes, then one whose rerun fails, then one whose check fails in `lint test`, and verdict and the judge run on the first gate's `flaky`
- **THEN** the first gate is green with that case in `flaky` and the check log; the second is red; the third is red with no rerun; the verdict passes and the judge ships with a `- note:` naming the case

#### Scenario: Gate reruns a failed readiness case once
- **WHEN** gate.py runs with a `make` stub whose check fails in `test-readiness` on one case and whose rerun passes, then one whose rerun fails
- **THEN** the first gate reruns `make test-readiness CASE=<name>` and is green with the case in `flaky` and the check log; the second is red

#### Scenario: Gate reruns a case a hung worker left unrun
- **WHEN** gate.py's `case_name` gets a `FAIL in` label ending in tests/parallel.lua's `hung: no progress …` or `not run: its worker was killed after a hung case` note, for a case whose set is keyed by a variable
- **THEN** the rerun's `CASE=` is the set chain and case name without the note

#### Scenario: Gate reruns a readiness case whose label carries its error
- **WHEN** gate.py's check log has `FAIL in tests/integration/lsp/test_readiness.lua | lsp: slow case: ready after 3157 ms, bound 2500 ms` and that file defines the case `lsp: slow case`
- **THEN** the rerun command is `make test-readiness CASE=lsp: slow case`

#### Scenario: Gate reruns e2e once after a sandbox failure
- **WHEN** gate.py runs with a `make` stub whose check fails in `e2e` with only sandbox lines (`did not answer SSH`, `is not running`) and whose rerun passes, then fails; then with a `FAIL in` case; then with another non-sandbox line
- **THEN** the first reruns `make e2e E2E=1` and is green with `e2e: <last sandbox line>` in `flaky`; the second is red; the last two are red with no rerun

#### Scenario: Drain gives a re-queued change one more run
- **WHEN** `make drain` runs a queue whose first change has a `## Rejected run` section (the judge re-queued it) and whose run ends `cancelled` every time
- **THEN** it runs that change twice, then moves on to the next change; a cancelled change without that section runs once

#### Scenario: A folder left without a proposal is not queued
- **WHEN** `queue_pick.py` runs with an archived change whose ignored `drafts/` folder stayed under `openspec/changes/<name>/`, and a queued change `b`
- **THEN** it picks `b`, never the leftover folder

#### Scenario: Gate reruns smoke-health once after a checkhealth error
- **WHEN** gate.py runs with a `make` stub whose check fails only in `smoke-health` with an `ERROR` line and whose rerun passes, then fails
- **THEN** the first reruns `make smoke-health` and is green with `smoke-health: <the ERROR line>` in `flaky`; the second is red

#### Scenario: Gate reruns the stack layer once after a failure
- **WHEN** gate.py runs with a `make` stub whose check fails only in `stack` with a `FAIL in` line and whose rerun passes, then fails
- **THEN** the first reruns `make stack` and is green with `stack: <the FAIL in line>` in `flaky`; the second is red

### Requirement: Gate stops on sandbox infra
When the e2e rerun fails on sandbox infra again (incl. the image pull disk guard) and every other rerun passes, gate.py SHALL print `infra` (the sandbox line) and not count the pass as an attempt; verdict SHALL end the loop with no fix pass and not exhausted; the judge SHALL decide `infra` (neither reject nor re-queue) and ship-decide SHALL stop the run.

#### Scenario: Gate stops on sandbox infra that fails again on rerun
- **WHEN** gate.py runs on a check failing in e2e on the image pull disk guard and in test-readiness on a timing bound, the e2e rerun failing on it again and the readiness rerun passing; then with the readiness rerun failing; then with an e2e rerun that passes
- **THEN** the first is red with `infra` set and the attempt counter at 0, verdict is done and not exhausted, the judge decides `infra` and ship-decide stops without go; the second is red with no `infra`; the third is green with both in `flaky`

### Requirement: Gate never passes a case the change owns as flaky
gate.py SHALL never rerun a failed case whose `T[...]` line or body the branch adds or edits or that is named after a scenario of the change, SHALL still rerun the other failed cases (in the same file too; an owned failure keeps the check red), and SHALL count a test rerun as passed only when it exits 0 and prints its reporter group (`<file> | <case>`, or `<file> | <set>` for a nested set) with only passes.

#### Scenario: Gate never passes a case the change owns as flaky
- **WHEN** gate.py runs on a check failing in `test` on one case whose file the branch edits; then on one named after a scenario of the change; then with a rerun that exits 0 printing `No test cases matched`; then with a rerun printing the case as passed
- **THEN** the first two are red with no rerun, the third is red, the last is green with the case in `flaky`

#### Scenario: Gate reruns an old case in a test file the change edits
- **WHEN** gate.py runs on a check failing on a case the branch leaves unchanged in a test file whose other case it edits; then failing on both cases
- **THEN** the first reruns only the old case and is green with it in `flaky`; the second reruns only the old case and is red, its failures noting the old case passed on rerun

#### Scenario: Gate reruns a failed case of a nested set
- **WHEN** gate.py runs on a check failing on `<file> | load | <case>: <message>` whose rerun prints `<file> | load: o`; then `<file> | load: x`
- **THEN** the rerun is `make test FILE=<file> CASE=load | <case>` and the first is green; the second is red

### Requirement: Fix pass never makes an empty commit
The fix command SHALL commit nothing when no listed finding needs a change and say so (the gate reruns), never an empty commit, and SHALL prefix with `loop:` (dropped) a lesson candidate that restates one of its own rules.

#### Scenario: Fix prompt never makes an empty commit
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it allows no commit when nothing needs changing, forbids `git commit --allow-empty`, and has lesson candidates that restate a rule of the command start with `loop:`

### Requirement: Spec step plans only unfinished adopted work
work-queue SHALL skip the queue-spec step when the adopted change's tasks.md has tasks and all are ticked (`tasks.py --adopted-state`), reading visible UI from design.md; queue-spec SHALL read adopt notes only if they exist and never let a task empty a test file.

#### Scenario: Agents never load the host to reproduce a flake
- **WHEN** `.archon/commands/fix.md` and `.archon/commands/implement.md` are read
- **THEN** both forbid loading the host (stress loops) to reproduce a flake, and fix.md runs `make fmt` before it commits

#### Scenario: Harness slips are not implementation attempts
- **WHEN** `.archon/commands/fix.md` and `.archon/commands/implement.md` are read
- **THEN** both say fixing a mechanical error in the agent's own test or harness code and rerunning is not an attempt

#### Scenario: Fix prompt shortens an overlong delta requirement
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it treats a "Requirement text is very long" validate finding as a fix to this change's spec delta and reruns `spec_trial.py`

#### Scenario: Implement and fix self-check like the gate before handing back
- **WHEN** the Makefile and `.archon/commands/fix.md` and `implement.md` are read
- **THEN** `make self-check CHANGE=<id>` runs the hard rules (`integrity.py`, `pinned.py --check`), lint, types, trace, strict validation of the change and `spec_trial.py` (no tests, no e2e), both prompts run it before they commit (committing anyway with a `loop:` note when only base or loop tooling is red), implement also reruns each test file it edited whole, the integration tests of each area that requires a module it edited, the screen and integration tests of each other area it edits, and the capability's e2e for a visible-UI change, and both fix an ordinary bug instead of writing `## Stuck` while an attempt is left

#### Scenario: Fix keeps the red regression test and review blocks scope creep
- **WHEN** `.archon/commands/fix.md` and `review.md` are read
- **THEN** fix forbids deleting or weakening the red regression test an earlier pass added, and review marks an edit outside the proposal and tasks `[must-fix]` unless the gate needed it, which the finding says, and keeps new scenario test files, whitespace-only `make fmt` edits and the change's folder in scope

#### Scenario: Review lists every must-fix in one pass
- **WHEN** `.archon/commands/review.md` and `fix.md` are read
- **THEN** review checks every unit implementing each delta requirement and scenario, not a sample, lists all must-fix findings at once and says why an earlier pass missed one in code it already reviewed; fix applies a finding about a shared contract to every unit, each against its own native API

#### Scenario: Each review sees the run's earlier reviews
- **WHEN** verdict.py runs after two reviewed passes (one rejected, one approved) and after a gate-red pass with no review, and `.archon/commands/review.md` is read
- **THEN** `$ARTIFACTS_DIR/reviews.md` holds both reviews' findings in pass order under their pass number and outcome, nothing for the unreviewed pass, and review reads it, checks agent decisions first (one narrowing a delta SHALL is `[must-fix]`) and never re-asks for a reverted fix

#### Scenario: A red pass keeps the last review's open findings
- **WHEN** verdict.py runs after a rejecting review, then on a gate-red pass with no review, then after an approving review, then on another red pass
- **THEN** the first red pass's feedback quotes the rejecting review's blocking findings as still open, and the red pass after the approval quotes none

#### Scenario: Adopted change with every task ticked skips the spec step
- **WHEN** `tasks.py --adopted-state` runs for change `c` with all tasks ticked (with a design.md holding a render section, with a technical design.md, without one, and with a proposal holding a `## Rejected run` section), with one unticked, with no tasks.md and with no change folder
- **THEN** it prints `tasks_done` true only for the ticked ones without a rejected run, `visible_ui` true only with the render-holding design.md and `archived` true only without the folder; work-queue's `complete` requires `tasks_done == false` and queue-spec reads adopt-notes.md only if it exists

#### Scenario: Queue spec prompt never empties a test file
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** it says a task never empties a test file and keeps the copy in the file that would be emptied

### Requirement: Skip-specs change needs no design
Before the spec step, the work-queue `meta` node (`no_design.py`) SHALL set `schema: spec-driven` for a change needing design (a feature, or a proposal.md or design.md with a render section, without skip_specs) and `schema: spec-driven-no-design` for every other change; agents never change it. The spec step (`complete`) SHALL run queue-spec without `output_format`; `classify` (`classify.py`) SHALL answer `visible_ui` and `architecture` from the written change, false for skip_specs.

#### Scenario: Skip-specs change gets the no-design schema
- **WHEN** `no_design.py` runs for a change with proposal.md, tasks.md and a `.openspec.yaml` holding `schema: spec-driven` and `skip_specs: true`, in a repo carrying `openspec/schemas/spec-driven-no-design`
- **THEN** it prints skip_specs true and design false, the file names `schema: spec-driven-no-design`, and `openspec status --json` lists no `design` artifact and reports the change complete

#### Scenario: No-design switch is committed on its own
- **WHEN** `no_design.py` switches change `c` to the no-design schema in a git checkout with a clean tree
- **THEN** the tree is clean afterwards and the latest commit is `chore(openspec): c uses the no-design schema`

#### Scenario: Change without a new look gets the no-design schema
- **WHEN** `no_design.py` runs for a `Kind: bug` change without renders whose `.openspec.yaml` holds only `schema: spec-driven`, with a spec delta
- **THEN** it prints skip_specs and design false, the file names `schema: spec-driven-no-design`, and `openspec status --json` lists proposal, specs and tasks and reports the change complete

#### Scenario: Change with a new look keeps the design schema
- **WHEN** `no_design.py` runs for a `Kind: feature` change set to `spec-driven-no-design`, for a change whose proposal.md has a `## Proposed render` section, and for a feature with `skip_specs: true`
- **THEN** the first two print design true and their file names `schema: spec-driven`; the skip_specs one prints design false

#### Scenario: Queue spec prompt keeps the schema and greps one capability
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** it says the meta step already set the schema, forbids changing the `schema:` line, reading `openspec/schemas/` and `openspec instructions design`, keeps the `schema:` line when a skip_specs change drops skip_specs, and forbids listing every Requirement or Scenario of all specs, grepping one capability's spec instead, and before an ADDED requirement lists the spec files naming the behaviour's key, command or function (`rg -l`) so a requirement that already owns it gets a MODIFIED delta

#### Scenario: Work queue spec step returns no JSON
- **WHEN** `.archon/workflows/work-queue/work-queue.yaml` is read
- **THEN** `complete` runs queue-spec without `output_format` and no `complete-skip` node exists, `classify` runs `classify.py` after `complete` with a `visible_ui`/`architecture` schema, spec-gate waits for it, and a fix reaches `preview` only with `$classify.output.visible_ui == true` (or an adopted render)

#### Scenario: Classify reads visible UI and architecture from the change
- **WHEN** `classify.py` runs for change `c` with a design.md holding a render section, with a technical design.md, with proposal.md `## Impact` naming `lua/gleb/plugins/plugins.lua`, `init.lua` or `lazy-lock.json`, with an Impact naming only `lua/gleb/lsp/config/terraform/init.lua`, with a tasks.md naming `lua/gleb/plugins/`, and with `skip_specs: true` plus a render design.md and a wiring Impact
- **THEN** `visible_ui` is true only with the render section and without skip_specs, and `architecture` is true only for the wiring files named in Impact or tasks.md without skip_specs

#### Scenario: Queue spec prompt opens with a skip_specs fast path
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** a skip_specs fast path precedes the full path, names the expected `openspec status` lines and forbids `.archon/`, `openspec/config.yaml`, `openspec/changes/archive/` and `openspec instructions`, and the prompt reads only the `rules:` block of openspec/config.yaml and never cites context.md

#### Scenario: Queue spec prompt sees a tightened assertion fail
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** the refactor template is limited to changes that leave every assertion as is, and a change adding or tightening an assertion gets a task 1.1 that makes it fail once by a temporary fault, records the failure and removes the fault

### Requirement: OpenSpec config rules are plain strings
Every entry under `rules` in `openspec/config.yaml` SHALL load as a plain string, so an unquoted `- Key: text` line cannot become a mapping that openspec silently drops with the rest of its section.

#### Scenario: OpenSpec config rules are plain strings
- **WHEN** `openspec/config.yaml` is loaded with Ruby's YAML parser
- **THEN** `rules` has at least one section and every entry of every section is a string

### Requirement: Judge tells a tested rename from a removal
The judge SHALL count a removed main-spec scenario as renamed when, one for one, an added scenario of the same capability (or the capability Git sees its spec renamed to) gains its `<capability>: <title>` test and the old test name is removed; a renamed capability's renamed tests are kept too. `## RENAMED Requirements` is no removal. Test cases SHALL be compared by name, so an added case never offsets a lost one.

#### Scenario: Judge ships a tested scenario rename
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that retitles scenario `old title` of capability `c` to `new title` and renames test `c: old title` to `c: new title`, on one that only reorders scenarios, and on one whose change delta has a `## RENAMED Requirements` section applied to the main spec
- **THEN** each JSON `decision` is `ship`

#### Scenario: Judge ships a renamed capability
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that moves `openspec/specs/a/spec.md` to `openspec/specs/b/spec.md` unchanged and renames tests `a: one`, `a: two` to `b: one`, `b: two`
- **THEN** its JSON `decision` is `ship`

#### Scenario: Judge notes a scenario removal a rename does not cover
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that removes scenario `old title` of `c` and keeps test `c: old title`, one that retitles it while keeping the old test beside `c: new title`, and one that retitles it with no test change
- **THEN** each JSON `decision` is `ship` and `reasons` has a `note: breaking: removes behaviour` line naming `c: old title`

#### Scenario: Judge rejects a lost test case by name
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that replaces test `c: kept` by `c: unrelated` (same case count), one that does so inside a nested `T["group"]` set, and one that moves scenario `old title` to capability `d` as `new title` with its test renamed to `d: new title`
- **THEN** each JSON `decision` is `reject` and `reasons` names the lost case (`c: kept`, `c: old title`), never the group

### Requirement: Loop keeps the user's contract
The loop SHALL keep the user's contract unasked: no step changes a requirement's bounds or the `## Decision` text (the judge rejects it), main specs change only by archive, and a `## Blocked` section is settled by `unblock.md` (default model at `xhigh`, then Claude if one is left), never ships, and fails work-queue's run if it survives both. A section of only `loop:` items stops nothing; the judge lists those items and `loop-notes.md` lines as notes.

#### Scenario: Queue spec prompt keeps the user's contract
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** it forbids changing a requirement's numbers or bounds, removing a requirement to add it again, rewording `## Decision` and dropping, narrowing or scoping out a `## What Changes` item, and settles any `## Blocked` section left

#### Scenario: Judge rejects a change that re-adds a removed requirement
- **WHEN** `.archon/scripts/escalation.py` runs on a branch whose change delta REMOVES requirement `Server readiness` and ADDS `Server readiness.` (a near name), once with no main-spec text, once keeping the main spec's `1 s` and once loosening it to `2.5 s`
- **THEN** the first and third JSON `decision`s are `reject` with `reasons` naming the re-added requirement, and the second (every bound kept) is `ship`

#### Scenario: Judge rejects a change that rewrites the user's Decision
- **WHEN** `.archon/scripts/escalation.py` runs on a branch that rewords the `## Decision` section of a proposal on `auto`, on one that edits only its `## Why`, and on one whose `auto` extended the Decision after the branch forked
- **THEN** the first JSON `decision` is `reject` with a reason naming the proposal, and the second and third are `ship`

#### Scenario: Adopt reverts main spec edits
- **WHEN** `.archon/scripts/adopt.py` merges a branch that edits and adds files under `openspec/specs/` and edits another file
- **THEN** `openspec/specs/` equals the pre-merge state in a new commit, the other edit is kept, and the summary names the reverted spec

#### Scenario: Blocked queued change goes to the unblock step
- **WHEN** `.archon/scripts/blocked.py` runs for a change whose proposal.md has a `## Blocked` section, and for one without, and work-queue.yaml is read
- **THEN** the first prints `blocked` true with the section text and writes an escalation.md quoting it; the second prints `blocked` false; work-queue runs `settle-queued` (the unblock command at `effort: xhigh`) when `blocked` is true, `unblock-queued` (`provider: claude`, `effort: xhigh`) when the recheck `settled` still is, and the failing `still-blocked` when `unblocked` still is, with no `approval:` node

#### Scenario: Unblock prompt settles every Blocked section
- **WHEN** `.archon/commands/unblock.md` is read
- **THEN** it never asks the user nor leaves a `## Blocked` section, picks the recommendation unless it contradicts the spec, design.md or a `## Decision`, writes one line per choice under `## Agent decisions` in tasks.md (creating it if needed) and deletes each settled section

#### Scenario: A later user Decision resolves a Blocked section
- **WHEN** `.archon/scripts/blocked.py` runs for a change whose tasks.md `## Blocked` section was committed before a user `## Decision` in its proposal.md, and again after tasks.md gets an uncommitted new Blocked section
- **THEN** the first run reports `blocked` false and the second reports `blocked` true

#### Scenario: An Unblocked section resolves an earlier Blocked section
- **WHEN** `.archon/scripts/blocked.py` runs for a change whose tasks.md `## Blocked` section was committed before a `## Unblocked` section in its proposal.md
- **THEN** it reports `blocked` false

#### Scenario: Blocked task is settled in its pass so later tasks still run
- **WHEN** nvim-deliver.yaml's task loop is read
- **THEN** after `implement` a `task-blocked` check runs; a `## Blocked` section goes to `task-settle` (the unblock command at `effort: xhigh`), and one still left after `task-settled` goes to `task-unblock` (`provider: claude`, `effort: xhigh`) in the same pass, so the next pass implements the next task

#### Scenario: Blocked build pass goes to settle, then Claude
- **WHEN** `.archon/scripts/verdict.py` runs three times in one artifacts dir on red passes for a change whose tasks.md has a `## Blocked` section, and nvim-deliver.yaml is read
- **THEN** it reports `blocked` true, `exhausted` false and `blocked_passes` 1, 2, 3 with `done` false, false, true; the build loop's `fix` runs only when `blocked` is false, `settle` (the unblock command at `effort: xhigh`) when `blocked_passes` is 1 and `unblock` (`provider: claude`, `effort: xhigh`) when it is 2, and there is no `ship-gate`

#### Scenario: Judge rejects a Blocked section, never asks
- **WHEN** `.archon/scripts/escalation.py` runs with `exhausted` true for a change whose tasks.md has a `## Blocked` section
- **THEN** its JSON `decision` is `reject`, `escalate` is false and escalation.md quotes the Blocked text

#### Scenario: A Blocked section of only loop items never stops the change
- **WHEN** `.archon/scripts/blocked.py` and `verdict.py` (first red pass) run for a change whose tasks.md `## Blocked` section holds only `loop:` items, and blocked.py again after a non-`loop:` line joins that section
- **THEN** blocked.py prints `blocked` false and writes no escalation.md, verdict reports `done` and `blocked` false, and the second blocked.py run reports `blocked` true

#### Scenario: Judge lists loop notes for the auditor
- **WHEN** `.archon/scripts/escalation.py` runs for a done change whose tasks.md `## Blocked` section holds only `loop:` items and whose `$ARTIFACTS_DIR/loop-notes.md` holds `loop:` lines, one repeating an item
- **THEN** its JSON `decision` is `ship`, and `reasons` and escalation.md list each item and line once as `- note: loop: …`

#### Scenario: Fix and implement prompts send loop tooling failures to loop notes
- **WHEN** `.archon/commands/fix.md` and `implement.md` are read
- **THEN** each says to append a `loop: <failure>` line to `$ARTIFACTS_DIR/loop-notes.md`, not tasks.md, and neither says to write `## Blocked` with `loop:`

### Requirement: Stuck work goes to the fix passes
A `## Stuck` section in tasks.md (a behaviour red after both attempts, no decision needed) SHALL never ask the user nor hold a queued change before spec nor stop later tasks: the build loop stays red on it and sends it to one fix pass on Claude at `effort: xhigh`; still stuck after it, verdict ends the loop as exhausted, and an exhausted loop is rejected and re-queued with it. Agents SHALL decide small design choices themselves and record them under `## Agent decisions`.

#### Scenario: Verdict sends a Stuck section to the fix pass
- **WHEN** `.archon/scripts/verdict.py` runs on an otherwise green pass for a change whose tasks.md has a `## Stuck` section
- **THEN** it reports `done`, `passed` and `blocked` false, `stuck` true, `failed_gates` `stuck`, feedback quoting the section and `stuck_passes` 1, `exhausted` false; a second run in the same artifacts dir reports `stuck_passes` 2 with `done` and `exhausted` true; nvim-deliver has no `fix-stuck` node, its `fix-stuck-claude` (`provider: claude`, `effort: xhigh`) runs every stuck pass, and fix.md tells it to solve it itself

#### Scenario: A Stuck change never asks and is never held before spec
- **WHEN** blocked.py, escalation.py (`exhausted` true) and tasks.py run for a change whose tasks.md has a `## Stuck` section
- **THEN** blocked.py reports `blocked` false, the judge's `decision` is `reject` (no ask) with a `- stuck:` reason pointing at tasks.md's `## Stuck` without quoting it, and tasks.py ends the task loop (the stuck task is the only one)

#### Scenario: Implement continues past a stuck task
- **WHEN** tasks.py and context_pack.py run for a change of five tasks whose tasks.md gained a `## Stuck` section while its second task was unchecked
- **THEN** tasks.py exits 1 (tasks are left), the pack's next task is the third, and once every other task is ticked tasks.py exits 0 with the stuck one still unchecked

#### Scenario: Agents decide small choices and record them
- **WHEN** `.archon/commands/implement.md`, `fix.md` and `review.md` are read
- **THEN** implement and fix decide small design choices themselves, record each under `## Agent decisions` in tasks.md, and write `## Blocked` only for a choice beyond the spec or design, a contradiction or a breaking change, with the question, options and a recommendation; fix deletes `## Stuck` once green; review checks the Agent decisions against the spec and design

#### Scenario: Judge hands the review findings to the follow-up
- **WHEN** `.archon/scripts/escalation.py` runs with `weakened_test` true and 3000+ chars of review findings starting with a `## ` line, and again with the findings alone
- **THEN** the first `decision` is `reject` and `reasons` holds `review: test weakened`, then `- review findings:` with at most 1500 chars of the findings indented two spaces, no line starting `## `; the second is `ship` without them

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

### Requirement: Quick routes reference existing config files
Every literal `lua/gleb` file path routed by `tests/quick.sh` SHALL exist in the repository.

#### Scenario: Literal quick routes exist
- **WHEN** the literal `lua/gleb` file routes in `tests/quick.sh` are checked against the worktree
- **THEN** every routed file exists

### Requirement: Spec step plans the main-spec scenarios a change pins
`.archon/scripts/pinned.py <change>` SHALL list each main-spec scenario naming a symbol the change touches (config identifiers and keymap lhs backticked in the proposal's What Changes and Impact; lhs and callables of mappings and local functions the branch diff changes) whose capability has no delta and whose title no `## Impact` line cites (backticked or quoted); `--check` SHALL exit 1 when any. The spec steps SHALL plan each; the spec gates and gate.py SHALL run the check.

#### Scenario: Pinned lists a scenario a proposal symbol names
- **WHEN** pinned.py runs for a proposal naming `gr` and `lsp_references(…)` and `H.xfail`, against a spec with a scenario reading `maparg("gr")` whose callback is `lsp_references`, a desc enumeration naming `gr`, a screenshot scenario with no `gr` row and an `H.xfail` scenario
- **THEN** it prints only the first scenario with its spec line, and `--check` exits 1

#### Scenario: Pinned ignores the loop spec's examples
- **WHEN** `pinned.py` runs for a proposal naming `gr` in a repo whose `openspec/specs/loop/spec.md` quotes the same `gr` scenario text as the keymaps spec
- **THEN** it lists only the keymaps pin

#### Scenario: Pinned skips a planned or explained scenario
- **WHEN** pinned.py `--check` runs for that change once with a `specs/keymaps/spec.md` delta and once with an Impact line naming the scenario's title
- **THEN** both exit 0 and print nothing

#### Scenario: Pinned reads mappings the branch diff changes
- **WHEN** pinned.py runs for a proposal with no backticked symbol on a branch that changes the `gr` mapping's callback, and on one that changes only its desc
- **THEN** the first prints the `gr` scenario and the second prints `none`

#### Scenario: Gate rejects a pinned scenario before make check
- **WHEN** gate.py runs for a change whose proposal pins an undeclared scenario, with a `make` stub that records being called
- **THEN** `green` is false, the failures name `hard rule: pinned scenario` and the scenario, and make never ran

#### Scenario: Spec steps receive pinned scenarios
- **WHEN** the work-queue and fix-bug workflows and the queue-spec and spec-bug prompts are read
- **THEN** a `pinned` node runs before `complete` and its output reaches queue-spec as `Pinned scenarios`, spec-bug runs pinned.py, each pin gets a MODIFIED delta or an Impact line, and both spec gates run `pinned.py --check`

#### Scenario: Fix prompt allows a delta for a contradicted pin
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it allows a MODIFIED delta when a failing test pins a main-spec scenario the change contradicts, and calls replacing a behaviour check with metadata (desc, buffer) weakening, as is a check replaced by a wait longer than the behaviour's bound, and keeps a removed stub's checks against the real module

#### Scenario: Queue spec prompt keeps skip_specs and flake tasks narrow
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** it locates code by `rg -n <symbol>`, gives a skip_specs task template reading only scenario titles, and has flake tasks copy the proposal's `FAIL in` lines without searching `artifacts/runs`

#### Scenario: Queue spec fast path plans pinned scenarios
- **WHEN** `.archon/commands/queue-spec.md` is read
- **THEN** the pinned list precedes the skip_specs fast path, which adds one `## Impact` line per pinned scenario saying why it still holds (or drops skip_specs for a MODIFIED delta)

### Requirement: Red spec gate reruns the spec step once
The work-queue spec gate (`spec_gate.py`) SHALL print `{ok, log}` and exit 0. A red first pass SHALL rerun queue-spec once with the gate's log as feedback, then gate again; only a red second gate SHALL fail the run, printing its log. Preview and the design decision SHALL wait for a green pass.

#### Scenario: Spec gate prints its log instead of failing
- **WHEN** `spec_gate.py` runs for a change pinning an unplanned scenario, then with `INPUTS_FAILED_LOG` set to that log
- **THEN** the first exits 0 with `ok` false and a log naming `pinned.py` and the scenario; the second exits 1 printing the log

#### Scenario: Red spec gate reruns the spec step once
- **WHEN** `.archon/workflows/work-queue/work-queue.yaml` and queue-spec.md are read
- **THEN** `spec-retry` runs queue-spec with `$spec-gate.output.log` when the gate is red, `spec-gate-2` follows, `spec-failed` fails the run on a second red gate, and preview and design-decide wait for `spec-ok`

### Requirement: Probe runs Lua in a test child
`make probe` SHALL run a Lua snippet (`SCRIPT=<file>` or `PROBE=<code>`) in a headless full-config child started like the tests' (`H.new_child` + `start_config`), print its prints and return values, exit non-zero on error and after a timeout. implement, fix and explore-bug prompts and the context pack SHALL point probes at it and say LSP restart and tree and panel renders are async: wait for the end state.

#### Scenario: Probe prints the snippet's return value
- **WHEN** `make probe PROBE='return vim.g.mapleader'` runs
- **THEN** it exits 0 and prints the leader through `vim.inspect`

#### Scenario: Probe exits non-zero on an error
- **WHEN** `make probe SCRIPT=<file>` runs a script that prints a line and then errors
- **THEN** it prints the line, writes the error to stderr and exits non-zero

#### Scenario: Agent prompts and context pack point probes at make probe
- **WHEN** implement.md, fix.md, explore-bug.md and a built context pack are read
- **THEN** each names `make probe` and says LSP restart and tree and panel renders are async: wait for the end state, not for attachment

### Requirement: Rejections say what to fix
A red pass SHALL tell the next fix pass, and a rejection the re-queued run, what to fix: verdict.py sends only blocking review findings to fix and never lists a skipped review as a failed gate; an exhausted judge quotes the first lines of the last gate failures; gate.py names dropped cases with their remedy while the judge still never ships them; an `## Unblocked` answer is kept until the spec step records it.

#### Scenario: Verdict sends only blocking review findings to fix
- **WHEN** verdict.py runs on a pass the review rejected with `[must-fix]` findings (one numbered under a `Minor (non-blocking):` heading) and `[minor]` ones (one continued on a second line), and on a red pass the review skipped
- **THEN** the first feedback holds both must-fix findings and no minor line (review_findings keeps them all), and the second `failed_gates` has no `review_skipped`

#### Scenario: Exhausted judge quotes the last failures
- **WHEN** verdict.py runs on a red pass with a make check failure, a `## Stuck` section and review findings, then escalation.py with `exhausted` true and that verdict's `failures`
- **THEN** the judge's reasons have a `- last failures:` item quoting the first lines of the make check failure, indented, and neither the Stuck text nor the review findings in it

#### Scenario: Gate returns dropped cases to fix with the remedy
- **WHEN** gate.py runs on attempt 1 after the fix pass dropped a case the previous pass added, then verdict.py on that result, then escalation.py with the case still gone
- **THEN** failures name the case with "restore these cases under their names, or add a same-titled scenario", the verdict is not done and its `failed_gates` has `rules`, and the judge does not ship

#### Scenario: Rejected run keeps the Unblocked answer
- **WHEN** followup.py re-queues an active change whose proposal has an `## Unblocked` section and no `## Blocked` one, and queue-spec.md is read
- **THEN** the proposal keeps the `## Unblocked` section, and queue-spec moves an Unblocked answer it acts on under `## Agent decisions` in tasks.md before deleting it

### Requirement: Agents get narrow context and test rules
The context pack SHALL hold only what the next task needs, and the prompts and trace SHALL say how a regression test is named: after a scenario of the change, never invented, folded or deleted; a test of mode-dependent behaviour SHALL drive the real mapping with the mode still active.

#### Scenario: Context pack keeps only what the next task needs
- **WHEN** context_pack.py runs for a change whose next task names one scenario of a test file (unbackticked) with two cases and a section of a doc with a long preamble, whose design names another file, and whose proposal has an `## Unblocked` section and a `## Rejected run` that only reported a block, with no Blocked section left
- **THEN** the pack holds the test file's header and named case only, the doc's named section, a `more lines` note for the preamble and an outline of the rest, lists the other file by path without its content, keeps only the spec delta requirement of that scenario (the other one named), keeps the `## Unblocked` section and drops the Rejected run

#### Scenario: Trace orphan message names the remedy
- **WHEN** `tests/trace.lua` runs on a test case named after no scenario
- **THEN** it exits 1 and the ORPHAN heading says to name it after a scenario or add that scenario to `openspec/changes/<change>/specs`, never delete it

#### Scenario: Review flags a test reading a change folder
- **WHEN** `.archon/commands/review.md` is read
- **THEN** its test-integrity rule makes a test that reads a file under `openspec/changes/` at runtime a must-fix, the file copied under `tests/`

#### Scenario: A new look is checked against its approved render
- **WHEN** `.archon/commands/implement.md` and `review.md` are read
- **THEN** implement requires a new screen case to assert its whole colour mask from the change's approved render, and review calls a new screen case without that mask untested and a tasks.md rewrite that drops a gate step weakened

#### Scenario: Review treats a narrowed screen check as weakened
- **WHEN** `.archon/commands/review.md` is read
- **THEN** its test-integrity rule calls a screen case that checks fewer mask rows, or replaces a screenshot comparison with text checks, a weakened test

#### Scenario: Fix resolves a trace duplicate
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it makes a trace DUPLICATE the pass's to resolve, by renaming one copy after a scenario it adds to the delta, and forbids recording it as inherited

#### Scenario: A stuck fix pass fixes the other gate failures too
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** a `stuck` finding is the first finding, not the only one: the pass also fixes every other `FAIL in` line of the gate log

#### Scenario: Implement and fix probe UI edge cells
- **WHEN** `.archon/commands/implement.md` and `fix.md` are read
- **THEN** each requires a headless probe of an empty result (also after a filter), a multibyte line, `VimResized` across the breakpoint and an external `:quit`/`:close` before a UI task is done, with autocmds tied to the buffer or torn down on `WinClosed`

#### Scenario: Trace links a nested case to its scenario
- **WHEN** `tests/trace.lua` runs on a case `T["x: base"]["hidden mode"]` nested in the set of scenario `base`
- **THEN** it counts the case as testing `x: base` and reports no orphan

#### Scenario: Fix prompt names regression tests after scenarios
- **WHEN** `.archon/commands/fix.md` is read
- **THEN** it names each new regression test `<capability>: <scenario title>`, reusing a scenario's case or adding a same-titled scenario to the change's spec delta, and forbids inventing a case name or folding or renaming a case an earlier pass added

#### Scenario: Implement tests mode-dependent behaviour in the mode
- **WHEN** `.archon/commands/implement.md` is read
- **THEN** it says a Visual, Insert or operator-pending behaviour is tested through the real mapping with the mode still active, never after `<Esc>`

### Requirement: Test tooling the agents run is exact
a test child SHALL exit when its test worker is gone, `make test FILE=<directory>` SHALL run that directory's test files, and the hard-rule checks (`.archon/scripts/integrity.py`) SHALL stage into a private index, leaving the worktree's index as the agent left it.

#### Scenario: A test child outlives no killed worker
- **WHEN** a worker Neovim starts a test child through `tests/helpers.lua` and the worker is killed with SIGKILL
- **THEN** the child process exits within 10 s

#### Scenario: A test worker outlives no killed run
- **WHEN** `tests/parallel.lua` runs one worker (`JOBS=1`) on a test file whose case waits forever, and the run is killed with SIGKILL
- **THEN** the worker process exits within 10 s

#### Scenario: A test directory runs its files
- **WHEN** `tests/runner.lua` collects with `FILE` set to a directory holding a nested test file and a non-test file
- **THEN** it returns the test files under it, sorted, and not the other file

#### Scenario: Hard-rule checks leave the real index alone
- **WHEN** `integrity.py` diffs a repo with a new untracked test file
- **THEN** the diff includes the new file and `git diff --cached` in the repo stays empty

### Requirement: Check prunes stale Neovim temp dirs
`make check` SHALL first remove Neovim temp dirs (`$TMPDIR/nvim.$USER/<name>`) older than 12 hours that no running process names in its arguments or holds open (`tests/prune_tmp.sh`), so dirs of killed test children never fill the disk.

#### Scenario: Check prunes stale Neovim temp dirs
- **WHEN** `tests/prune_tmp.sh` runs on a root holding an old unused dir (with a read-only and a write-only dir inside), a young dir, and an old dir a running process names
- **THEN** only the old unused dir is removed, the script reports one removal and prints nothing on stderr

#### Scenario: Check stops orphaned test processes
- **WHEN** `tests/prune_tmp.sh <root>/` runs while a Neovim reparented to launchd has `XDG_DATA_HOME` under `<root>`, and the caller has a live child of its own
- **THEN** it exits 0 with no stderr, prints `stopped 1 orphaned test processes`, the orphan exits and the caller's child lives

#### Scenario: Test children keep the Go build cache under .tests
- **WHEN** a test child starts through `tests/helpers.lua` and runs `go env GOCACHE`
- **THEN** its `GOCACHE` and the `go` answer are `<repo>/.tests/go/cache` (`tests/check.sh` empties it past `CHECK_GOCACHE_GB`, default 5)

### Requirement: Test bootstrap ignores a leaked GIT_DIR
`tests/bootstrap.sh` and `tests/fixtures/build.sh` SHALL unset Git's local environment (`git rev-parse --local-env-vars`) before any git command, so a `make test` run from `git bisect run` or a hook never re-initializes the real repository, and `followup.py` SHALL refuse to move the base branch while the repository reads as bare.

#### Scenario: Test bootstrap ignores a leaked GIT_DIR
- **WHEN** both scripts are read, and `git init <dir>` runs after that unset with `GIT_DIR` naming another repository's `.git`
- **THEN** both scripts carry the unset, the other repository's `core.bare` stays `false` and `<dir>` gets its own `.git`

### Requirement: Loop clean skips a branch that is already gone
`loop_clean.py` SHALL skip a listed loop branch whose ref no longer exists when it classifies it, instead of failing on `git rev-parse`, so a ship's cleanup never ends in a traceback.

#### Scenario: Loop clean skips a branch that is already gone
- **WHEN** `loop_clean.clean` gets a branch list holding `loop/c`, which does not exist, and an existing `loop/c-<stamp>` that is the keeper
- **THEN** it finishes without an error and keeps `loop/c-<stamp>` (`.archon/scripts/test_loop_clean.py`)

### Requirement: Steps commit the run files they edit
The gate SHALL commit its tick of tasks.md's gate items and the judge SHALL commit its lessons edit of `docs/workflow.md` on the run branch (`integrity.commit_paths`, only those paths), so the run's worktree never keeps uncommitted loop edits that block `sync_base.py` from merging a moved base.

#### Scenario: Steps commit the run files they edit
- **WHEN** `integrity.commit_paths` commits a changed tasks.md in a repo that also has another edited file, then runs again with nothing changed, and gate.py and escalation.py are read
- **THEN** it reports a commit, then none; only the other file stays modified; gate.py commits its tick and escalation.py commits `docs/workflow.md`

### Requirement: Plugin update checks retain installed test dependencies
The private data prepared for a plugin update SHALL retain installed plugins, parsers, and Mason packages so the full check exercises the updated plugin with the same external test tools as the normal test environment, and the context pack SHALL read only numbered gate logs (`check-<n>.log`), ignoring the update's `check-update.log`.

#### Scenario: Plugin update data includes Mason tools
- **WHEN** the plugin update workflow prepares private test data from an installation containing `lazy`, `site`, and `mason` trees
- **THEN** all three trees are available to the update's test gate, including executables under `mason/bin`

#### Scenario: Plugin update fails on a failed fetch
- **WHEN** `plugin_update.fetch_failed` reads a `:Lazy! update` log whose line for the plugin shows a git transport error (`Could not resolve host`), one where only another plugin's fetch failed, and one where the fetch finished
- **THEN** it reports the first as failed and the others as not, so an offline update exits with an error instead of "nothing to update"

#### Scenario: Context pack skips the update check log
- **WHEN** `context_pack.last_failures` reads an artifacts dir holding `check-update.log` and `check-2.log`
- **THEN** it returns the FAIL lines of `check-2.log` and does not fail on the unnumbered log

### Requirement: Tests never see an Archon node's inputs
`tests/minimal_init.lua` SHALL unset every `INPUTS_*` environment variable, `BASE_BRANCH`, `DRAIN_SKIP_FILE` and `DRAIN_PICK_LOCK`, so a loop script a test runs sees only the inputs the test passes, not the ones of the Archon node that ran `make check` (plugin-update sets `INPUTS_CANCEL_ON_REJECT=false`).

#### Scenario: Tests never see an Archon node's inputs
- **WHEN** Neovim starts with `tests/minimal_init.lua` and `INPUTS_CANCEL_ON_REJECT=false` `BASE_BRANCH=loop/x` and `DRAIN_SKIP_FILE=/tmp/drain-skip-x` in its environment
- **THEN** `vim.env.INPUTS_CANCEL_ON_REJECT`, `vim.env.BASE_BRANCH` and `vim.env.DRAIN_SKIP_FILE` are nil
