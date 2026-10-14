## Why
`lua/gleb/git/diffview.lua` (~34-37) maps conflict keys `<D-o>`/`<D-i>`/`<D-d>`/`<D-a>`, but Alacritty sends no Cmd+O/I/D/A (`terminal/alacritty/keymaps_macos.toml`), so they never fire.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Drop the dead `<D-*>` overrides and keep diffview's default conflict keys (`<leader>co`/`ct`/`cb`/`ca`/`dx` etc. — check diffview's defaults), so conflict resolution works; test the default keys exist in a diffview merge view.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `git`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
