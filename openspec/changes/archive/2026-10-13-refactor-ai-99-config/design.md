# Design

## Context

See proposal.md - Why. Root cause: the 99 wiring was written inline in the lazy spec, against
`docs/architecture.md` rules 2.2 (plugin config in a `gleb` module) and 1.3 (pure logic without plugin
requires). Consequence beyond the proposal: the seven `ai` scenarios under "99 entry keymaps" have no
test (`make trace` reports them MISSING), because the menu and its keymaps only exist inside the
anonymous `config`. Only "Keymaps exist after VeryLazy" (integration) and the provider and submit-keymap
scenarios (unit, `tests/unit/ai/`) are tested today; the proposal's `tests/ai/*_spec.lua` and plenary
note are stale, tests are already mini.test.

The previous implementation run completed the refactor on `loop/refactor-ai-99-config`; its three gates
failed only in shared test infrastructure. Current `auto` already contains the sandbox lock and
load-scaled startup budget identified by that run, so applying this change means merging the existing
branch into current `auto`, preserving both the refactor and the newer infrastructure.

No visible UI change: same keys, descs, menu text (`99> [s]earch [v]ibe: `, `Question`), so no renders.

## Goals / Non-Goals

**Goals:**
- Each part of the 99 wiring is a named module under `lua/gleb/ai/`, loadable in a bare child Neovim.
- The seven "99 entry keymaps" scenarios get unit tests.
- Reuse the completed commits from `loop/refactor-ai-99-config` without losing newer `auto` fixes.

**Non-Goals:**
- No spec change (`skip_specs`), so no new scenarios, e.g. no "Missing 99 is tolerated" (rule 6.1).
  lazy.nvim only calls `config` when 99 is installed, so no `pcall` guard is added.
- Rule 3.6 (`x` instead of `v`) and 3.4 (`silent`) are not applied: they would change behaviour in
  select mode / messages, against "no behaviour change".
- The already-shipped shared-sandbox lock and load-scaled timing fixes are not reimplemented here.

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

### 4. Merge the completed branch instead of replaying it

Merge `loop/refactor-ai-99-config` into the current branch. Keep the source branch's AI modules and tests,
and keep current `auto` for unrelated files and the newer sandbox-lock and load-budget infrastructure.
This preserves commit history and avoids reimplementing an already-tested refactor.

Alternative: cherry-pick or manually copy the three implementation commits. Rejected: the request names
the existing branch as the source of truth, and a merge records that relationship while allowing normal
three-way conflict resolution.

## Risks / Trade-offs

- [Menu test blocks on `getchar()`] → feed the menu key in the same `type_keys` call (`"<A-9>", "s"`), so
  typeahead satisfies `getchar()`. For "Menu shows prompt", record `vim.api.nvim_echo` chunks and inspect
  the bottom screen row before sending `<Esc>`.
- [`param-type-mismatch` on `nvim_echo` moves with the code] → `make types` decides; annotate the chunk
  list only if the move surfaces it in the new file, else leave out of scope.
- [99 calls a base method by `rawget`] → the integration test "Keymaps exist after VeryLazy" runs the
  real plugin `setup` with the provider and exercises normal metatable lookup.
- [The source branch predates current `auto`] → resolve merge conflicts by scope: source for the listed AI
  files/tests and change artifacts, current `auto` for unrelated fixes; never delete or weaken a test or
  scenario.

## Migration Plan

Merge the existing branch, resolve only genuine conflicts, run the focused AI tests, then run
`make check E2E=1`. After verification, archive the change through OpenSpec. If verification fails,
retain the unarchived change and branch; rollback is aborting the merge before commit or reverting the
merge commit after it is recorded.
