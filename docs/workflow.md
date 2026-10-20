# Workflow

How to operate this repo: the local AI loop, the queue, design renders, and debugging shortcuts. Tests
and their layers are in [testing](testing.md). The loop's stages and gates are drawn in
[architecture](architecture.md#ai-maintenance-loop).

## Goals

- You design a change up front (a Claude session, `/opsx:explore` into small queued changes chained by
  `Depends:`); the loop then delivers it end to end with no human input: no manual approval gates, and
  `make drain` works the queue in order.
- Strict automatic gates replace the human: `make check` (e2e only in the Lume VM, never on the host),
  trace, the spec gate, pinned scenarios, the integrity and drop/weaken detectors, review must-fix.
  Partial or untested work never ships; temporary breakage is accepted for progress (a breaking change
  ships with a note).
- Agents decide small choices and log them under `## Agent decisions`. A `## Blocked` section is settled in the
  same pass (the task loop too, so later tasks still run) by the model itself at xhigh, then by a Claude unblock step that must settle it. Technical exhaustion is
  `## Stuck`: an xhigh fix pass, then Claude while attempts are left, then an automatic reject and re-queue with actionable
  reasons that adopts the branch and keeps the work.
- Small steps: each knows the whole flow and its own boundary, gets a narrow context pack and one task
  group per implement pass; no AI where a script can decide.
- Roles: Archon does all Neovim work (`lua/`, its tests): Codex by default, Claude for review and the
  last-resort Stuck and Blocked steps. The auditor (a Claude session) only
  reviews each phase in a subagent and fixes the loop (`.archon/`, loop tests, sandbox) on `loop/round<N>`
  branches merged into `auto` after `make check E2E=1`; nothing is pushed, `main` stays untouched, tests
  are never weakened.
- Efficiency: measure each step's time and tokens from the Archon DB and fix the weak spots after each
  run (flaky or infra reruns, one exhaustive review pass, scenario-named regression tests).

## Loop lessons

- Every Changes tab action that opens a panel must restore repository-local view and fold state before applying its requested tab.
- When focusing a retained tab mode, rebuild from that mode's model so rendered rows cannot diverge from saved state.
- Commit-file caches keyed by immutable full hashes should survive Branch model refreshes and be reattached to rebuilt nodes so open folds retain their children.
- Bind debounced selection callbacks to the tab that scheduled them, and defer only data-dependent review work so tab focus changes synchronously without stale rows.
- Name every main-spec contract pinned by newly shared symbols in Impact, with the concrete reason its behavior remains unchanged.
- When a base-change event invalidates an in-flight forced fetch, queue the replacement and carry its force intent so the stale callback cannot lose both the refetch and notification.
- Screen tests of approved Go captures must keep gopls off (an in-process fake client gives the "LSP ok" chip): its semantic tokens recolour Tree-sitter's groups once it loads the module, so masks fail only on runs where gopls is fast.
- `:edit` of the file a window already shows re-reads it (BufRead, LSP reattach, ufo refold) and moves the view after the cursor was placed; edit only when the window shows another file.
- Guard renderer window IDs as well as buffers because WinEnter can run after a pane closes but before its scheduled view teardown.
- Serve branch-specific review-thread fixtures through the fake API so integration tests exercise the intended parser and preview path.
- A write made while libuv rebuilds its single macOS FSEvents stream (after any watch start) emits no event; before asserting a watcher reaction, wait for watch reconciliation to settle and for a sentinel event on a later-started watch.
- After feeding a key with MiniTest, wait within the behavior's bound for its observable effect before sampling state because `nvim_input()` only queues the key.
- Measure synchronous mapped actions from immediately before key execution until the mapping returns so final draw work stays inside the sample.
- Gating fallback git-index polls on a confirmed watch event loses external staging made during the start gap; poll the index on every settling pass and gate only the pass count.
- auto-save.nvim's 1 s debounced write of a test's buffer edit races any later measured :write; turn it off before editing when a case counts writes, git runs or redraws.

## The loop

Agents fix bugs, build features and update plugins on this machine only. Nothing is pushed and no PR is
opened. [Archon](https://archon.diy/docs/) runs the workflows in `.archon/workflows/` on Codex by default,
with review on Claude Code (Setup facts).
Each run works in its own git worktree cut from `auto` and, when every gate is green, merges back into
`auto` with `--no-ff`. `main` is never touched. When `auto` moved past the branch, ship first runs
`make lint trace specs` on the merge in a temporary worktree; red goes to `reconcile` like a conflict.

| Command | What it does |
|---|---|
| `make fix BUG="…"` | `fix-bug`: root cause, spec delta, TDD fix. `BUG` can also be a change id |
| `make feature IDEA="…"` | `new-feature`: brainstorm, proposal with renders and a preview, then build (no approval stop) |
| `make queue [CHANGE=<id>]` | `work-queue`: the oldest change in `openspec/changes/` that no run has taken (no `loop/<id>` branch); afterwards `loop_clean.py --change` keeps one loop branch per change (drops reruns whose tip is on the kept one or on `auto`) |
| `make drain [N=<runs>]` | `drain.py`: foreground `make queue CHANGE=<id>` one change at a time (status read from the Archon DB) until the queue is empty, N runs, a paused run (a loop bug: no node pauses), or stop-infra cancels a run (broken host, exit 1); a `## Blocked` change runs too (its unblock step settles it) |
| `make drains [LANES=2] [N=<runs per lane>]` | `drain.py --lanes`: that many drains at once, lines prefixed `[lane <k>]`; a pick lock and a shared skip list keep two lanes off one change, a lane whose pick is empty waits while a live run works a change the rest `Depends:` on, and each `Depends:` edge sharing no `## Impact` path is printed first (ordering-only: drop it) |
| `make loop-clean [APPLY=1]` | `loop_clean.py`: remove worktree and branch of shipped or superseded `loop/*` runs; dry run unless `APPLY=1` |
| `make outdated` | plugins with commits past `lazy-lock.json` (read-only) |
| `make update PLUGIN=<name>` | `plugin-update`: update that one plugin, test it, ship it or adapt the config |
| `make preview CHANGE=<id> [OPEN=1]` | regenerate `openspec/changes/<id>/preview.html` and print its absolute path (`OPEN=1` is for you; the loop passes `OPEN=`) |
| `make console` | `archon serve`, the web console at http://localhost:3090 |
| `make loop-report [RUN=<id>]` | generate a local HTML report for the named run, or the latest run for this codebase |
| `make self-check CHANGE=<id>` | the gate's cheap checks (hard rules: `integrity.py`, `pinned.py --check`; lint, types, strict validation of the change and of its trial archive), run by implement and fix before they commit |
| `make loop-status` / `make loop-validate` | active and last runs plus the latest report URI / `archon validate workflows` |

Run the targets from `~/.config/nvim` (the `auto` checkout). `fix`, `feature`, `queue` and `update` are
interactive-class workflows, so they stay in the foreground; no node pauses for you.

Steps are small and know their place in the flow (each prompt opens with the flow and its own
input, output and limits). Scripts do everything that needs no judgment:

| Step | Runs as | Skill | Output |
|---|---|---|---|
| diagnose (fix) / brainstorm (feature) | agent | `superpowers:systematic-debugging` / `superpowers:brainstorming` | `root-cause.md` / `idea.md`, a few lines |
| spec | agent | `openspec-propose` (queued change: `openspec-continue-change`) | change folder + JSON |
| pinned (queued change, also with every adopted task ticked; fix-bug: spec runs it) | script `pinned.py` | none | main-spec scenarios that name a symbol the change touches (proposal What Changes/Impact minus Impact lines naming a main-spec title, branch diff) with no delta and no `## Impact` line; spec gives each a MODIFIED delta or an Impact line, the spec gate and `gate.py` (a hard rule) run `--check` |
| spec gate (queued change) | script `spec_gate.py` | none | `{ok, log}`: strict validate, trial archive, task scenario names, `pinned.py --check`; a red pass reruns spec once with the log (`spec-retry`, `spec-gate-2`), a second red gate fails the run with it |
| plan (only when spec wrote no tasks) | agent, low effort | `superpowers:writing-plans` | `tasks.md` |
| pack | script `context_pack.py` | none | `context.md`: next task, a bug's `## Evidence`, change, named files, lessons, last failures; `has_task` (false skips implement) |
| implement, once per task (one session for ≤ 4 tasks) | agent, fresh | `superpowers:test-driven-development` | 1 commit per task, ticked |
| check | script `gate.py` | none | a `## Blocked` change first (red with `blocked`, at once: no `make check`, no review), then hard rules (a violation is red at once: no `make check`, no review), then a quick tier (`make check CHECK_TARGETS=…` with `CAPS` of the touched capabilities, the areas requiring them and the tests naming a changed support file; `loop-test` for loop files; no e2e); after an approving review the `full-gate` node runs `make check E2E=1` once (a failed case reruns once unless the change owns it, a `tests/flaky.txt` case or one `flake_stats.py` finds flaky in 3+ recent runs up to 3 times; e2e failing on sandbox infra twice is `infra`: the run stops with no fix pass, no attempt, no reject), strict validate, untested change scenarios (`scenarios.py`, replaces a verify agent), JSON |
| fix (pass 2-3 only) | agent, fresh | `superpowers:systematic-debugging` (none when every finding is a hard rule) | 1 commit for the listed findings: one headless probe first for a non-obvious failure, at most 2 attempts, then `## Stuck` with the probe output, reverting only non-test edits and committing the red test with it (implement follows the same rule); after a Stuck pass the `fix-stuck-claude` node runs it once on Claude at xhigh effort with the Stuck text as its first finding and deletes the section once green; still stuck after it, the loop ends as exhausted (the judge rejects) |
| unblock (a `## Blocked` section) | agent, xhigh: default model, then Claude if one is left | none | 1 commit: each section settled on its recommendation, logged under `## Agent decisions` |
| review | agent, Claude | `superpowers:requesting-code-review` | JSON |
| verdict, judge, ship, follow-up | scripts | none | JSON, `escalation.md`, merge commit |

Agents run only their own test case and never `make quick` or `make check`; general instructions about web searches, extra skills and sub-agents do not apply in a step (`codex-loop.sh` also turns off Codex sub-agents, hooks, apps, the skills catalog, GUI and MCP tools, and the global `~/.codex/AGENTS.md`, and caps each tool output at 6000 tokens (`tool_output_token_limit`), and `codex_preflight.py` refuses the call when `codex --version` is outside its tested range or an MCP server or GUI plugin is still enabled; widen the range only after checking the overrides against the new Codex). A failure in loop tooling is never fixed inside a change: the step appends a `loop: …` line to `$ARTIFACTS_DIR/loop-notes.md`, which the judge lists as a note; a `## Blocked` section holding only `loop:` items blocks nothing and is listed the same way. The check/review
group runs at most 3 attempts (a blocked pass is none; at most 10 passes); a red pass sends only its findings (`verdict.py` `feedback`, which also
lists hard-rule violations from `integrity.py`) to the next pass's fix step. A fix pass stays on those
findings: verdict snapshots the change's proposal.md, `.openspec.yaml` and spec deltas, and the next gate
lists any of them the fix edited in `fix-scope.md`, a finding for the review. Verdict also snapshots the test
case names, and with `ARTIFACTS_DIR` set every `make test` adds the cases it collected to `case-seen.json`
(verdict clears it): a case the previous pass had, or a run of this pass saw, that is now in neither the branch
nor the base is a hard rule (`test added then removed during build`), and the judge rejects while it stays gone. The judge keeps the 15 newest
lessons in `## Loop lessons` (`lessons.py`), a new one replacing a near duplicate; a lesson about loop
tooling starts with `loop:` and is never kept.

Runs merge into `auto` one at a time under `.git/nvim-ship.lock`; ship waits up to 5 min (`SHIP_DIRTY_WAIT`) while the `auto` checkout has tracked edits, so edit the loop on a branch, not in `~/.config/nvim` (it holds the merging pid; delete it
only if that pid is not running). A run whose merge conflicts with `auto` goes through `reconcile`: an
agent merges `auto` into the branch and resolves it, the gate runs again, and ship retries, at most twice.

**Plugin updates** happen only on demand, one plugin per run; nothing updates plugins on a schedule
(lazy.nvim's `checker` is off). `make outdated` and `plugin-update` run lazy.nvim on an APFS clone of the
plugin dir, so live plugins and parsers are untouched. `plugin-update` updates the one plugin, shows its
changelog and runs `make check E2E=1` against the clone. Green: that `lazy-lock.json` line merges into
`auto`. Red: the breakage becomes an `update-<plugin>` change and `nvim-deliver` adapts the config. If
that does not ship (escalation rejected), the old pin stays and only the change merges, queued for the
next `make update PLUGIN=<name>` (`make queue` skips it). After a merge, run `:Lazy restore` in your
editor.

### Gates without you

- Preview: always for a feature, and for a fix that changes visible UI; `preview.html` is an artifact, never a
  pause, and nothing opens on the host (no `open`, `osascript` or browser).
- The judge (`.archon/scripts/escalation.py`) never asks. It rejects a test case the build added and then removed,
  a requirement removed and re-added, or your `## Decision` text reworded; it ships other breaking changes
  (a plugin added or removed, a core keymap or the leader changed, behaviour (a spec scenario) removed) with a
  `- note: breaking:` line. A scenario or capability renamed together with its
  `<capability>: <title>` tests, or a `## RENAMED Requirements` delta, is no removal; test cases count
  by name, so a lost one is rejected even when others are added. A deleted test file is no loss when
every case it held still exists by name in another test file. On ship, review findings marked `[minor]` (or
  under a `Minor (non-blocking):` heading) are `- note:` lines in `escalation.md`.
- A `## Blocked` section (one not only of `loop:` items) in a change's proposal.md or tasks.md goes to the
  unblock step (`.archon/commands/unblock.md`): the default model settles it at xhigh, then Claude if one is
  left. In `work-queue` that runs before spec, and one surviving both fails the run; in the build loop the
  next passes settle it, and one still standing is rejected and re-queued. A blocked change never ships.
- Small design choices the spec leaves open (format details, names, internal APIs, defaults, ordering) are the
  agent's: one line each under `## Agent decisions` in tasks.md, checked by the review. `## Blocked` is only for a
  choice beyond the spec or design, a contradiction or a breaking change (question, options, recommendation).
  A behaviour red after both attempts is `## Stuck`, not Blocked: it never holds a queued change;
  implement skips its task and goes on with the later ones, the build loop stays red on it (gate `stuck`), and an
  exhausted loop is rejected and re-queued with it (tasks.md keeps its text).

Partial or untested work never ships and never asks: a red check, unfinished tasks, an untested
scenario, a CRITICAL verify finding, a deleted or weakened test, an xfail without a queued change, or
committed conflict markers go back to fix; after 3 passes the judge rejects, the branch is kept and
`followup.py` re-queues it on `auto`: a change still active there gets `Adopt: <branch>` and a
`## Rejected run` section, an archived one a new `followup-<change>`. The next run merges the kept branch
first (`adopt.py`) and reverts its edits to `openspec/specs/` (data sections such as the shortcut table
excepted: archive never writes them): main specs change only by archive. When
the adopted tasks.md has every task ticked, the spec step is skipped (`tasks.py --adopted-state`;
visible UI is then read from design.md).

### Queue and known issues

Known issues and planned work are queued changes in `openspec/changes/`; there is no separate issue list.
`openspec list` shows them, `openspec/changes/archive/` holds the shipped ones.

- Queue an issue: `openspec new change fix-<topic>`, then write `proposal.md` (Why, `Kind: bug|feature`,
  What Changes, Impact; a bug adds `## Evidence`: `file:line` refs or probe output for its root cause, which the
  context pack hands to implement and fix). A proposal alone is enough: `work-queue` completes the spec delta, design and
  tasks before building. Add a spec delta yourself when the correct behaviour is already clear.
- Work it: `make queue` (oldest first) or `make queue CHANGE=<id>`; `make drain` works them all.
- A change with no behaviour or look change (test-only, refactor, follow-up) sets `skip_specs: true` in
  `.openspec.yaml`, and the spec step writes only tasks.md.
- `work-queue`'s `meta` script (`no_design.py`) sets the schema before the spec step, which never changes it:
  `spec-driven` (with design.md) for a feature or a proposal/design.md holding a render, else the repo-local
  `spec-driven-no-design` (`openspec/schemas/`, no design artifact, spec deltas allowed; skip_specs always).
- The spec step never returns JSON (a schema made it repeat the answer every turn). The `classify` script
  (`classify.py`) answers after it: visible UI when design.md has a render section (written only for a new or
  changed look), architecture when proposal.md `## Impact` or tasks.md names plugin wiring or load-order files
  (`lua/gleb/plugins/`, `init.lua`, `lazy-lock.json`, `docs/architecture.md`); a skip_specs change is neither.
  Visible UI sends a fix to the preview.
- Order: a `Depends: <change>[, <change>]` line in proposal.md holds the change until those are archived. Write it only when the change needs the other's code (it idles a `make drains` lane otherwise), and keep changes small (one behaviour, few files), so both lanes stay busy.
- A test that pins a known bug wraps the case in `H.xfail("<change id>", fn)` ([testing](testing.md)).

### Where to look

- **Console** (`make console`): runs, node output, gate buttons, logs. Transcripts and artifacts
  (`root-cause.md`, `check-<n>.log`, `escalation.md`) are under
  `~/.archon/workspaces/GlebBeloded/nvim.config/` in `logs/` and `artifacts/runs/<run-id>/`.
- **Run report** (`make loop-report [RUN=<id>]`): writes
  `<output_root>/artifacts/runs/<id>/report.html` and prints its local URI. `make loop-status` prints the
  latest report URI after the active and recent runs.
- **git**: `git log --first-parent auto` lists one merge per shipped run; run branches are `loop/*`.
  After a merge, ship starts `loop_clean.py` for its run: once no running or paused run holds it, the
  run's worktree and branch go (log: `.git/nvim-loop-clean.log`). `make loop-clean` lists every
  `loop/*` branch: shipped or superseded ones (tip on `auto`) to remove, the rest kept with the reason
  (unmerged commits, uncommitted changes, a live run).
- **Resume or stop**: `archon workflow runs`, `archon workflow resume <run-id>`,
  `archon workflow abandon <run-id>`, `archon complete <branch>`.

### Setup facts

- `.archon/config.yaml`: base branch `auto`, remote `local` (a self-remote added by `make loop-setup`), so
  `auto` never has to exist on GitHub.
- Provider: `assistant: codex` in `.archon/config.yaml` runs the loop on Codex; the one line
  `assistant: claude` switches it back to Claude Code. The `review` node keeps `provider: claude`
  under either default, so review is always cross-model.
- Codex loads repo skills from `.agents/skills` and superpowers from the Codex plugin
  `superpowers@openai-curated-remote`. Archon hides Codex's skill list, so commands invoke each skill
  as `$<skill>`. Archon runs Codex with no sandbox, network on and no approval prompts: `make check
  E2E=1` and `lume ssh` to the sandbox VM need nothing extra, and there are no Codex hooks.
- Claude runs with `bypassPermissions` and project settings. There are no Claude Code hooks: the
  `implement` command runs `make fmt` and `make quick` itself, and the full `make check E2E=1` runs
  once per build pass in the `gate` script.
- Plugins: `make loop-setup` installs the plugins that `.claude/settings.json` enables at **user**
  scope. Project scope is recorded per path, and every Archon worktree is a new path, so a
  project-scope install never loads in a run. It also installs every Codex plugin a codex node
  declares.
- AI nodes can use only the skills they declare (`skills:` on the node). Add a skill there before a
  prompt mentions it. Each workflow's `skills-check` node fails the run when a declared skill does
  not resolve in the worktree for the provider that runs the node, and every command loads its
  declared skills (Skill tool on Claude, `$<skill>` on Codex) as its first step. Archon's "Claude
  skills not found on disk: superpowers:…" warning is expected for plugin skills; `skills-check` is
  the real check.

## Design renders

A render is a fixed-width text picture of the Neovim screen. UI is sketched, compared and approved as
renders before any code, and the approved one becomes the reference screenshot the screen test asserts.
The binding rules are in `openspec/config.yaml` under `rules.design`.

### Notation

- **Caption** first: label (Current, Proposed A, B, …), `<cols>x<rows>`, mode, buffer, and any state that
  matters (LSP attached, git changes, focus). An excerpt says so: `excerpt: statusline row`.
- **Fence** is always ```` ```text ````, at most 100 columns, one line per screen row.
- **Real content**: real file names, code, branches and messages from this repo, never `foo`/`bar`.
- **Single-width characters only.** Use stand-ins for Nerd Font glyphs and emoji, and a 2-character
  stand-in for a double-width glyph:

  | Stand-in | Meaning | Stand-in | Meaning |
  |---|---|---|---|
  | `█` | cursor cell | `◆` | filetype logo (devicons) |
  | `⎇` | git branch | `( )` | rounded pill caps |
  | `+ ~ -` | diff added / changed / removed | `▸ ▾` | tree expander |
  | `✗ ▲` | diagnostics error / warn | `■` | folder icon |
  | `⠹` | spinner frame | `LL` | 🦙 (2 columns) |

- **Windows**: `│` between vertical splits, `─` between horizontal ones (no per-window statuslines with
  `laststatus=3`). Floats are drawn over the windows below with their border (`rounded` is `╭─╮│╰─╯`),
  title in the top border, footer in the bottom. The bufferline shows buffers, not tabs: draw one render
  per tab page and say which is current.
- **Colors**: name highlight groups as `[Name]`, never a color alone. When color matters, add a **mask**
  right after the render (same rows and width, one letter per cell, `.` or space for [Normal]) and a
  `Legend:` paragraph mapping each letter to an exact group name (no wildcards; lualine groups name a
  mode). `make colorize` turns render + mask + legend into the real colors.

### Example

**Proposed B**: `100x1`, excerpt: statusline row, Normal mode, `lua/gleb/keymaps.lua`, lua_ls attached

```text
 NORMAL  ⎇ auto  + 3 ~ 1                                                           ✗ 0 ▲ 0  ● ◆ lua 
```

```text
aaaaaaaabbbbbbbbbbbbbbbbbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccxxxxwwwcmomlmmmmm
```

Legend: `a` [lualine_a_normal] · `b` [lualine_b_normal] · `c` [lualine_c_normal] ·
`x` [lualine_x_diagnostics_error_normal] · `w` [lualine_x_diagnostics_warn_normal] ·
`o` [StatuslineLspOk] · `l` [StatuslineLang_lua] · `m` [StatuslineLangText]

Trade-off line under the options, e.g.: "B works without Nerd Font caps and reads in a monochrome
screenshot; A needs the caps." The picked option and why are recorded in `design.md`.

### Seeing renders in color

- **Current** (the real screen): `make render CASE=<case> [COLUMNS=100 LINES=30]` runs the real config in a
  private tmux, drives a case from `tests/render/cases.lua` and writes `renders/<case>.ansi`
  (`less -R` to view). `MONO=1` prints plain text to paste into a doc. Add a case with one entry in
  `cases.lua`.
- **Proposed** (mockups): `make colorize FILE=<design.md>` prints every render of a file, colored from the
  real colorscheme where a mask and legend exist; unknown groups are reported.

### Flow

1. Explore with a Current render (`make render … MONO=1`) and Proposed A/B/C, each with a mask when color
   matters; check them with `make colorize`.
2. The user (core UI or keymaps) or the agent picks one and records why.
3. `design.md` carries Current and the picked Proposed render; the spec delta adds a reference-screenshot
   scenario naming it.
4. The first task writes the screen test with the caption's size and state; it fails until the code
   matches. Finish by comparing `make render` with `make colorize` of the approved render.

## Debugging a shortcut

Keys pass macOS → Alacritty → zellij → Neovim ([terminal stack](architecture.md#terminal-stack)). The
[shortcuts spec](../openspec/specs/shortcuts/spec.md) holds the key table; `make chain` and `make stack`
check it against the real configs. When a key does nothing, test bottom up:

1. macOS: the app menu owns Cmd+Q/Cmd+H before Alacritty sees them. Run `make menu-keys`, fully quit and
   relaunch Alacritty; afterward Quit is Cmd+Option+Control+Q.
2. Alacritty: `alacritty --print-events | grep KeyboardInput` shows the key; `xxd` outside zellij shows the
   bytes sent (`1b 64` = Alt+d). Config: `~/.config/alacritty/keymaps_macos.toml`; quit Alacritty fully
   (Cmd+Option+Control+Q) after edits.
3. zellij: a bind in `shared_except "locked"` always wins, even over Neovim. KDL writes `bind "Alt d"`,
   not escape codes. `zellij setup --check` validates the config.
4. Neovim: `:verbose map <A-d>`, and `i<C-v>` then the key shows what Neovim really receives. Map that
   exact notation (e.g. `<S-D-=>` for Cmd+Shift+=). The debug log takes the `Last set from` line of
   `:verbose map`; run `:lua require("gleb.nvim_debug_log").stop()` first to see it on screen.
