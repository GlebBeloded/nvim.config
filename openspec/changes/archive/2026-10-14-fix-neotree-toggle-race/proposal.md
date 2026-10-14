## Why
The neo-tree keymap cases still fail under the full parallel `make check` even on an idle host and with the 10 s load-scaled ceiling from fix-keymaps-async-wait-ceiling, so the cause is not the wait budget. Gate evidence (2026-10-14, plain `make check`, 12 workers):
- `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-G switches tree to git status:` (Left: false, Right: true; `wait_tree_focused("git_status")`)
- `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-e closes focused filesystem tree:` (Left: false, Right: true; `wait_no_tree()`)
Both pass alone. Likely a real race in `smart_toggle_neotree` (`lua/gleb/keymaps.lua`, find with `rg -n smart_toggle_neotree lua`): the key arrives while neo-tree still finishes an async open/reveal/source switch started by `focus_tree`, and that pending work reopens or refocuses the tree after the toggle.

Kind: bug

## Root Cause
Neo-tree marks the filesystem source visible before all work that can render it has settled. Its filesystem navigation is debounced and file-watcher refreshes can queue another navigation; `focus_tree` returns as soon as the source window is focused. If the toggle closes that window or replaces it with `git_status` before the queued navigation runs, the stale filesystem render opens/focuses the filesystem source again. The existing wait therefore observes an intermediate state, not completion of the operation that can overwrite the toggle.

## What Changes
- Make the smart toggle's close or source-switch result win over a filesystem render that was already pending; keep every assertion.
- Add a deterministic case that delays neo-tree's async completion and proves the toggle still closes / switches.

## Capabilities
### Modified Capabilities
- `keymaps`: define the toggle result while a prior filesystem render is pending.

## Out of Scope
- Changing neo-tree's implementation, debounce interval, or file-watcher configuration.
- Changing core keymaps or the visible tree layout.

## Impact
- Code: `lua/gleb/keymaps.lua`, `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none. Core keymaps: behaviour unchanged.
