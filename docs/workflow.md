# Workflow

How to operate this repo: the local AI loop, the queue, design renders, and debugging shortcuts. Tests
and their layers are in [testing](testing.md). The loop's stages and gates are drawn in
[architecture](architecture.md#ai-maintenance-loop).

## The loop

Agents fix bugs, build features and update plugins on this machine only. Nothing is pushed and no PR is
opened. [Archon](https://archon.diy/docs/) runs the workflows in `.archon/workflows/` with Claude Code.
Each run works in its own git worktree cut from `auto` and, when every gate is green, merges back into
`auto` with `--no-ff`. `main` is never touched.

| Command | What it does |
|---|---|
| `make fix BUG="…"` | `fix-bug`: root cause, spec delta, TDD fix. `BUG` can also be a change id |
| `make feature IDEA="…"` | `new-feature`: brainstorm, proposal with renders; always stops for your approval |
| `make queue [CHANGE=<id>]` | `work-queue`: the oldest change in `openspec/changes/` that no run has taken (no `loop/<id>` branch) |
| `make outdated` | plugins with commits past `lazy-lock.json` (read-only) |
| `make update PLUGIN=<name>` | `plugin-update`: update that one plugin, test it, ship it or adapt the config |
| `make preview CHANGE=<id> [OPEN=1]` | regenerate `openspec/changes/<id>/preview.html` |
| `make console` | `archon serve`, the web console at http://localhost:3090 |
| `make loop-status` / `make loop-validate` | active and last runs / `archon validate workflows` |

Run the targets from `~/.config/nvim` (the `auto` checkout). `fix`, `feature`, `queue` and `update` can
pause, so they stay in the foreground. Answer gates in the terminal, in the console, or from another shell with
`archon workflow approve|reject|respond <run-id> [text]`.

Implement, verify, align and review form one group that runs at most 3 times; each pass starts with the
previous pass's failures. After 3 red passes the run escalates.

**Plugin updates** happen only on demand, one plugin per run; nothing updates plugins on a schedule
(lazy.nvim's `checker` is off). `make outdated` and `plugin-update` run lazy.nvim on an APFS clone of the
plugin dir, so live plugins and parsers are untouched. `plugin-update` updates the one plugin, shows its
changelog and runs `make check E2E=1` against the clone. Green: that `lazy-lock.json` line merges into
`auto`. Red: the breakage becomes an `update-<plugin>` change and `nvim-deliver` adapts the config. If
that does not ship (escalation rejected), the old pin stays and only the change merges, queued for the
next `make update PLUGIN=<name>` (`make queue` skips it). After a merge, run `:Lazy restore` in your
editor.

### When you get pinged

- The design gate: always for a feature, and for a fix that changes visible UI or architecture.
  `preview.html` opens in the browser (renders side by side, mermaid diagrams, proposal and design).
- The escalation gate before ship (`.archon/scripts/escalation.py`), when the change adds a plugin,
  changes a core keymap or the leader, removes or weakens a spec scenario, deletes or disables a test, or
  exhausted the fix loop.

Everything else ships without asking. A rejected gate cancels the run and keeps its branch and worktree.

### Queue and known issues

Known issues and planned work are queued changes in `openspec/changes/`; there is no separate issue list.
`openspec list` shows them, `openspec/changes/archive/` holds the shipped ones.

- Queue an issue: `openspec new change fix-<topic>`, then write `proposal.md` (Why, `Kind: bug|feature`,
  What Changes, Impact). A proposal alone is enough: `work-queue` completes the spec delta, design and
  tasks before building. Add a spec delta yourself when the correct behaviour is already clear.
- Work it: `make queue` (oldest first) or `make queue CHANGE=<id>`.
- A test that pins a known bug wraps the case in `H.xfail("<change id>", fn)` ([testing](testing.md)).

### Where to look

- **Console** (`make console`): runs, node output, gate buttons, logs. Transcripts and artifacts
  (`root-cause.md`, `check-<n>.log`, `escalation.md`) are under
  `~/.archon/workspaces/GlebBeloded/nvim.config/` in `logs/` and `artifacts/runs/<run-id>/`.
- **git**: `git log --first-parent auto` lists one merge per shipped run; run branches are `loop/*`.
  `archon isolation cleanup --merged` removes merged run worktrees (the make targets run it).
- **Resume or stop**: `archon workflow runs`, `archon workflow resume <run-id>`,
  `archon workflow abandon <run-id>`, `archon complete <branch>`.

### Setup facts

- `.archon/config.yaml`: base branch `auto`, remote `local` (a self-remote added by `make loop-setup`), so
  `auto` never has to exist on GitHub.
- Claude runs with `bypassPermissions` and project settings, so the superpowers plugin in
  `.claude/settings.json` is active. There are no Claude Code hooks: the `implement` command runs
  `make fmt` and `make quick` itself, and the full `make check E2E=1` runs once per build pass in the
  `gate` script.
- AI nodes can use only the skills they declare (`skills:` on the node). Add a skill there before a
  prompt mentions it.
- `--dry-run` auto-approves gates with the plain string `approved`, so nodes that read
  `$gate.output.decision` fail in a dry run. Pass `--pause-at-gates`, or stub the nodes after the gate.

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

1. macOS: System Settings → Keyboard → App Shortcuts may own it (Cmd+H hides the app until remapped there).
2. Alacritty: `alacritty --print-events | grep KeyboardInput` shows the key; `xxd` outside zellij shows the
   bytes sent (`1b 64` = Alt+d). Config: `~/.config/alacritty/keymaps_macos.toml`; quit Alacritty fully
   (Cmd+Q) after edits.
3. zellij: a bind in `shared_except "locked"` always wins, even over Neovim. KDL writes `bind "Alt d"`,
   not escape codes. `zellij setup --check` validates the config.
4. Neovim: `:verbose map <A-d>`, and `i<C-v>` then the key shows what Neovim really receives. Map that
   exact notation (e.g. `<S-D-=>` for Cmd+Shift+=). The debug log takes the `Last set from` line of
   `:verbose map`; run `:lua require("gleb.nvim_debug_log").stop()` first to see it on screen.
