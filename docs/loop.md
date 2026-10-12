# Local AI loop

Agents fix bugs, build features and update plugins on their own, on this machine only. Nothing is
pushed and no PR is opened. [Archon](https://archon.diy/docs/) runs the workflows in
`.archon/workflows/` with Claude Code. Each run works in its own git worktree cut from `auto` and, when
every gate is green, merges back into `auto` with `--no-ff`. `main` is never touched. The stages are the
ones in [architecture/README.md](architecture/README.md#ai-maintenance-loop).

## Commands

| Command | What it does |
|---|---|
| `make fix BUG="…"` | `fix-bug` workflow. `BUG` can also be an existing change id |
| `make feature IDEA="…"` | `new-feature` workflow. It always stops for your approval after the proposal |
| `make queue [CHANGE=<id>]` | `work-queue`: takes the oldest change in `openspec/changes/` that no run has taken yet (no `loop/<id>` branch) |
| `make upkeep [DRY=1]` | `weekly-upkeep`: plugin update. `DRY=1` simulates it without AI or git |
| `make schedule` / `make unschedule` | load or unload the launchd job (`ops/launchd/`) that runs `make upkeep` every Monday at 09:00 |
| `make preview CHANGE=<id> [OPEN=1]` | regenerate `openspec/changes/<id>/preview.html` |
| `make console` | `archon serve`, the web console at http://localhost:3090 (runs, gates, logs) |
| `make loop-status` | the active runs and the last 10 runs |
| `make loop-validate` | `archon validate workflows` |
| `make loop-setup` | one-time setup: adds the `local` self-remote. The other targets run it for you |

Run the targets from `~/.config/nvim` (the `auto` checkout). A run that can pause is interactive, so
`fix`, `feature` and `queue` stay in the foreground. Answer gates in the terminal, in the console, or from
another shell with `archon workflow approve|reject|respond <run-id> [text]`.

## Stages

| Stage | fix-bug | new-feature | work-queue | Gate |
|---|---|---|---|---|
| Explore | `explore-bug` (systematic-debugging) writes `root-cause.md` | `explore-feature` (opsx explore and brainstorming) writes `brainstorm.md` | `queue-spec` finishes a proposal-only change | none |
| Specify | `spec-bug` (opsx propose): a MODIFIED or ADDED scenario | `spec-feature`: proposal, specs, and `design.md` with Current, Proposed A and Proposed B renders | (in queue-spec) | bash: `openspec validate --strict` |
| Preview + approval | only for visible UI or architecture changes | always. Choices: approve (name the option in the comment), revise (runs Specify again with your comment), reject | features, and visible UI or architecture changes | you |
| Plan | `plan` (writing-plans) rewrites `tasks.md`. Each task lists its scenario titles, and its first step is a failing test | same | same | bash: `openspec validate --strict` |
| Build TDD | `implement` (opsx apply, TDD): the failing test `"<capability>: <scenario title>"` first, then the fix, one commit per task | same | same | |
| Verify | `gate` script: `make check` (which includes `make trace`), `openspec validate --strict` on the change and on the main specs after a trial archive, every task ticked | same | same | must be green |
| Align | `verify` (opsx verify plus `make trace VERBOSE=1`) | same | same | no CRITICAL findings |
| Review | `review` (requesting-code-review): conventions.md, scope creep, test integrity, reuse | same | same | `approve` |
| Escalation check | `escalation` script on the diff against `auto` | same | same | see below |
| Ship | `ship` script: `openspec archive`, commit, `git merge --no-ff` into `auto` | same | same | merge succeeds |

Implement, Verify, Align and Review form one `loop_group` that runs at most 3 times. When a pass has red
tests, CRITICAL findings or a rejecting review, the next pass starts with those failures. After 3 passes
the loop stops and the run escalates.

`nvim-deliver.yaml` holds Plan through Ship. The three workflows above include it.

### weekly-upkeep

1. `upkeep` update runs `:Lazy! update` in an APFS clone of `~/.local/share/nvim/lazy`, so your live
   plugins are not touched. It rewrites `lazy-lock.json` in the run worktree and runs `make check`
   against the clone.
2. Green: commit `lazy-lock.json` and merge it into `auto`.
3. Red: `upkeep` bisect binary-searches the changed plugins. For each candidate it reverts lockfile
   entries, runs `:Lazy! restore` and `make check`. Each breaking plugin is pinned back to its old commit
   (3 at most). `upkeep-queue` then writes one `openspec/changes/fix-upkeep-<plugin>/proposal.md` per
   breakage, and the pinned lockfile and the queue items are merged into `auto`.
4. Still red with every culprit pinned: the run is cancelled and nothing is merged.

After a merge, run `:Lazy restore` in your editor to install the new lock.

## When you get pinged

Only at these points:
- The design gate: always for a feature, and for a fix that changes visible UI or architecture.
  `preview.html` opens in your browser, and the gate message shows its path.
- The escalation gate before Ship (`.archon/scripts/escalation.py`), when the change:
  - adds a plugin (a new `"owner/repo"` in `lua/gleb/plugins/` or a new `lazy-lock.json` key),
  - changes a core keymap (a keymap or mapleader line in `lua/gleb/keymaps.lua`),
  - removes or weakens a spec scenario (a removed `#### Scenario:`, `## REMOVED Requirements`, or the
    review's judgment),
  - deletes or disables a test (a deleted test file, fewer `T["…"]` cases, a new `H.xfail`, or the
    review's judgment),
  - or exhausted the fix loop (3 passes still red).

Everything else ships without asking you. A rejected gate cancels the run and keeps its branch and
worktree for manual work.

## Preview page

`ops/preview/preview.lua` (run with `nvim --clean -l`) builds a self-contained
`openspec/changes/<id>/preview.html` (gitignored). The page holds:
- every ```` ```text ```` render from `design.md`, side by side,
- the mermaid diagrams, drawn by mermaid@11.4.1 from jsdelivr, which is the page's only network
  request,
- the full `proposal.md` and `design.md`.

Renders are colored with `make colorize FILE=…` (truecolor ANSI from the real colorscheme) when that
target exists, and monochrome otherwise. `*.ansi` captures in the change folder (from `make render`)
are shown in color too.

## Where to look

- **Archon console** (`make console`): runs, node output, gate buttons, logs. Transcripts and artifacts
  (`root-cause.md`, `check-<n>.log`, `escalation.md`) live under
  `~/.archon/workspaces/GlebBeloded/nvim.config/` in `logs/` and `artifacts/runs/<run-id>/`.
- **git**: `git log --first-parent auto` lists one merge per shipped run. Branches are `loop/*`.
  Run worktrees are in `~/.archon/workspaces/GlebBeloded/nvim.config/worktrees/` until
  `archon isolation cleanup --merged` removes them (the make targets run it after each run).
- **Queue**: `openspec list` (the pending changes) and `openspec/changes/archive/` (the shipped ones).
  Queue a finding with `openspec new change fix-<topic>` plus a `proposal.md` (`Kind: bug|feature`),
  then run `make queue`.
- **Resume or stop**: `archon workflow runs`, `archon workflow resume <run-id>`,
  `archon workflow abandon <run-id>`, `archon complete <branch>`.

## Setup facts

- `.archon/config.yaml`: base branch `auto`, remote `local`, assistant Claude, and no bundled
  workflows. Archon cuts worktrees from `<remote>/<baseBranch>`. `local` points at this repo, so `auto`
  never has to exist on GitHub.
- Claude runs with `bypassPermissions` and project settings, so the hooks and the superpowers plugin
  (`.claude/settings.json`) are active. With `ARCHON_RUN=1` the Stop hook lints only the changed Lua
  files. The full `make check` runs once per build pass, in the `gate` script. Inside `implement`,
  agents run only the targeted test file or case (`make test FILE=… CASE=…`).
- AI nodes can use only the skills they declare (`skills:` on the node). Add a skill there before a
  prompt mentions it.
- `--dry-run` auto-approves gates with the plain string `approved`, so the nodes that read
  `$gate.output.decision` fail in a dry run. Pass `--pause-at-gates`, or stub the nodes after the gate.
