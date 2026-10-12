## 1. Diagnostic maps call vim.diagnostic.jump

Scenarios: "keymaps: Diagnostic jump is not deprecated", "keymaps: ge jumps to next diagnostic", "keymaps: Alt-w jumps to next diagnostic", "keymaps: [d jumps to previous diagnostic"

- [x] 1.1 Failing test: add `T["keymaps: Diagnostic jump is not deprecated"]` to `tests/integration/keymaps/test_keymaps.lua` (after `[d jumps to previous diagnostic`). In the child, replace `vim.deprecate` with a function that appends its first argument to `_G.deprecations`; call `set_diagnostics_on_lines_2_and_4()`, cursor on line 1, `child.type_keys("ge", "<A-w>", "[d")`; assert `child.lua_get("_G.deprecations")` is `{}` and `child.cmd_capture("messages")` has no `deprecated`. Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Diagnostic jump"` and confirm it fails with `vim.diagnostic.goto_next()` recorded.
- [x] 1.2 In `lua/gleb/keymaps.lua`, replace the three diagnostic maps with named `jump_next` / `jump_prev` functions calling `vim.diagnostic.jump({ count = 1 })` / `({ count = -1 })`; `<A-w>` and `ge` map to `jump_next`, `[d` to `jump_prev`; drop the `border` option; LuaCATS annotations.
- [x] 1.0 Sync the change into `openspec/specs/keymaps/spec.md` (trace reads only main specs) and set the Cmd+W *Mapping* cell of `openspec/specs/shortcuts/spec.md` to `` desc `Next diagnostic` `` with that `desc` on `<A-w>` / `ge` (the old `fn vim.diagnostic.goto_next` identity cannot hold for a local function).
- [x] 1.3 `make quick` green: the new case and the three existing jump cases pass unchanged.
- [x] 1.4 `make types` (or `make quick TYPES=1`): no `deprecated` hit left in `lua/gleb/keymaps.lua`. Keep `deprecated` at Information in `.luarc.jsonc` while `lsp/config/python/typecheck.lua:7` still hits (owned by `fix-type-check-baseline`); raise it to Warning only if no hit remains.

## 2. Float after each jump through on_jump

Scenarios: "keymaps: Diagnostic jump opens float"

- [ ] 2.1 Failing test: add `T["keymaps: Diagnostic jump opens float"]` to `tests/integration/keymaps/test_keymaps.lua`. `set_diagnostics_on_lines_2_and_4()`, cursor on line 1, `child.type_keys("ge")`, then `child.wait(...)` (on_jump is scheduled) for a window with `nvim_win_get_config(w).relative ~= ""` whose buffer lines contain `first`; assert the wait returned true. Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Diagnostic jump opens float"` and confirm it fails (task 1's `jump({ count })` opens no float).
- [ ] 2.2 In `lua/gleb/keymaps.lua`, add a named `open_float_on_jump(diagnostic, bufnr)` (LuaCATS: `vim.Diagnostic?`, `integer`) that returns early when `diagnostic` is nil and otherwise calls `vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })`; pass it as `on_jump` in `jump_next` / `jump_prev`. No `float` option.
- [ ] 2.3 `make quick` green: both new cases and the three jump cases pass; "Diagnostic jump is not deprecated" still passes with the float open.
- [ ] 2.4 `make check` green.

