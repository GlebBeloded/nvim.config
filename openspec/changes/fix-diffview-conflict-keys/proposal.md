## Why
`lua/gleb/git/diffview.lua` (~34-37) maps conflict keys `<D-o>`/`<D-i>`/`<D-d>`/`<D-a>`, but Alacritty sends no Cmd+O/I/D/A (`terminal/alacritty/keymaps_macos.toml`), so they never fire.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/git/diffview.lua:34-37` replaces four conflict actions with `<D-o>`, `<D-i>`, `<D-d>`, and `<D-a>` mappings.
- `terminal/alacritty/keymaps_macos.toml:1-225` defines the Cmd sequences Alacritty emits but has no bindings for Cmd+O/I/D/A, so those Neovim mappings are unreachable from the configured terminal stack.
- `/Users/hlebbeladzed/.local/share/nvim/lazy/diffview.nvim/lua/diffview/config.lua:137-141` provides reachable defaults for the same conflict actions at `<leader>co`, `<leader>ct`, `<leader>cb`, `<leader>ca`, and `dx`.

## What Changes
- Drop the dead `<D-*>` overrides and keep diffview's default conflict keys (`<leader>co`/`ct`/`cb`/`ca`/`dx` etc. — check diffview's defaults), so conflict resolution works; test the default keys exist in a diffview merge view.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `git`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: `lua/gleb/git/diffview.lua` and `tests/integration/git/test_diffview.lua`.
- Core keymaps: conflict choices change from unreachable Cmd overrides to Diffview's default leader mappings; existing `dx` behaviour still holds.
- Architecture: unchanged; plugin wiring, load order, and module layout are untouched.
- Visible UI: unchanged.
- Plugins: none added or upgraded.
- Out of scope: terminal key bindings, Diffview layout and file-panel mappings, whole-file conflict actions, and the pinned Diffview version.
