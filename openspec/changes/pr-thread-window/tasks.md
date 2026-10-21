## 1. Thread window colours
Scenarios: `pr: Thread window colours`
- [x] 1.1 Write the test `pr: Thread window colours` in `tests/integration/pr/test_thread_window.lua` with `H.expect_hl_colors`; run `make test FILE=tests/integration/pr/test_thread_window.lua CASE="Thread window colours"` and see it fail
- [x] 1.2 Add `PrConfirm`, `PrConfirmHint` and `PrReplyPlaceholder` to `lua/gleb/pr/highlights.lua`
- [x] 1.3 Run `make test FILE=tests/integration/pr/test_thread_window.lua CASE="Thread window colours"` and see it pass

## 2. Thread window content and opening
Scenarios: `pr: Open thread shows the thread centred`, `pr: Open thread without a thread on the line`, `pr: An unmapped thread window shows its diff hunk`
- [x] 2.1 Write the three tests in `tests/integration/pr/test_thread_window.lua` using the real `pr.open_thread` action or `<CR>`, the `billing-branch` fixture and populated `pr482` responses; run each with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it fail
- [x] 2.2 Add `lua/gleb/pr/thread_window.lua`, register `pr.open_thread` in `lua/gleb/pr/actions.lua`, and open the mapped thread or its `diffHunk` in the centred joined-float layout
- [x] 2.3 Run each scenario with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it pass

## 3. Comments tab Enter
Scenarios: `pr: Enter on a thread opens its line`, `pr: Enter on an unmapped thread shows its diff hunk`
- [x] 3.1 Tighten the existing cases in `tests/integration/pr/test_comments_tab.lua` to press `<CR>` on populated Comments rows and assert the thread window; run each with `make test FILE=tests/integration/pr/test_comments_tab.lua CASE="<scenario title>"` and see it fail
- [x] 3.2 Change `lua/gleb/pr/comments_tab.lua` so mapped and unmapped thread rows open and focus their thread after preserving the existing editor or `diffHunk` navigation
- [x] 3.3 Run each scenario with `make test FILE=tests/integration/pr/test_comments_tab.lua CASE="<scenario title>"` and see it pass

## 4. Thread keys, hints and drafts
Scenarios: `pr: Enter on an empty reply starts writing`, `pr: gx opens the thread on the web`, `pr: q keeps the draft for the next open`, `pr: Resolved thread offers Unresolve`, `pr: Resolve is hidden without permission`
- [x] 4.1 Write the five tests in `tests/integration/pr/test_thread_window.lua`, driving the real mappings against populated thread data; run each with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it fail
- [x] 4.2 Add the `pr.thread_*` actions, permission-aware hints, per-thread drafts, `vim.ui.open` call and focus-leave close to `lua/gleb/pr/thread_window.lua` and `lua/gleb/pr/actions.lua`
- [x] 4.3 Run each scenario with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it pass

## 5. Thread key ownership
Scenarios: `pr: Thread window keys come from the shortcut file`
- [x] 5.1 Write the test `pr: Thread window keys come from the shortcut file` in `tests/integration/pr/test_thread_window.lua` against the real post-`VeryLazy` mappings; run `make test FILE=tests/integration/pr/test_thread_window.lua CASE="Thread window keys come from the shortcut file"` and see it fail
- [x] 5.2 Add the `pr.thread_*` entries scoped to `gleb-pr-thread` in `settings/keymap.json` and build the hint text from their assigned keys
- [x] 5.3 Run `make test FILE=tests/integration/pr/test_thread_window.lua CASE="Thread window keys come from the shortcut file"` and see it pass

## 6. Reply confirmation
Scenarios: `pr: Enter asks before sending a reply`, `pr: y sends the reply`, `pr: n keeps editing`, `pr: A failed reply keeps the draft`, `pr: The reply goes to gh as one argument`
- [x] 6.1 Write the five tests in `tests/integration/pr/test_thread_window.lua`, driving the real reply area and fake `gh` with populated `AddReply` responses; run each with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it fail
- [x] 6.2 Add the `gleb-pr-confirm` send state, `pr.confirm_yes` and `pr.confirm_no` actions and mappings, call the existing `gh.reply`, silently refresh on success, and preserve the draft on cancellation or failure
- [x] 6.3 Run each scenario with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it pass

## 7. Reply confirmation render
Scenarios: `pr: Send confirmation matches the approved render`
- [ ] 7.1 Write the test `pr: Send confirmation matches the approved render` in `tests/screen/pr/test_thread_window.lua`, driving the real thread window and reply mappings; run `make test FILE=tests/screen/pr/test_thread_window.lua CASE="Send confirmation matches the approved render"` and see it fail
- [ ] 7.2 Match the text and colour mask of design.md's approved `r3_confirm_footer` render
- [ ] 7.3 Run `make test FILE=tests/screen/pr/test_thread_window.lua CASE="Send confirmation matches the approved render"` and see it pass

## 8. Resolve confirmation
Scenarios: `pr: R asks before resolving`, `pr: y resolves the thread`, `pr: y unresolves a resolved thread`, `pr: A failed resolve is reported`
- [x] 8.1 Write the four tests in `tests/integration/pr/test_thread_window.lua`, driving `R` and `y` against populated threads and fake `gh` responses; run each with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it fail
- [x] 8.2 Add the resolve and unresolve confirmation states, call the existing `gh.set_resolved`, silently refresh and update the title on success, and restore normal state on failure
- [x] 8.3 Run each scenario with `make test FILE=tests/integration/pr/test_thread_window.lua CASE="<scenario title>"` and see it pass

## 9. Mutation progress
Scenarios: `pr: A mutation shows progress and ignores keys`
- [x] 9.1 Write the test `pr: A mutation shows progress and ignores keys` in `tests/integration/pr/test_thread_window.lua` with delayed fake `gh`; run `make test FILE=tests/integration/pr/test_thread_window.lua CASE="A mutation shows progress and ignores keys"` and see it fail
- [x] 9.2 Add the running state that draws progress and ignores confirm keys until the mutation callback returns
- [x] 9.3 Run `make test FILE=tests/integration/pr/test_thread_window.lua CASE="A mutation shows progress and ignores keys"` and see it pass

## 10. Thread window render
Scenarios: `pr: Thread window matches the approved render`
- [ ] 10.1 Write the test `pr: Thread window matches the approved render` in `tests/screen/pr/test_thread_window.lua`, driving `<CR>` from the populated Comments tab; run `make test FILE=tests/screen/pr/test_thread_window.lua CASE="Thread window matches the approved render"` and see it fail
- [ ] 10.2 Match the text and colour mask of design.md's approved `r3_thread_center` render
- [ ] 10.3 Run `make test FILE=tests/screen/pr/test_thread_window.lua CASE="Thread window matches the approved render"` and see it pass, then run `make check`

## Agent decisions

- Pass an ephemeral LEFT-side thread copy after unmapped navigation so the existing thread renderer uses its diff-hunk path without changing cached review data.
- Observe delayed mutation progress inside the child because the real mapping keeps MiniTest's RPC channel blocked while `gh` is pending.

## Stuck

- Task 7: `pr: Send confirmation matches the approved render` remains red after two production attempts; the second attempt is saved in `stuck-attempt-7.diff`.
- Probe: empty reply `{ "", "", "" }` had one placeholder extmark; multibyte source rendered `{ "  22 \tif café.税 == nil {" }`; resizing to 60 columns produced message `col=2`, `width=54`, display width 25; `:close` cleared the tab-local window state.
- Attempt 1: added visual inner padding, cleared the stale placeholder, restored the editor statusline, highlighted the confirmation ends and tried a reply-border title; this fixed those cells, but the reply rule was still absent and the editor background remained one row low.
- Attempt 2: gave the reply float a real top border and restored the editor view after opening; the border then overlaid the hint row, its title lacked the approved leading border cell, and the background still remained one row low.
