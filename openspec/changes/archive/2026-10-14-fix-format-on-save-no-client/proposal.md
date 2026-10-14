## Why
Every manual `:w` in a buffer with no formatting LSP shows `[LSP] Format request failed, no matching language servers.` (`lua/gleb/autocommands.lua`, find with `rg -n 'format' lua/gleb/autocommands.lua`; reproduced headless with a `.txt` file).
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/autocommands.lua:90-96` installs an unconditional `BufWritePre` callback that calls `vim.lsp.buf.format({})` whenever format-on-save is enabled; it does not first check for a client that supports formatting and does not scope the request to the event buffer.
- Headless probe (`nvim --headless <empty-.txt> '+write' '+qa!'`) output: `[LSP] Format request failed, no matching language servers.`

## What Changes
- Format on save only when `vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" })` is non-empty, passing `bufnr`; test: saving a `.txt` buffer emits no message; a buffer with a stub formatting client still formats.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### New Capabilities
- `autocommands`: editor event behaviour, including format-on-save with and without a matching language server.

### Modified Capabilities
- None.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
- Core keymaps: unchanged.
- Out of scope: the `:Format` command, auto-save writes, formatter selection, and formatter configuration.
