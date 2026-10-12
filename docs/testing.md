# Testing

`make check` is the merge gate (the loop's `gate` script runs it). `make quick` is the inner loop (the Claude Code Stop hook runs it). The loop is fully local; there is no hosted CI.

| Command | What runs | Wall time (14-core Mac) |
|---|---|---|
| `make check` | every layer below, concurrently (`tests/check.sh`); smoke startup timing runs alone afterwards. e2e runs only if it needs no window focus (else `skip`) | ~15 s |
| `make check E2E=1` | the same, e2e with focus bursts; the loop's gate (`.archon/scripts/gate.py`) | ~15 s + e2e |
| `make quick` | lint + trace, plus only the layers the changes vs `BASE` (default `auto`) can affect (`tests/quick.sh` has the mapping) | <1 s docs only, ~7 s one capability |
| `make test FILE=… CASE=…` | one file / matching cases | ~1–3 s |

`check.sh` prints one status line per layer as it finishes, then the full log of every failed layer. A layer that cannot run here prints `skip` with its reason (e2e without Accessibility). `make quick` takes `ALL=1`, `STACK=1`, `E2E=1`, `SMOKE=1` and `TYPES=1` to force a layer.

Pyramid, bottom to top. Times are wall times of one layer on its own (in `make check` they overlap).

| Layer | Command | What it checks | Time |
|---|---|---|---|
| Static | `make lint` | `stylua --check` and `selene` on `lua/ init.lua tests/` | <1 s |
| Static | `make types` | `lua-language-server --check` with `.luarc.jsonc` (LuaJIT, `vim` global, `$VIMRUNTIME` as library), gate at Warning | ~6 s, 0 s cached |
| Static | `make trace` | scenario ↔ test matrix, fails on orphan tests | <1 s |
| Static | `make chain` | real Alacritty + zellij configs parsed and routed, mappings checked in a child Neovim; prints the shortcut table ([shortcut layers](#shortcut-layers)) | ~2 s |
| Unit | `make test-unit` | one module in a *bare* child Neovim (`tests/minimal_init.lua`, no user config, plugins added one by one) | `make test` (all three): ~10 s |
| Integration | `make test-integration` | behaviour of the *real* config in a child Neovim (keys, autocmds, plugins) | |
| Screen | `make test-screen` | reference screenshots (`tests/screenshots/`) of the real config | |
| Stack | `make stack` | real zellij (user keybinds) in a tmux pty with the real Neovim config, fed Alacritty's bytes | ~6 s |
| E2E | `make e2e` | real Alacritty window + zellij + Neovim, real macOS key events; needs Accessibility, else skipped | ~2 s to ready; full run not measured yet; 0.3 s skipped |
| Smoke | `make smoke` | headless start of the real config: nothing in `:messages` or stderr, no `ERROR` in `:checkhealth`, startup time within budget | ~7 s health, ~2 s startup |

`make test` runs all three mini.test layers (`tests/parallel.lua`): the matched cases are sharded over `JOBS` headless workers (default cores − 2; `JOBS=1` runs serially), balanced by the case durations of earlier runs (`.tests/timings.json`), and reported as one mini.test report with fails and notes at the end. Every worker has its own sandbox (see [Isolation](#isolation)). `make screenshots`, `chain`, `stack` and `e2e` run in one process. `make deps` fetches the pinned test dependency, mini.nvim v0.18.0, into `.tests/deps` (gitignored) via `tests/bootstrap.sh`. It is not part of the plugin list. `make install` installs the static tools with brew.

To narrow a run, use `FILE=tests/unit/session/test_key.lua make test`, `CAPS=session,keymaps make test` (only `tests/<layer>/<cap>/`) or `CASE="Move to left" make test-integration`.

`make types` caches a green result in `.tests/types.ok`, keyed by the content of every Lua file, `.luarc.jsonc`, the LuaLS version and the libraries; it skips LuaLS while that key is unchanged.

Run make from inside Neovim's `:terminal` as usual: the binary is `NVIM_BIN` (not `NVIM`, which Neovim sets to its server address).

## Layout

```
tests/
  minimal_init.lua      runner + bare-child init (rtp: checkout + mini.nvim)
  child_init.lua        --cmd for full-config children (in-memory clipboard)
  helpers.lua           sandbox, child factory, screenshot helpers, xfail
  runner.lua            mini.test entry point (one process, or one shard)
  parallel.lua          make test*: shards cases over JOBS workers, merged report
  check.sh / quick.sh   make check / make quick
  <layer>/<capability>/test_<topic>.lua
  shortcuts/            chain + stack harness (configs.py, chain.lua, stack.lua)
  e2e/                  e2e harness (alacritty.lua, keys.swift, build.sh)
  screenshots/          reference screenshots (text, committed)
  smoke/                make smoke (run.lua outside, probe.lua inside nvim)
  render/               make render / make colorize (cases.lua, tmux capture, mockup colorizer)
  trace.lua             make trace
```

`<layer>` is `unit`, `integration` or `screen`, and `<capability>` is the directory name under `openspec/specs/`.

## Isolation

Every child gets its own sandbox (`tests/helpers.lua`), so tests never touch your sessions, shada, undo files or clipboard:
- `XDG_CONFIG_HOME/nvim` is a symlink to this checkout, so `stdpath("config")` is the worktree and not `~/.config/nvim`.
- `XDG_DATA_HOME` and `XDG_STATE_HOME` are fresh temp dirs for each child start. Only `lazy/` (plugins) and `site/` (treesitter parsers) are symlinked from `NVIM_TEST_DATA_DIR` (default `~/.local/share/nvim`; point it at any dir where `Lazy! restore` installed the plugins). `XDG_CACHE_HOME` is a temp dir shared by one runner process (each parallel worker has its own). Neovims never start concurrently on one cache: vim.loader writes its byte code in place, so a concurrent start can load a half-written module (smoke warms the cache before its probe and timing overlap).
- mini.test passes `--clean`, so the child reads and writes no shada.
- Multiplexer env vars (`ZELLIJ*`, `TMUX*`, `WEZTERM_PANE`, `KITTY_*`) are unset, so smart-splits never moves your terminal panes.
- `g:clipboard` is an in-memory provider (`tests/child_init.lua`).
- `copilot.lua` is disabled in full-config children because it lazy-loads on InsertEnter and talks to the network.
- nvim-debug-log writes `/tmp/nvim/<time>_<pid>.txt` (hard-coded). The harness deletes its own children's files by pid.

## Naming rule = traceability

A test case name is exactly `"<capability>: <scenario title>"`, matching a `#### Scenario:` heading in `openspec/specs/<capability>/spec.md`:

```lua
T["keymaps: Move to left window"] = function() ... end
```

`make trace` collects every case with `MiniTest.collect`, parses every spec, and prints `tested` / `MISSING` per scenario (`VERBOSE=1` lists them) plus orphans. It exits non-zero only for orphans, i.e. cases whose name matches no scenario. Missing scenarios are reported as a count.

## Adding a test for a scenario

1. Pick the layer. Use unit for a module that runs on its own (stub its plugin deps or add them with `child.start_bare({ "plugin.nvim" })`). Use integration for anything that needs the real config, and screen for visual-only scenarios.
2. Create or extend `tests/<layer>/<capability>/test_<topic>.lua`:

   ```lua
   local MiniTest = require("mini.test")
   local H = require("tests.helpers")
   local eq = MiniTest.expect.equality
   local child = H.new_child()

   local T = H.child_set(child, child.start_config) -- fresh child per case

   T["keymaps: Move to right window"] = function()
   	child.cmd("vsplit")
   	...
   end

   return T
   ```
3. Copy the scenario title verbatim. `make trace` shows it as tested.
4. Useful helpers: `child.wait_very_lazy()` (VeryLazy needs UIEnter, which headless never fires), `child.wait(lua_expr, ms)`, `child.disable_plugin(name)`, `H.screen_rows(child, -1)` (statusline row), `H.expect_screenshot(shot)`.

If no scenario exists yet, add it to the spec first (via an OpenSpec change). Never invent a test name.

## How bugs become tests

Specs describe current behaviour, and tests assert the spec.
- A finding where the spec already describes the buggy behaviour is fixed with an OpenSpec change. Change the scenario, write the failing test (named after the new scenario), then fix the code.
- When the code does not do what the spec says (e.g. the codediff crash queued as `openspec/changes/fix-diff-preview-codediff-crash`), wrap the case in `H.xfail("<change id>", fn)`. It reports a skipped case with an `XFAIL` note while the bug exists, and fails with `XPASS` once it is fixed, so the marker gets removed.

## Screenshots

Screen tests call `H.expect_screenshot(...)` (mini.test `reference_screenshot`). The references are plain text in `tests/screenshots/`, named after the case, with one block for text and one for attribute identity. They are committed.
- A missing reference is created on the first run, and the case passes with a note. Review the new file and commit it.
- After an intended visual change, run `make screenshots` (`UPDATE_SCREENSHOTS=1`) and review `git diff tests/screenshots`.
- Attributes are compared by identity, not by color. For colors, assert the resolved highlight of a statusline segment: `H.expect_colors(H.statusline_colors(child, "NORMAL"), { bg = "#a9b665", bold = true })` compares only the given fields (`fg`, `bg` as `#rrggbb`, `bold`, `italic`) of the combined groups that draw the first occurrence of the text.

## Seeing the current render

`make render CASE=<case>` starts the real config (same isolation as the tests) in a private, detached tmux server sized `COLUMNS` x `LINES` (default 80x24, `TERM=tmux-256color`, truecolor), runs the case's setup over RPC, waits until the screen stops changing, and captures the pane with `tmux capture-pane -e`. It prints the colored capture and writes `renders/<case>.ansi` (gitignored, `OUT=path` to override); view it with `cat` or `less -R`. `MONO=1` prints the plain mini.test screenshot instead (`ATTR=1` adds the attribute block). Plain `make render` lists the cases.

Cases live in `tests/render/cases.lua`: one entry per case with a description and a `setup(driver)` that uses `driver.lua`, `driver.cmd`, `driver.type_keys` and `driver.wait` (a mini.test child satisfies the same interface, so MONO and colored renders share the setup).

`make colorize FILE=<doc.md>` prints the renders of a design doc, colored where a mask and legend are given (see [workflow.md](workflow.md#seeing-renders-in-color)).

## Smoke details

`tests/smoke/run.lua` lists the healthchecks it skips (they need external tools, or their known issues are queued in openspec/changes) and the known-benign ERROR lines. `make smoke` runs the probe (messages, checkhealth) concurrently with the timing, after one warm-up start; `make smoke-health` and `make smoke-startup` run one part. The startup budget defaults to 400 ms and is checked on the median of 3 `--startuptime` runs. Over budget, it takes 6 more samples and checks the fastest of all 9, since load only adds time; the line then shows the load average. Override the budget with `STARTUP_BUDGET_MS`.

## Claude Code hooks

`.claude/settings.json` (committed) sets two hooks:
- PostToolUse on `Edit|Write|MultiEdit`: `.claude/hooks/lua-format.sh` runs stylua on the edited `*.lua` file, then selene. Selene findings go back to Claude (exit 2).
- Stop: `.claude/hooks/stop-check.sh` runs `make quick` when the work tree has changes, and blocks (exit 2, tail of the log) if it is red. When the hook fires again for the same stop (`stop_hook_active`), it lets Claude stop, so the gate cannot loop forever.

## Shortcut layers

Keys go Alacritty → zellij → Neovim, so the `shortcuts` capability (`openspec/specs/shortcuts/spec.md`) is tested across the whole chain. Its shortcut and collision tables are the source of truth; the tests parse them.

The Alacritty and zellij configs are external and unversioned. They are read-only, from `$ALACRITTY_CONFIG_DIR` / `$ZELLIJ_CONFIG_DIR`, else `<repo>/terminal/<tool>`, else `~/.config/<tool>`. A change there can turn `make check` red without a commit here.

- **chain** (`tests/chain/`, ~2 s, in `make check`): `tests/shortcuts/configs.py` parses the TOML (imports followed) and the KDL (kdl-py, pinned in `.tests/venv` by `make deps-shortcuts`) and resolves zellij's keybind semantics. `tests/shortcuts/chain.lua` decodes bytes the way zellij and Neovim's TUI do and models vim-zellij-navigator. Then each row is checked against Alacritty, zellij (normal and locked mode) and `maparg` in a child Neovim.
- **stack** (`tests/stack/`, ~10 s, in `make check`): `tests/shortcuts/stack.lua` runs tmux, used only as the pty. Inside it run real zellij with a copy of the user's config (session serialization off; keybinds unchanged) and a fixed layout: Neovim with the real config on the left, `cat` on the right. Every process gets a temp dir under `/tmp`, which holds its own HOME (zellij cache with pre-granted plugin permissions), socket dirs and the helpers sandbox. Bytes are sent with `tmux send-keys -H`. Results are read from recorder mappings over RPC and from `zellij action list-clients`. Everything is cleaned up, even after a failure. `TMUX` and `TERM_PROGRAM` are unset for zellij, otherwise smart-splits picks its tmux backend.
- **e2e** (`tests/e2e/`, `make e2e`): starts a dedicated Alacritty instance with the repo's `terminal/alacritty` config (imports pointed at it, fixed size) without activating it, running the stack layer's zellij + Neovim setup. `tests/e2e/keys.swift` (built and cached in `.tests/e2e/` by `tests/e2e/build.sh`) launches it, checks `AXIsProcessTrusted`, and posts real key events to its pid (`CGEventPostToPid`, US key positions, modifier down/up events). At start one probe key shows whether events reach the window in the background. If they do not, each test's key burst makes the window frontmost and gives focus back to the previous app afterwards; that mode runs only with `E2E=1` (`make e2e`, `make check E2E=1`, the loop's gate) and `make check` alone reports `skip`. The window, the zellij session and the temp dir are removed by `stop()`, and by a detached watchdog if the runner dies. `make quick` adds e2e (with `E2E=1`) when `terminal/`, keymaps, `tests/shortcuts/`, `tests/e2e/` or the shortcuts spec change and Accessibility is granted.

  Permission: macOS charges Accessibility to the app that started the process chain (for a shell in Alacritty, Alacritty itself; the skip line names it). Enable it in System Settings > Privacy & Security > Accessibility. Without it every e2e case is skipped with that one-line fix. While a burst runs, your own keystrokes would land in the test window.

Kitty keyboard protocol: zellij always pushes kitty flag 1 to Alacritty (`\e[>1u`) and answers Neovim's `CSI ? u`, so Neovim runs with kitty keys inside zellij. `chars` bindings are sent verbatim. Keys without a binding (Ctrl+Return, Ctrl+H, Ctrl+Q, Ctrl+arrows) are sent by the stack layer in Alacritty's flag-1 encoding (`alacritty/src/input/keyboard.rs`, e.g. Ctrl+Return = `\e[13;5u`). Only the e2e layer checks Alacritty's real encoding, `option_as_alt`, and macOS key handling.
