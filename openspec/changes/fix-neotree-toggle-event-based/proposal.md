## Why
fix-neotree-toggle-race (72d06cd) made `smart_toggle_neotree` (`rg -n after_pending_filesystem_render lua/gleb/keymaps.lua`) wait for 120 ms with no filesystem AFTER_RENDER (beating neo-tree's 100 ms navigate debounce) and `_ready ~= false` (a private field), with a 5 s fallback. Every Alt-e / Alt-G from a focused filesystem tree now waits at least 120 ms even when nothing is pending, and the build deleted its own red regression test for the trailing-navigation case (a file-watcher refresh that queues another navigation after the first render), so that race is untested.

Kind: bug

## Evidence
- neo-tree `lua/neo-tree/sources/filesystem/init.lua` (~198-203): navigate is debounced CALL_FIRST_AND_LAST, 100 ms.
- run 94bb45e1 fix-1 probe: `state._ready` was already true at keypress while a navigation was still held, so `_ready` is not an in-flight signal.
- neo-tree `lua/neo-tree/utils/init.lua` `tracked_functions` / debounce state may expose whether a navigation is pending.

## What Changes
- Replace the timer with an event/state-based condition: act immediately when no navigation is pending; when one is, act after it completes (or make a stale render unable to reopen a tree the user closed/switched). No fixed sleeps; no private fields unless no public hook exists (then document the neo-tree version it relies on).
- Restore a regression test for the trailing-navigation race (hold the first render, queue a second navigation as a watcher refresh would, press the key, release both) and keep the existing delayed-render case; both must fail on the 72d06cd code path or on base as appropriate (task 1.1 shows the red).
- Alt-e / Alt-G with nothing pending act without added delay; add a case asserting the toggle happens synchronously (same tick) when nothing is pending.

## Capabilities
### Modified Capabilities
- `keymaps`: scenarios for the trailing-navigation case and immediate toggle when idle.

## Impact
- Code: `lua/gleb/keymaps.lua`, `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none. Core keymaps: behaviour as specified (no added latency).
