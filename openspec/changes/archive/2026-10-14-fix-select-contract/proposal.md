## Why
`vim.ui.select` override (`lua/gleb/select/init.lua`, `rg -n 'opts.kind' lua/gleb/select`) indexes `opts` without a nil check, so `vim.ui.select({"x"}, nil, cb)` raises "attempt to index local 'opts' (a nil value)" (default select accepts nil). The code-action menu (`lua/gleb/select/code_action.lua`) passes no `on_close` to the nui Menu, so `<Esc>` never calls `on_choice(nil, nil)` as the `vim.ui.select` contract requires (rustaceanvim grouped actions wait forever).
Found by the second audit of auto (2026-10-14).

Kind: bug

## Evidence
- A clean headless probe that loads `lua/gleb/select/init.lua` and calls `vim.ui.select({"x"}, nil, callback)` reports `lua/gleb/select/init.lua:7: attempt to index local 'opts' (a nil value)`.
- `lua/gleb/select/init.lua:6` accepts `opts`, then `lua/gleb/select/init.lua:7` reads `opts.kind` without normalizing an omitted value.
- `lua/gleb/select/code_action.lua:68` builds the menu options with only `on_submit`; nui maps close keys through `menu_props.on_close` and invokes the optional menu callback at `/Users/hlebbeladzed/.local/share/nvim/lazy/nui.nvim/lua/nui/menu/init.lua:302` and `/Users/hlebbeladzed/.local/share/nvim/lazy/nui.nvim/lua/nui/menu/init.lua:339`.

## What Changes
- `opts = opts or {}` at the top of the override; nui Menu `on_close` calls `on_choice(nil, nil)` once.
- `select` spec: add a requirement + scenarios for nil `opts` and cancel calling `on_choice(nil, nil)`; tests for both, RED first.

## Capabilities
### Modified Capabilities
- `select`: scenarios for the fixed behaviour.

## Impact
- Code: `lua/gleb/select/init.lua`, `lua/gleb/select/code_action.lua`, and unit tests under `tests/unit/select/`.
- Plugins: none added or upgraded. Core keymaps: unchanged.
- Out of scope: changing picker layout, styling, item formatting, or mappings.
