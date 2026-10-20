## 1. Branch fixture and tab cycle rules

Scenarios: `git: Cycle rules`

- [x] 1.1 Write `git: Cycle rules` in tests/unit/git/test_changes_tabs.lua and run `make test FILE=tests/unit/git/test_changes_tabs.lua CASE="Cycle rules"` to see it fail
- [x] 1.2 Add the `billing-branch` fixture to tests/fixtures/build.sh exactly as design.md Decision 8 (reuse the `billing` file contents; per-commit author and committer dates; `origin/main` and `origin/HEAD` refs; manifest with merge-base, HEAD, commits, Branch and Local files) and verify `git log` shows `e325463`, `07cb52e`, `b5435c5` on `4ccefde`
- [x] 1.3 Add lua/gleb/git/changes/tabs.lua with typed tab descriptors, `first` and `next`
- [x] 1.4 Run `make test FILE=tests/unit/git/test_changes_tabs.lua CASE="Cycle rules"` and see it pass

## 2. Branch summary rules

Scenarios: `git: Branch summary wording`

- [x] 2.1 Write `git: Branch summary wording` in tests/unit/git/test_changes_tabs.lua and run `make test FILE=tests/unit/git/test_changes_tabs.lua CASE="Branch summary wording"` to see it fail
- [x] 2.2 Add the typed pure summary and name-status parsing parts of lua/gleb/git/changes/branch.lua
- [x] 2.3 Run `make test FILE=tests/unit/git/test_changes_tabs.lua CASE="Branch summary wording"` and see it pass

## 3. Commit age rules

Scenarios: `git: Commit ages are short relative times`

- [x] 3.1 Write `git: Commit ages are short relative times` in tests/unit/git/test_changes_tabs.lua and run `make test FILE=tests/unit/git/test_changes_tabs.lua CASE="Commit ages are short relative times"` to see it fail
- [x] 3.2 Add typed `age`, `now` and commit parsing helpers to lua/gleb/git/changes/branch.lua
- [x] 3.3 Run `make test FILE=tests/unit/git/test_changes_tabs.lua CASE="Commit ages are short relative times"` and see it pass

## 4. Committed layer in the diff view

Scenarios: `diff: Diff view draws a committed spec in purple`, `diff: Diff view committed colours`, `diff: Diff view without committed keeps its kind colours`

- [x] 4.1 Write the scenarios in tests/integration/diff/test_committed.lua and run `make test FILE=tests/integration/diff/test_committed.lua` to see them fail
- [x] 4.2 Add `committed?: boolean` to `gleb.diff.view.Spec` and its view state; in lua/gleb/diff/view/render.lua use the `Committed` suffix for added, changed and deleted rows and `DiffViewCommittedWord` for words, keep moved groups and leave the checkbox column blank; define the four palette-derived groups in lua/gleb/diff/view/highlights.lua as design.md Decision 6 requires
- [x] 4.3 Run `make test FILE=tests/integration/diff/test_committed.lua` and tests/integration/diff/ and see them pass

## 5. Tab strip availability and colours

Scenarios: `git: Changes tabs show Local and Branch on a feature branch`, `git: Changes tabs show only Local on the default branch`, `git: Changes tab colours`

- [x] 5.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua and run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [x] 5.2 Build the winbar strip from lua/gleb/git/changes/tabs.lua in lua/gleb/git/changes/view.lua, map its WinBar highlights to `FileTreeNormal`, add the tab groups in lua/gleb/git/changes/highlights.lua and derive Branch availability from `gleb.git.base`
- [x] 5.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 6. Cmd+G tab cycle

Scenarios: `git: Cmd+G cycles Local, Branch, then closes`, `git: First review opens Branch when nothing is uncommitted`, `git: Review on the default branch opens only Local`, `git: Review from the diff window advances the tab`

- [x] 6.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua against the real `changes.review` action, panel and populated `billing-branch` fixture and run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [x] 6.2 Rewrite `review` in lua/gleb/git/changes/init.lua with `first` and `next` as design.md Decision 2 requires
- [x] 6.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 7. Existing review entry behaviour

Scenarios: `git: Changes panel review shows the current file's diff`, `git: Changes panel review without a changed current file`, `git: Changes panel review replaces the dashboard`

- [x] 7.1 Run each named scenario in tests/integration/git/test_changes_diff.lua and see it pass before changing review; after task 6, run each again through the real `changes.review` action and see it pass

## 8. Branch files model and rows

Scenarios: `git: Branch tab lists the branch files`, `git: Branch tab header without a pull request`, `git: Branch tab colours committed files`

- [x] 8.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua against the real Branch tab and populated fixture and run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [x] 8.2 Finish lua/gleb/git/changes/branch.lua with async files and generation guards, shared-tree nodes with the ids of design.md Decision 4, and render the header, summary, purple names and stats in lua/gleb/git/changes/render.lua
- [x] 8.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 9. Branch commit view

Scenarios: `git: c shows the branch commits`, `git: c again shows the branch files`, `git: Expanding a commit lists its files`, `git: Expanding All changes shows every branch file`, `git: c on the Local tab does nothing`

- [x] 9.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua against the real Branch tab and `c` mapping and run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [x] 9.2 Add async commits and per-commit files with generation guards and caching to lua/gleb/git/changes/branch.lua, render commit rows with truncation and ages, add `changes.toggle_commits` to lua/gleb/git/changes/actions.lua and assign `c` in settings/keymap.json
- [x] 9.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 10. Branch hint row

Scenarios: `git: Branch tab hint names the commit view key`, `git: Branch tab hint follows a reassigned key`, `git: Branch tab keeps the last row above the hint`, `git: Local tab has no hint row`

- [ ] 10.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua against the real panel and keymap settings and run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [ ] 10.2 Add lua/gleb/git/changes/hint.lua exactly as design.md Decision 7 requires, including resize handling and two virtual lines above the rule
- [ ] 10.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 11. Branch diff navigation

Scenarios: `git: Branch tab shows the merge-base diff`, `git: Branch tab shows a commit's diff`, `git: Branch tab shows an added file`, `git: Branch tab ]f steps through the branch files`, `git: Branch tab Enter opens the working file`

- [ ] 11.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua against the real picker rows, `<CR>` and `]f`, then run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [ ] 11.2 Add the branch variant of `git.load_diff` in lua/gleb/git/changes/git.lua as design.md Decision 5 requires and route selection, `]f` and `<CR>` by active tab with the labels of Decision 10
- [ ] 11.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 12. Branch staging keys are inert

Scenarios: `git: Branch tab ignores staging keys`

- [x] 12.1 Write `git: Branch tab ignores staging keys` in tests/integration/git/test_changes_tabs.lua against the real Branch tab mappings and run `make test FILE=tests/integration/git/test_changes_tabs.lua CASE="Branch tab ignores staging keys"` to see it fail
- [x] 12.2 Make `<Space>`, `A` and `X` no-ops on the Branch tab
- [x] 12.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua CASE="Branch tab ignores staging keys"` and see it pass

## 13. Branch refresh

Scenarios: `git: Branch tab refreshes after a commit`

- [x] 13.1 Write `git: Branch tab refreshes after a commit` in tests/integration/git/test_changes_tabs.lua and run `make test FILE=tests/integration/git/test_changes_tabs.lua CASE="Branch tab refreshes after a commit"` to see it fail
- [x] 13.2 Refresh the Branch tab with the Local tab's triggers and `gleb.git.base` updates while preserving cursor, fold and view state and dropping stale generations
- [x] 13.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua CASE="Branch tab refreshes after a commit"` and see it pass

## 14. Changes tab actions

Scenarios: `git: Tab actions are in the catalog`, `git: Show Branch Commits opens the commit view`, `git: Show Branch on the default branch`

- [x] 14.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua against the real action catalog and run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [x] 14.2 Add `changes.show_local`, `changes.show_branch` and `changes.show_branch_commits` to lua/gleb/git/changes/actions.lua with no keys and the default-branch WARN behaviour
- [x] 14.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 15. Repository-local tab state

Scenarios: `git: Toggle reopens the last tab`, `git: Review starts the cycle again after a close`

- [x] 15.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua through the real toggle and review actions and run `make test FILE=tests/integration/git/test_changes_tabs.lua` to see them fail
- [x] 15.2 Keep `M.state.by_root` with tab, commit view and folds in lua/gleb/git/changes/init.lua as design.md Decision 9 requires and clear it in `M.reset()`
- [x] 15.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua` and see the scenarios pass

## 16. Existing Local diff behaviour

Scenarios: `git: Changes panel j shows the next file in the diff view`, `git: Changes panel debounces rapid moves`, `git: Changes panel shows an untracked file as added`, `git: Changes panel shows a deleted file`, `git: Changes panel keeps the diff on a directory row`

- [x] 16.1 Run each named scenario in tests/integration/git/test_changes_diff.lua and see it pass before the shared diff-pipeline changes; after task 11, run each again and see it pass

## 17. Existing Local diff generation behaviour

Scenarios: `git: Changes panel drops a stale diff result`, `git: Changes panel skips an unchanged selection`

- [ ] 17.1 Run each named scenario in tests/integration/git/test_changes_diff.lua and see it pass before the shared generation changes; after tasks 11 and 13, run each again and see it pass

## 18. Local tab screen

Scenarios: `git: Local tab matches the approved render`

- [ ] 18.1 Write the scenario in tests/screen/git/test_changes_tabs.lua from design.md "Proposed — Local tab" and run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="Local tab matches the approved render"` to see it fail
- [ ] 18.2 Make the strip and Local panel match the approved text and colour mask
- [ ] 18.3 Run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="Local tab matches the approved render"` and see it pass

## 19. Branch files screen

Scenarios: `git: Branch tab matches the approved render`

- [ ] 19.1 Write the scenario in tests/screen/git/test_changes_tabs.lua from design.md "Proposed — Branch tab, files" and run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="Branch tab matches the approved render"` to see it fail
- [ ] 19.2 Add a `changes-branch` case to tests/render/cases.lua with the `billing-branch` fixture, fake `gh` and stubbed clock and make the Branch files screen match the approved text and colour mask
- [ ] 19.3 Run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="Branch tab matches the approved render"` and compare `make render CASE=changes-branch COLUMNS=100 LINES=30` with renders/branch_files.ansi

## 20. Branch commits screen

Scenarios: `git: Branch commits match the approved render`

- [ ] 20.1 Write the scenario in tests/screen/git/test_changes_tabs.lua from design.md "Proposed — Branch tab, commits" and run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="Branch commits match the approved render"` to see it fail
- [ ] 20.2 Make the Branch commit screen match the approved text and colour mask
- [ ] 20.3 Run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="Branch commits match the approved render"` and see it pass

## 21. Existing Local diff screen

Scenarios: `git: Changes panel with the diff view matches the approved render`

- [ ] 21.1 Point the scenario in tests/screen/git/test_changes_screen.lua at design.md "Proposed — Local only on main" and run `make test FILE=tests/screen/git/test_changes_screen.lua CASE="Changes panel with the diff view matches the approved render"` to see it fail
- [ ] 21.2 Make the Local-only panel and diff match the approved text and colour mask without changing the editor-side diff
- [ ] 21.3 Run `make test FILE=tests/screen/git/test_changes_screen.lua CASE="Changes panel with the diff view matches the approved render"` and see it pass

## 22. Existing Local panel screen

Scenarios: `git: Changes panel matches the approved render`

- [ ] 22.1 Point the scenario in tests/screen/git/test_changes_screen.lua at design.md "Proposed — Local only on main" and run `make test FILE=tests/screen/git/test_changes_screen.lua CASE="Changes panel matches the approved render"` to see it fail
- [ ] 22.2 Make the Local-only panel match the approved text and colour mask
- [ ] 22.3 Run `make test FILE=tests/screen/git/test_changes_screen.lua CASE="Changes panel matches the approved render"` and see it pass

## 23. Bufferline offset over the panel

Scenarios: `bufferline: tabs start after the open project tree`, `bufferline: tabs start after the open changes panel`, `bufferline: tabline over the changes panel matches the approved render`, `bufferline: tabline with tree open matches reference screenshot`, `bufferline: tabline without tree matches reference screenshot`

- [ ] 23.1 Run the five named scenarios in tests/screen/bufferline/test_bufferline_screen.lua and see the existing four pass while `bufferline: tabline over the changes panel matches the approved render` fails against the new panel strip
- [ ] 23.2 Update only the changes-panel reference to use the panel columns of design.md "Proposed — Local only on main"; keep the tabline row and project-tree/no-tree references unchanged
- [ ] 23.3 Run `make test FILE=tests/screen/bufferline/test_bufferline_screen.lua` and see all five scenarios pass

## 24. Real Cmd+G cycle

Scenarios: `git: Real Cmd+G presses cycle the changes tabs`

- [ ] 24.1 Add the scenario to tests/e2e/git/test_changes_review.lua against the populated `billing-branch` fixture and real Cmd+G key events, run it through `make e2e` in the sandbox VM and see it fail
- [ ] 24.2 Complete the real-key cycle wiring without changing the `<A-g>` action assignment
- [ ] 24.3 Run `make e2e` in the sandbox VM and see the scenario pass

## 25. Full verification

Scenarios: `git: Local tab matches the approved render`, `git: Branch tab matches the approved render`, `git: Branch commits match the approved render`, `git: Real Cmd+G presses cycle the changes tabs`

- [ ] 25.1 Run `make test-screen`, run `make e2e` in the sandbox VM, then run `make check`

## Agent decisions

- The fixture manifest uses `branch_files` and `local_files` string arrays, keeping committed and worktree expectations explicit for later scenarios.
- `parse_name_status` returns normalized status names and keeps a rename's source in `orig`, matching the existing changes-row vocabulary for later tree and diff consumers.
- `parse_commits` keeps every parent in an ordered array so later commit diffs can use the first parent without losing merge ancestry.
- The strip counts Branch files with a name-only merge-base diff, so drawing the pill does not load the later Branch row model.
- Branch loading uses `git rev-list --count` alongside the two file commands, because the files view needs summary wording without loading commit details.
- Branch directory nodes use `branch:directory:<path>` IDs, keeping their fold state distinct from the specified `branch:file:<path>` leaf IDs.
- Commit-file caches are panel-local and keyed by full commit hash, so reopening a fold avoids Git while stale callbacks remain generation-guarded.
- Branch actions resolve availability before replacing another sidebar, so unavailable tabs leave the current UI unchanged.
- Repository state is snapshotted in the shared view close path so action, cycle and window closes retain the same tab state.

## Stuck

- Task 10: the Branch hint regression test is red after two production attempts; the saved second attempt is `stuck-attempt-10.diff`.
- Probe: an empty Branch diff retained three structural rows and two trailing `virt_lines`; the multibyte hint was 38 bytes and 35 cells; `VimResized` kept the valid 35-column footer across the layout breakpoint; `:close` invalidated both panel and hint windows.
- Attempt 1: added the panel-relative float, live action-store glyphs, resize/close lifecycle and two virtual lines; the rule rendered one screen row too low and `G` left `tax_test.go` under the float.
- Attempt 2: compensated for the winbar offset and adjusted the panel topline on `CursorMoved`; the naming, reassigned-key and Local-tab scenarios passed, but `G` still left `tax_test.go` hidden because below-EOF virtual lines did not affect its scroll result.
- Task 11: the Branch diff navigation regression tests are red after two production attempts; the saved second attempt is `stuck-attempt-11.diff`.
- Probe: the cause was visible in the existing pipeline, so no headless state probe was needed; isolated real-entry runs showed merge-base, commit and added-file diffs passing, while `]f` recorded `invoice.go` twice and `<CR>` left the panel current with one `gleb-diff` window.
- Attempt 1: added committed `git show` comparisons and tab-qualified diff identity; replacing the Local diff scheduled the panel's orphan check after both editor panes became read-only diff windows, which closed the panel.
- Attempt 2: kept the panel alive while its owned diff windows were valid; committed content scenarios passed in isolation, but `]f` exposed the duplicate initial selection and Branch file rows still routed `<CR>` through fold handling instead of opening the working file.
