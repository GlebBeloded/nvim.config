# Design

## Context

See proposal.md - Why. Root cause: the 99 wiring was written inline in the lazy spec, against
`docs/architecture.md` rules 2.2 (plugin config in a `gleb` module) and 1.3 (pure logic without plugin
requires). Consequence beyond the proposal: the seven `ai` scenarios under "99 entry keymaps" have no
test (`make trace` reports them MISSING), because the menu and its keymaps only exist inside the
anonymous `config`. Only "Keymaps exist after VeryLazy" (integration) and the provider and submit-keymap
scenarios (unit, `tests/unit/ai/`) are tested today; the proposal's `tests/ai/*_spec.lua` and plenary
note are stale, tests are already mini.test.

No visible UI change: same keys, descs, menu text (`99> [s]earch [v]ibe: `, `Question`), so no renders.

## Goals / Non-Goals

**Goals:**
- Each part of the 99 wiring is a named module under `lua/gleb/ai/`, loadable in a bare child Neovim.
- The seven "99 entry keymaps" scenarios get unit tests.

**Non-Goals:**
- No spec change (`skip_specs`), so no new scenarios, e.g. no "Missing 99 is tolerated" (rule 6.1).
  lazy.nvim only calls `config` when 99 is installed, so no `pcall` guard is added.
- Rule 3.6 (`x` instead of `v`) and 3.4 (`silent`) are not applied: they would change behaviour in
  select mode / messages, against "no behaviour change".

## Decisions

### 1. Three modules, one job each

| Module | Content |
|---|---|
| `ai/pi_provider.lua` | provider, `PiProvider.MODEL` (the one model string), no top-level `require("99")` |
| `ai/entry_keymaps.lua` (new) | `enter_prompt`, `normal_menu`, `vibe_prompt`, `visual_prompt`, `M.setup(nn)` sets the four keymaps |
| `ai/init.lua` (new) | `M.setup()`: `require("99").setup({ provider, model = provider.MODEL })`, then `prompt_keymaps.setup()`, then `entry_keymaps.setup(nn)` |

The lazy spec becomes `config = function() require("gleb.ai").setup() end`; `event`, `dependencies`
unchanged. `init.lua` keeps the existing order (setup, prompt keymaps, entry keymaps) and only wires
its parts (rule 1.1).

`entry_keymaps.setup(nn)` takes the 99 module as a parameter instead of requiring it, so unit tests pass
a stub table with `search`, `vibe`, `visual` and no plugin on the runtime path (rule 1.3). The menu's
actions table is built from that parameter.

Alternative: one `ai/init.lua` holding everything (proposal's example). Rejected: mixes plugin setup with
pure keymap logic, and rule 1.1 keeps `init.lua` to wiring.

### 2. Model lives on the provider

`PiProvider.MODEL = "openai-codex/gpt-5.6-sol"` (UPPER_SNAKE, rule 4.3); `_get_default_model()` returns
it and `ai.setup` passes it to `nn.setup`. The provider is the only consumer that must know a default
model, so no separate config table. Alternative `ai/config.lua`: a module for one string.

### 3. Lazy base provider

`setmetatable(PiProvider, { __index = inherit_base })` where named `inherit_base(_, key)` returns
`require("99").Providers.BaseProvider[key]`. Lookups only happen when 99 calls provider methods it does
not override, i.e. after 99 is loaded. Alternative: wrap `require("99")` in `pcall` at load. Rejected:
it would silently freeze a `nil` base if the provider were required early.

## Risks / Trade-offs

- [Menu test blocks on `getchar()`] → feed the menu key in the same `type_keys` call (`"<A-9>", "s"`), so
  typeahead satisfies `getchar()`; for "Menu shows prompt", read the command line from
  `child.get_screenshot()` while `getchar()` waits, then send `<Esc>`.
- [`param-type-mismatch` on `nvim_echo` moves with the code] → `make types` decides; annotate the chunk
  list only if the move surfaces it in the new file, else leave out of scope.
- [99 calls a base method by `rawget`] → not the case for `BaseProvider` lookups via `__index`; the
  integration test "Keymaps exist after VeryLazy" runs the real plugin `setup` with the provider.
