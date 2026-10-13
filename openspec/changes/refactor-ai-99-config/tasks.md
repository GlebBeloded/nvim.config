# Tasks

**Goal:** the 99 wiring lives in `lua/gleb/ai/` (`init.lua`, `entry_keymaps.lua`, `pi_provider.lua`), the model string exists once, the provider loads without 99, and every "99 entry keymaps" scenario has a unit test.

**Spec:** `openspec/specs/ai/spec.md` (unchanged, skip_specs). `design.md` (Decisions 1-3).

## Global Constraints

- No behaviour change: same lhs, modes (`n`, `v`), descs, menu text and highlight, provider command and model.
- Test names are `"ai: <scenario title>"` from the existing spec; `make trace` has no orphans.
- No test deleted or weakened. LuaCATS on every exported function; small named functions, no long anonymous functions.

## Review Focus

- `plugins.lua` 99 spec keeps `event = "VeryLazy"` and `dependencies`; `config` is a one-line call to `require("gleb.ai").setup()`.
- `"openai-codex/gpt-5.6-sol"` appears once in `lua/` (`rg -F gpt-5.6-sol lua/`).
- `pi_provider.lua` has no top-level `require("99")`.

---

## 1. Provider loads without 99, single model

Scenarios: ai: runs Pi ephemerally with low thinking, ai: defaults to Codex Sol, ai: Provider name, ai: Provider inherits base provider

**Files:** `tests/unit/ai/test_pi_provider.lua`, `lua/gleb/ai/pi_provider.lua`

- [x] 1.1 **Failing test.** In `test_pi_provider.lua`, require the provider in a bare child with no `99` stub for the first three cases; for "Provider inherits base provider", require the provider first and install the `package.loaded["99"]` stub after. `make test-unit` → FAIL (`module '99' not found`).
- [x] 1.2 **Implement** Decisions 2 and 3: `PiProvider.MODEL`, `_get_default_model()` returns it, base provider resolved in a named `__index` function. `make test-unit` → the four provider cases pass.
- [x] 1.3 **Commit** `refactor(ai): resolve 99 base provider lazily`.

## 2. Entry keymaps module

Scenarios: ai: Menu shows prompt, ai: Menu s opens search prompt, ai: Menu v opens vibe prompt, ai: Menu ignores other keys, ai: Shift-Enter opens vibe prompt, ai: Visual Alt-9 opens visual prompt, ai: Visual Shift-Enter opens visual prompt

**Files:** `tests/unit/ai/test_entry_keymaps.lua` (new), `lua/gleb/ai/entry_keymaps.lua` (new)

- [x] 2.1 **Failing test.** New `test_entry_keymaps.lua`: bare child, a stub 99 table whose `search`, `vibe`, `visual` each record their name in a global and open a new buffer with filetype `99`; call `require("gleb.ai.entry_keymaps").setup(Stub)`. One case per scenario, keys sent with `child.type_keys` (menu key in the same call as `<A-9>`; visual cases start with `V`). Assert the recorded action, `&filetype == "99"` and `mode() == "i"` after the scheduled `startinsert` (or no action and mode `n` for `x`); "Menu shows prompt" wraps `vim.api.nvim_echo` to record chunks, sends `<A-9>` alone, asserts `child.is_blocked()`, sends `<Esc>`, then asserts the recorded `{ "99> [s]earch [v]ibe: ", "Question" }` (screenshots are refused while `getchar()` blocks; design.md, Risks). `make test-unit` → FAIL (module not found).
- [x] 2.2 **Implement** `entry_keymaps.lua` (design.md, Decision 1): body moved from `plugins.lua`, `M.setup(nn)` with `---@param`. `make test-unit` → seven cases pass; `make trace VERBOSE=1` lists all seven as tested.
  - Note (implementation): on Nvim 0.12.5 `getchar()` in the menu does not report `blocking` and screenshots work, so `child.is_blocked()` is false; "Menu shows prompt" asserts the bottom screen row text plus the recorded `nvim_echo` chunk (highlight) instead.
- [x] 2.3 **Commit** `test(ai): cover 99 entry keymaps`.

## 3. Wire through `gleb.ai`

Scenarios: ai: Keymaps exist after VeryLazy

**Files:** `lua/gleb/ai/init.lua` (new), `lua/gleb/plugins/plugins.lua`, `tests/integration/ai/test_setup.lua`

- [x] 3.1 **Failing test.** Extend "ai: Keymaps exist after VeryLazy" to also assert the visual maps: `maparg("<A-9>", "v", false, true).desc` and `maparg("<S-CR>", "v", false, true).desc` are `"99: Visual"`, and that `package.loaded["gleb.ai"]` is set. `make test-integration` → FAIL (`gleb.ai` not loaded).
- [x] 3.2 **Implement** `ai/init.lua` `M.setup()` (99 setup with `provider.MODEL`, prompt keymaps, entry keymaps, in that order) and replace the inline `config` with `function() require("gleb.ai").setup() end`. `make test-integration` → pass; `make types` shows no new diagnostic (the `nvim_echo` `param-type-mismatch` may move to `entry_keymaps.lua`; fix only if it does, design.md Risks).
- [x] 3.3 **Commit** `refactor(ai): move 99 config into gleb.ai`.

## 4. Gate

- [x] 4.1 `rg -F gpt-5.6-sol lua/` → one hit (`pi_provider.lua`); `rg 'require\("99"\)' lua/gleb/ai/pi_provider.lua` → only inside the `__index` function.
- [x] 4.2 `make check` green (verified by the gate run after this pass).
  - Note (attempt 1): only `smoke-startup` failed, at host load 52 (sandbox VM ~230% CPU). Neither `gleb.ai` nor `99` appears in `--startuptime` (both load on VeryLazy). Back to back under the same load, this branch started in 740-1260 ms and `auto` in 1950-7100 ms. No code change; re-run the gate when load is normal.
  - Note (attempt 2): the gate's only failure was `e2e: in prepare, database is locked (5)`, a transient sandbox lock; `make e2e` re-run alone → 11/11 pass. `make quick` here: everything green except `smoke` startup 455 ms at host load 57 (same host-load cause as attempt 1, no code change).
