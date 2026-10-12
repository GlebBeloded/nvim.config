# Testing

`make check` is the gate. It runs every layer below in pyramid order, and the Claude Code Stop hook runs it. The loop is fully local; there is no hosted CI.

| Layer | Command | What it checks |
|---|---|---|
| Static | `make lint` | `stylua --check` and `selene` on `lua/ init.lua tests/` |
| Static | `make types` | `lua-language-server --check` with `.luarc.jsonc` (LuaJIT, `vim` global, `$VIMRUNTIME` as library), gate at Warning |
| Unit | `make test-unit` | one module in a *bare* child Neovim (`tests/minimal_init.lua`, no user config, plugins added one by one) |
| Integration | `make test-integration` | behaviour of the *real* config in a child Neovim (keys, autocmds, plugins) |
| Screen | `make test-screen` | reference screenshots (`tests/screenshots/`) of the real config |
| Smoke | `make smoke` | headless start of the real config: nothing in `:messages` or stderr, no `ERROR` in `:checkhealth`, startup time within budget |
| Trace | `make trace` | scenario ↔ test matrix, fails on orphan tests |

`make test` runs all three mini.test layers in one process. `make deps` fetches the pinned test dependency, mini.nvim v0.18.0, into `.tests/deps` (gitignored) via `tests/bootstrap.sh`. It is not part of the plugin list. `make install` installs the static tools with brew.

To narrow a run, use `FILE=tests/unit/session/test_key.lua make test` or `CASE="Move to left" make test-integration`.

## Layout

```
tests/
  minimal_init.lua      runner + bare-child init (rtp: checkout + mini.nvim)
  child_init.lua        --cmd for full-config children (in-memory clipboard)
  helpers.lua           sandbox, child factory, screenshot helpers, xfail
  runner.lua            mini.test entry point used by the Makefile
  <layer>/<capability>/test_<topic>.lua
  screenshots/          reference screenshots (text, committed)
  smoke/                make smoke (run.lua outside, probe.lua inside nvim)
  render/               make render / make colorize (cases.lua, tmux capture, mockup colorizer)
  trace.lua             make trace
```

`<layer>` is `unit`, `integration` or `screen`, and `<capability>` is the directory name under `openspec/specs/`.

## Isolation

Every child gets its own sandbox (`tests/helpers.lua`), so tests never touch your sessions, shada, undo files or clipboard:
- `XDG_CONFIG_HOME/nvim` is a symlink to this checkout, so `stdpath("config")` is the worktree and not `~/.config/nvim`.
- `XDG_DATA_HOME` and `XDG_STATE_HOME` are fresh temp dirs for each child start. Only `lazy/` (plugins) and `site/` (treesitter parsers) are symlinked from `NVIM_TEST_DATA_DIR` (default `~/.local/share/nvim`; point it at any dir where `Lazy! restore` installed the plugins). `XDG_CACHE_HOME` is a temp dir shared by one run.
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
- When the code does not do what the spec says (e.g. the codediff crash in `openspec/findings.md`), wrap the case in `H.xfail("<finding>", fn)`. It reports a skipped case with an `XFAIL` note while the bug exists, and fails with `XPASS` once it is fixed, so the marker gets removed.

## Screenshots

Screen tests call `H.expect_screenshot(...)` (mini.test `reference_screenshot`). The references are plain text in `tests/screenshots/`, named after the case, with one block for text and one for attribute identity. They are committed.
- A missing reference is created on the first run, and the case passes with a note. Review the new file and commit it.
- After an intended visual change, run `make screenshots` (`UPDATE_SCREENSHOTS=1`) and review `git diff tests/screenshots`.
- Attributes are compared by identity, not by color. For colors, assert the resolved highlight of a statusline segment: `H.expect_colors(H.statusline_colors(child, "NORMAL"), { bg = "#a9b665", bold = true })` compares only the given fields (`fg`, `bg` as `#rrggbb`, `bold`, `italic`) of the combined groups that draw the first occurrence of the text.

## Seeing the current render

`make render CASE=<case>` starts the real config (same isolation as the tests) in a private, detached tmux server sized `COLUMNS` x `LINES` (default 80x24, `TERM=tmux-256color`, truecolor), runs the case's setup over RPC, waits until the screen stops changing, and captures the pane with `tmux capture-pane -e`. It prints the colored capture and writes `renders/<case>.ansi` (gitignored, `OUT=path` to override); view it with `cat` or `less -R`. `MONO=1` prints the plain mini.test screenshot instead (`ATTR=1` adds the attribute block). Plain `make render` lists the cases.

Cases live in `tests/render/cases.lua`: one entry per case with a description and a `setup(driver)` that uses `driver.lua`, `driver.cmd`, `driver.type_keys` and `driver.wait` (a mini.test child satisfies the same interface, so MONO and colored renders share the setup).

`make colorize FILE=<doc.md>` prints the renders of a design doc, colored where a mask and legend are given (see [design-renders.md](design-renders.md#viewing-renders-in-color)).

## Smoke details

`tests/smoke/run.lua` lists the healthchecks it skips (they need external tools, or their known issues are in findings) and the known-benign ERROR lines. The startup budget defaults to 400 ms and is the median of 5 `--startuptime` runs after a warm-up. Override it with `STARTUP_BUDGET_MS` (for example on a slow or busy machine).

## Claude Code hooks

`.claude/settings.json` (committed) sets two hooks:
- PostToolUse on `Edit|Write|MultiEdit`: `.claude/hooks/lua-format.sh` runs stylua on the edited `*.lua` file, then selene. Selene findings go back to Claude (exit 2).
- Stop: `.claude/hooks/stop-check.sh` runs `make check` when the work tree has changes, and blocks (exit 2, tail of the log) if it is red. When the hook fires again for the same stop (`stop_hook_active`), it lets Claude stop, so the gate cannot loop forever.
