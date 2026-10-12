## Context
Root cause (see proposal.md - Why): `do_open_diff` records `state.original_tab` only while it is nil, and `close_all_diffs()` clears only `current_file`. Only `reset()` restores the full state, so after the first close every later preview returns to the first tab, and the `DiffPreviewFocusGuard` `WinEnter` autocmd plus `navigating_until` outlive the diff tab. No visible layout changes: the same diff tab and tree render; only which tab `q` lands on and the post-close state change. No module layout, load order or plugin wiring changes.

## Goals / Non-Goals
Goals: closing a preview leaves the module in the same state as after `reset()`, so the next preview records the tab it starts from.
Non-goals: changing the per-tab reuse of the diff tab while previews are open; the codediff crash (fix-diff-preview-codediff-crash).

## Decisions
- Proposed A (picked): one named local `clear_state()` that clears the focus-guard group and assigns the initial state table; `close_all_diffs()` calls `close_current_diff()` then `clear_state()`, and `reset()` becomes `close_all_diffs()`. One source for the initial state, so `reset()` and close cannot drift again.
- Proposed B: clear `original_tab` inside `close_current_diff()` as well. Rejected: `close_current_diff()` is the "replace tab" primitive; keeping it state-light keeps `do_open_diff`'s reuse path unchanged.
- Proposed C: re-record `original_tab` on every `do_open_diff` when no diff tab is valid. Rejected: still leaves the focus guard and `navigating_until` alive after close, and duplicates the reset logic.
- Assign `M.state` fields in place rather than replacing the table, so callers holding `M.state` (tests, neo-tree mappings) see the reset.

## Risks / Trade-offs
- [Async callback after close: a `do_open_diff` scheduled before `q` finds `current_file` nil and returns] → existing `current_file ~= path` guard already covers it; pending debounce timer is stopped in `clear_state()` too.
- [Async scenarios ("Return clears tab state and focus guard", "Next preview records the new original tab") need a working `open_diff`] → depend on fix-diff-preview-codediff-crash; mark them `H.xfail(CODEDIFF_CRASH, ...)` until it merges, never weaken them.
