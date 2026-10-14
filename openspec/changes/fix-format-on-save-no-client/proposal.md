## Why
Every manual `:w` in a buffer with no formatting LSP shows `[LSP] Format request failed, no matching language servers.` (`lua/gleb/autocommands.lua`, find with `rg -n 'format' lua/gleb/autocommands.lua`; reproduced headless with a `.txt` file).
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Format on save only when `vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" })` is non-empty, passing `bufnr`; test: saving a `.txt` buffer emits no message; a buffer with a stub formatting client still formats.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- The capability that owns the touched module: a scenario for the fixed behaviour.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
