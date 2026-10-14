## Why
The neo-tree keymap cases still fail under the full parallel `make check` even on an idle host and with the 10 s load-scaled ceiling from fix-keymaps-async-wait-ceiling, so the cause is not the wait budget. Gate evidence (2026-10-14, plain `make check`, 12 workers):
- `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-G switches tree to git status:` (Left: false, Right: true; `wait_tree_focused("git_status")`)
- `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-e closes focused filesystem tree:` (Left: false, Right: true; `wait_no_tree()`)
Both pass alone. Likely a real race in `smart_toggle_neotree` (`lua/gleb/keymaps.lua`, find with `rg -n smart_toggle_neotree lua`): the key arrives while neo-tree still finishes an async open/reveal/source switch started by `focus_tree`, and that pending work reopens or refocuses the tree after the toggle.

Kind: bug

## Root Cause
To be confirmed by instrumenting (not by stressing the host): record neo-tree events / window+source state around the key press in the failing cases, e.g. log `neo_tree` events and `vim.api.nvim_list_wins()` in the child; reproduce by delaying neo-tree's async render (stub/wrap) in a test, not by loading the machine.

## What Changes
- Fix the race in the config (e.g. make the toggle act on neo-tree's settled state, or have `focus_tree` in the tests wait for neo-tree's render-complete event), whichever the root cause shows; keep every assertion.
- Add a deterministic case that delays neo-tree's async completion and proves the toggle still closes / switches.

## Capabilities
### Modified Capabilities
- `keymaps`: only if the fix needs a new scenario for the delayed-render case.

## Impact
- Code: `lua/gleb/keymaps.lua` (if the race is in the config), `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none. Core keymaps: behaviour unchanged.
