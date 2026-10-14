## Why
`lua/gleb/git/diffview.lua` (~34-37) maps conflict keys `<D-o>`/`<D-i>`/`<D-d>`/`<D-a>`, but Alacritty sends no Cmd+O/I/D/A (`terminal/alacritty/keymaps_macos.toml`), so they never fire.
Found by the final audit of auto (2026-10-14).

Kind: bug
Adopt: loop/fix-diffview-conflict-keys

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
## Rejected run
Run on `loop/fix-diffview-conflict-keys` was rejected by the judge:
- blocked: tasks.md: ## Blocked

Probe output: `literal_leader_hit=false`, `actual_leader_hit=false` (the second input followed the unresolved literal input).

- Attempt 1 removed the four `<D-*>` overrides; all four scenarios still failed because `nvim_input()` sent literal `<leader>` notation instead of the configured leader key.
- Attempt 2 expanded `<leader>` before input; all four scenarios errored with `Wrong number of arguments: expecting 1 but got 2` because `string.gsub()` returned both the expanded string and replacement count to the RPC call.

## Unblocked
The Blocked section is a test-harness slip, not a user decision: attempt 2's expansion was right, but `string.gsub()` returns two values, so pass `(s:gsub(...))` (parenthesized) or `vim.keycode`/`nvim_replace_termcodes` output to `nvim_input`. Remove the `## Blocked` section from tasks.md, keep the `<D-*>` removal, and make the four default-key scenarios pass.

- Out of scope: terminal key bindings, Diffview layout and file-panel mappings, whole-file conflict actions, and the pinned Diffview version.
