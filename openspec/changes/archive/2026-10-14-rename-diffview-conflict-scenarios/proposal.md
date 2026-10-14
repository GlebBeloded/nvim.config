## Why
After fix-diffview-conflict-keys (03cbc18) the git scenarios and their tests in `tests/integration/git/test_diffview.lua` are still titled "Cmd+O/I/D/A chooses …" although they press diffview's default `<leader>co`/`<leader>ct`/`<leader>cb`/`<leader>ca` (review note, run 1f5fb027).

Kind: bug

## Evidence
- `tests/integration/git/test_diffview.lua:84`, `:89`, `:94`, and `:99` repeat those Cmd titles, while their bodies at `:85`, `:90`, `:95`, and `:100` pass the `<leader>` mappings to `choose()`.

## What Changes
- Rename the four scenarios (git spec, `## RENAMED` or MODIFIED delta as OpenSpec requires) and their test case names together to name the keys pressed; steps and assertions unchanged. `make trace` stays at 0 orphans.
- Out of scope: changing Diffview mappings, conflict-resolution behavior, test bodies, or assertions.

## Capabilities
### Modified Capabilities
- `git`: four scenario titles renamed.

## Impact
- Code: `tests/integration/git/test_diffview.lua` (case names only).
- Plugins: none. Core keymaps: unchanged.
