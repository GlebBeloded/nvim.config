## Why
`:PyTypeCheckOn`/`:PyTypeCheckOff` (`lua/gleb/lsp/config/python/typecheck.lua`) stop every basedpyright client but `:edit` only the current buffer, so other Python buffers lose LSP and `:edit` fails (E37) on a modified buffer. Also `lua/gleb/lsp/config/json/init.lua` has a dead lspconfig-style `setup.commands` block using the removed `vim.lsp.buf.range_formatting`.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Re-attach basedpyright for every Python buffer (e.g. `vim.lsp.enable("basedpyright", false)` then `true`) without `:edit`; delete the dead json block. Tests: two Python buffers both re-attach; a modified buffer raises no error.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `lsp`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
