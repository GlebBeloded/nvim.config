# Tasks

Layer: unit (`tests/unit/ai/`), using a bare child Neovim. Cases are named exactly
`"<capability>: <scenario title>"`. No plugin dependency, core key, or documentation changes.

## 1. Tolerate a missing 99 module at the wiring boundary

Scenario: `Missing 99 is tolerated`.

- [x] 1.1 Failing mini.test first: create `tests/unit/ai/test_setup.lua` with the case
  `ai: Missing 99 is tolerated`. Start a bare child without 99, call
  `require("gleb.ai").setup()` through `pcall`, and assert that it returns without error and does not
  load the provider or either keymap module. Run
  `make test FILE=tests/unit/ai/test_setup.lua CASE="Missing 99 is tolerated"`; expect failure from
  `require("99")`.
- [x] 1.2 In `lua/gleb/ai/init.lua`, protect only `require("99")` and return early when it is missing.
  Preserve successful setup order and allow errors after 99 loads to propagate.
- [x] 1.3 Run the focused case and `make quick`; both pass. Commit the test and implementation.

## 2. Make every entry mapping silent

Scenario: `Entry mappings are silent`.

- [ ] 2.1 Failing mini.test first: extend `tests/unit/ai/test_entry_keymaps.lua` with the case
  `ai: Entry mappings are silent`. Assert via `maparg(..., false, true)` that `<A-9>` and `<S-CR>`
  are silent in normal and visual modes. Run the focused case; expect all four assertions to fail
  because the option is absent.
- [ ] 2.2 In `lua/gleb/ai/entry_keymaps.lua`, add `silent = true` beside the existing description in
  each of the four declarations; do not introduce an options helper.
- [ ] 2.3 Run the focused case and `make quick`; both pass. Commit the test and implementation.

## 3. Keep entry mappings out of Select mode

Scenario: `Select mode keeps its default behavior`.

- [ ] 3.1 Failing mini.test first: extend `tests/unit/ai/test_entry_keymaps.lua` with the case
  `ai: Select mode keeps its default behavior`. Assert via `maparg(..., false, true)` that neither
  `<A-9>` nor `<S-CR>` has a Select-mode mapping. Run the focused case; expect both assertions to
  fail because the current `v` maps also apply in Select mode.
- [ ] 3.2 In `lua/gleb/ai/entry_keymaps.lua`, change only the two selection mappings from mode `v` to
  `x`; preserve their functions, descriptions, and silent options.
- [ ] 3.3 Run `make test FILE=tests/unit/ai/test_entry_keymaps.lua` to cover the new scenario and every
  existing entry-key behavior, then run `make quick`; both pass. Commit the test and implementation.
