## Why
fix-neotree-toggle-race (72d06cd) made `smart_toggle_neotree` (`rg -n after_pending_filesystem_render lua/gleb/keymaps.lua`) wait for 120 ms with no filesystem AFTER_RENDER (beating neo-tree's 100 ms navigate debounce) and `_ready ~= false` (a private field), with a 5 s fallback. Every Alt-e / Alt-G from a focused filesystem tree now waits at least 120 ms even when nothing is pending, and the build deleted its own red regression test for the trailing-navigation case (a file-watcher refresh that queues another navigation after the first render), so that race is untested.

Kind: bug
Adopt: loop/fix-neotree-toggle-event-based

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

## Rejected run
Run on `loop/fix-neotree-toggle-event-based` was rejected by the judge:
- review: test weakened
- blocked: tasks.md: ## Blocked

- Probe output: the added stale-guard regression failed on the original code (`false`, expected `true`); after each fix attempt it passed, while `Toggle wins over trailing filesystem navigation` failed at line 741 (`false`, expected `true`).
- Attempt 1: clear the guard after one event-loop turn without a newer filesystem render. This released stale guards but cleared before the held trailing navigation rendered.
- Attempt 2: inspect neo-tree's pinned private debounce entry and clear when `filesystem_navigate.fn` was empty. The debounce entry was already empty before the held trailing render completed, so the guard again cleared too early.
- review findings:
  [must-fix] lua/gleb/keymaps.lua:67-92: the AFTER_RENDER guard is never unsubscribed except at the next smart_toggle_neotree call (line 95). It keeps re-applying the old toggle on every later filesystem render. Example: <A-G> from filesystem leaves the guard (source=git_status) active; when the user later opens filesystem through `:Neotree filesystem`, the source selector or `:Neotree reveal`, the next filesystem AFTER_RENDER runs `Neotree git_status` and forces the user back. After <A-e> closes the tree, the next filesystem open closes it again. This violates the proposal's "act after it completes" and the keymaps requirement that a toggle opens or focuses its source. tasks.md:13-17 ("## Blocked") confirms the stale guard is a known unresolved problem: both attempts to clear it failed.
  [must-fix] tasks.md:15 says a "stale-guard regression" test was added and failed on the original code, but no such test is in the diff (tests/integration/keymaps/test_keymaps.lua). A red regression test was dropped during the build, which is the pattern the proposal set out to stop. Restore it, with a scenario in specs/keymaps/spec.md, once the guard is bounded.
  [minor] lua/gleb/keymaps.lua:67: `guarded_filesystem_toggle` has no LuaCATS annotation (e.g. `---@type neotree.Subscription?`), unlike its neighbours (CLAUDE.md typed code).
  [minor] openspec/changes/fix-neotree-toggle-event-based/tasks.md:13-17: the "## Blocked" notes are left in tasks.md while every task is checked [x], so they contrad
