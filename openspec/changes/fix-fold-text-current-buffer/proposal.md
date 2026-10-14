## Why
The ufo fold-text handler (`lua/gleb/folding/init.lua`, `folding/go.lua`, `folding/lua.lua`) reads `vim.bo.filetype` and the current buffer's lines; ufo calls it for every visible window, so in a Go | Lua split folds in the other window get the wrong handler and text.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Use the handler's `ctx.bufnr` (6th argument) for filetype and lines; test: a split with a Go and a Lua buffer renders each window's fold text with its own handler.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `folding`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
