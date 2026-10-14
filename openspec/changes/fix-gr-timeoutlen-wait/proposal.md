## Why
Global normal `gr` (`lua/gleb/keymaps.lua`, `rg -n '"gr"' lua/gleb/keymaps.lua`) shares a prefix with Neovim 0.12's default `gra`/`gri`/`grn`/`grr`/`grt`/`grx` maps, so `gr` waits the full `timeoutlen` before firing.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Keep `gr` = references (user's existing binding) and remove the conflicting default `gr*` maps after setup (`vim.keymap.del`), so `gr` fires at once; test: no normal-mode mapping other than `gr` starts with `gr`. Keymap meaning unchanged.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `keymaps`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
