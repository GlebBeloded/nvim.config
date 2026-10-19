## 1. Colours
Scenarios: `pr: Thread window colours`
- [ ] 1.1 Write the scenario in `tests/integration/pr/test_thread_window.lua` with `H.expect_hl_colors`, and see it fail
- [ ] 1.2 Add `PrConfirm`, `PrConfirmHint` and `PrReplyPlaceholder` to `lua/gleb/pr/highlights.lua` (design.md, Decision 6)
- [ ] 1.3 Run the file and see it pass

## 2. Thread window
Scenarios: `pr: Open thread shows the thread centred`, `pr: Open thread without a thread on the line`, `pr: An unmapped thread window shows its diff hunk`, `pr: Enter on a thread opens its line`
- [ ] 2.1 Write the scenarios in `tests/integration/pr/test_thread_window.lua` on fresh `billing-branch` copies with the `pr482` responses and the clock stubbed, and see them fail
- [ ] 2.2 Add `lua/gleb/pr/thread_window.lua` with the layout of Decision 1 (three joined floats, title, commented line with copied captures, comments, placeholder), `pr.open_thread`, and Enter on Comments thread rows (Decision 2)
- [ ] 2.3 Run the file and see it pass

## 3. Keys, hints and drafts
Scenarios: `pr: Enter on an empty reply starts writing`, `pr: gx opens the thread on the web`, `pr: q keeps the draft for the next open`, `pr: Resolved thread offers Unresolve`, `pr: Resolve is hidden without permission`, `pr: Thread window keys come from the shortcut file`
- [ ] 3.1 Write the scenarios in `tests/integration/pr/test_thread_window.lua` and see them fail
- [ ] 3.2 Add the `pr.thread_*` actions and their `settings/keymap.json` entries (Decision 3), the hint row built from the assigned keys, the per-thread drafts and the `WinLeave` close
- [ ] 3.3 Run the file and see it pass

## 4. Reply confirmation and mutation
Scenarios: `pr: Enter asks before sending a reply`, `pr: y sends the reply`, `pr: n keeps editing`, `pr: A failed reply keeps the draft`, `pr: The reply goes to gh as one argument`, `pr: A mutation shows progress and ignores keys`
- [ ] 4.1 Write the scenarios in `tests/integration/pr/test_thread_window.lua` with `AddReply.json`, `AddReply.code` and `AddReply.stderr` in `FAKE_GH_DIR`, and the argv case in `tests/unit/pr/test_gh.lua`, and see them fail
- [ ] 4.2 Implement the confirm states (Decision 4) with the `gleb-pr-confirm` filetype and the `pr.confirm_yes`/`pr.confirm_no` actions, the `AddReply` mutation (Decision 5) and the silent refresh
- [ ] 4.3 Run both files and see them pass

## 5. Resolve confirmation
Scenarios: `pr: R asks before resolving`, `pr: y resolves the thread`, `pr: y unresolves a resolved thread`, `pr: A failed resolve is reported`
- [ ] 5.1 Write the scenarios in `tests/integration/pr/test_thread_window.lua`, switching the served page between calls where a scenario says so, and see them fail
- [ ] 5.2 Implement the resolve questions and the `ResolveThread`/`UnresolveThread` mutations with title updates on `GlebPrThreads`
- [ ] 5.3 Run the file and see it pass

## 6. Screens
Scenarios: `pr: Thread window matches the approved render`, `pr: Send confirmation matches the approved render`
- [ ] 6.1 Write the screen cases in `tests/screen/pr/test_thread_window.lua` with the captions' size, steps and clock and the colour masks from design.md, and see them fail
- [ ] 6.2 Fix what differs; compare `make render` of a `pr-thread` case in `tests/render/cases.lua` with `make colorize FILE=openspec/changes/pr-thread-window/design.md`
- [ ] 6.3 Run `make check` and see it pass
