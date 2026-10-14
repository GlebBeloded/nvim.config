## Why
Global normal `gr` (`lua/gleb/keymaps.lua`, `rg -n '"gr"' lua/gleb/keymaps.lua`) shares a prefix with Neovim 0.12's default `gra`/`gri`/`grn`/`grr`/`grt`/`grx` maps, so `gr` waits the full `timeoutlen` before firing.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/keymaps.lua:164` defines the global normal-mode `gr` Telescope references mapping.
- `/opt/homebrew/Cellar/neovim/0.12.5_1/share/nvim/runtime/lua/vim/_core/defaults.lua:204-226` defines Neovim's normal-mode `grn`, `gra`, `grx`, `grr`, `gri`, and `grt` mappings.
- `/opt/homebrew/Cellar/neovim/0.12.5_1/share/nvim/runtime/doc/options.txt:6881-6893` states that a mapped prefix waits `timeoutlen` for a following key; therefore the longer default `gr*` mappings delay the configured `gr` mapping.

## What Changes
- Keep `gr` = references (user's existing binding) and remove the conflicting default `gr*` maps after setup (`vim.keymap.del`), so `gr` fires at once; test: no normal-mode mapping other than `gr` starts with `gr`. Keymap meaning unchanged.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `keymaps`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
- Core keymaps: the configured `gr` meaning is unchanged; Neovim's conflicting default normal-mode `gr*` mappings are removed.
- Out of scope: changing `timeoutlen`, changing `gr`, or replacing the removed default actions with new bindings.
- `file-tree: gr keeps its global meaning in git status tree` still holds because the fix preserves the global `gr` mapping and changes no tree-local mapping.
