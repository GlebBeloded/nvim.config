## Why
`:PyTypeCheckOn`/`:PyTypeCheckOff` (`lua/gleb/lsp/config/python/typecheck.lua`) stop every basedpyright client but `:edit` only the current buffer, so other Python buffers lose LSP and `:edit` fails (E37) on a modified buffer. Also `lua/gleb/lsp/config/json/init.lua` has a dead lspconfig-style `setup.commands` block using the removed `vim.lsp.buf.range_formatting`.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/lsp/config/python/typecheck.lua:5-10` stops every basedpyright client, then runs `:edit`; that command reloads only the current buffer and raises E37 when the buffer is modified.
- `/opt/homebrew/Cellar/neovim/0.12.5_1/share/nvim/runtime/lua/vim/lsp.lua:610-665` documents and implements `vim.lsp.enable(name, false)` as stopping the named clients and `vim.lsp.enable(name, true)` as auto-activating the configuration on all existing matching buffers.
- `lua/gleb/lsp/config/json/init.lua:13-22` contains an unused lspconfig-style `setup.commands` block whose callback calls the removed `vim.lsp.buf.range_formatting` API.

## What Changes
- Re-attach basedpyright for every Python buffer (e.g. `vim.lsp.enable("basedpyright", false)` then `true`) without `:edit`; delete the dead json block. Tests: two Python buffers both re-attach; a modified buffer raises no error.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `lsp`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: `lua/gleb/lsp/config/python/typecheck.lua`, `lua/gleb/lsp/config/json/init.lua`, and `tests/integration/lsp/test_typecheck.lua`.
- Plugins: none added or upgraded.
- Core keymaps: unchanged.
- Out of scope: changing either command's type-checking modes or adding a replacement JSON formatting command.
