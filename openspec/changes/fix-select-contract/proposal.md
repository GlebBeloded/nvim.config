## Why
`vim.ui.select` override (`lua/gleb/select/init.lua`, `rg -n 'opts.kind' lua/gleb/select`) indexes `opts` without a nil check, so `vim.ui.select({"x"}, nil, cb)` raises "attempt to index local 'opts' (a nil value)" (default select accepts nil). The code-action menu (`lua/gleb/select/code_action.lua`) passes no `on_close` to the nui Menu, so `<Esc>` never calls `on_choice(nil, nil)` as the `vim.ui.select` contract requires (rustaceanvim grouped actions wait forever).
Found by the second audit of auto (2026-10-14).

Kind: bug

## Evidence
- Confirmed in a headless full-config child by the audit; locate code with `rg -n` (line numbers may drift).

## What Changes
- `opts = opts or {}` at the top of the override; nui Menu `on_close` calls `on_choice(nil, nil)` once.
- `select` spec: add a requirement + scenarios for nil `opts` and cancel calling `on_choice(nil, nil)`; tests for both, RED first.

## Capabilities
### Modified Capabilities
- `select`: scenarios for the fixed behaviour.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded. Core keymaps: unchanged.
