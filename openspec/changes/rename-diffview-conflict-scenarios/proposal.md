## Why
After fix-diffview-conflict-keys (03cbc18) the git scenarios and their tests in `tests/integration/git/test_diffview.lua` are still titled "Cmd+O/I/D/A chooses …" although they press diffview's default `<leader>co`/`<leader>ct`/`<leader>cb`/`<leader>ca` (review note, run 1f5fb027).

Kind: bug

## Evidence
- `rg -n 'Cmd+[OIDA]' openspec/specs/git/spec.md tests/integration/git/test_diffview.lua`

## What Changes
- Rename the four scenarios (git spec, `## RENAMED` or MODIFIED delta as OpenSpec requires) and their test case names together to name the keys pressed; steps and assertions unchanged. `make trace` stays at 0 orphans.

## Capabilities
### Modified Capabilities
- `git`: four scenario titles renamed.

## Impact
- Code: `tests/integration/git/test_diffview.lua` (case names only), git spec delta.
- Plugins: none. Core keymaps: unchanged.
