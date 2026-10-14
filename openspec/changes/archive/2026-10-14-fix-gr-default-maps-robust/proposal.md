## Why
fix-gr-timeoutlen-wait (ff5be24) deletes a hard-coded list of Neovim 0.12 default maps (`grn`, `gra`, `grx`, `grr`, `gri`, `grt`) in `lua/gleb/keymaps.lua` (`rg -n 'keymap.del' lua/gleb/keymaps.lua`). `vim.keymap.del` raises E31 for a missing mapping, so a Neovim that drops or renames one breaks startup, and a newly added default `gr*` map brings the `timeoutlen` wait back (review note, run 8db8c4e2).

Kind: bug

## Evidence
- Review note in run 8db8c4e2 escalation.md.

## What Changes
- Delete every global mapping whose lhs starts with `gr` (other than `gr` itself) found via `vim.api.nvim_get_keymap` for the affected modes, instead of a fixed list; never error when none exist.
- Test: in the child, add a fake global `grz` map before the keymaps module loads (or re-run the cleanup function) and assert it is removed and no error is raised; the existing "no other mapping starts with gr" case keeps passing. Task 1.1 shows the fake `grz` surviving on the current code.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `lua/gleb/keymaps.lua`, keymaps integration test.
- Plugins: none. Core keymaps: unchanged meaning.
- Pinned scenario preserved: `file-tree: gr keeps its global meaning in git status tree` still holds because cleanup excludes the exact global `gr` mapping while removing longer `gr*` mappings.
