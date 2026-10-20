## 1. Changes panel tabs
Scenarios: `git: Changes tabs show Local and Branch on a feature branch`, `git: Changes tabs show only Local on the default branch`, `git: Changes tab colours`, `git: Local tab matches the approved render`
- [x] 1.1 Update `tests/screen/git/test_changes_tabs.lua` for the Comments pill and write the missing assertions in `tests/integration/git/test_changes_tabs.lua`; run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="git: Local tab matches the approved render"` and see it fail
- [x] 1.2 Append the `comments` descriptor to `lua/gleb/git/changes/tabs.lua`, add `ChangesTabComments`, and redraw the winbar on `GlebPrThreads`
- [x] 1.3 Run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="git: Local tab matches the approved render"` and `make test FILE=tests/integration/git/test_changes_tabs.lua` and see them pass

## 2. Branch tab render
Scenarios: `git: Branch tab lists the branch files`, `git: Branch tab header without a pull request`, `git: Branch tab colours committed files`, `git: Branch summary wording`, `git: Branch tab matches the approved render`
- [x] 2.1 Update the Branch reference assertion in `tests/screen/git/test_changes_tabs.lua`; run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="git: Branch tab matches the approved render"` and see it fail on the missing Comments pill
- [x] 2.2 Make the shared tab renderer append Comments without changing Branch rows, colours, summary or diff ownership
- [x] 2.3 Run `make test FILE=tests/screen/git/test_changes_tabs.lua CASE="git: Branch tab matches the approved render"` and the Branch cases in `tests/integration/git/test_changes_tabs.lua` and see them pass

## Agent decisions

- Task 2 needed no further code edit because Task 1's shared renderer and approved-text helper already covered the Branch render; preserve that working implementation and verify the complete Branch scenario set.

## 3. Comments tab actions and cycle
Scenarios: `pr: Comments tab follows Branch with a pull request`, `pr: Cmd+G cycles Local, Branch, Comments, then closes`, `pr: Show Pull Request Comments opens the Comments tab`, `pr: Show Pull Request Comments without a pull request`
- [ ] 3.1 Write the scenarios in `tests/integration/pr/test_comments_tab.lua` on fresh `billing-branch` copies with the `pr482` responses and drive `changes.review` or `changes.show_comments`; run the file and see them fail
- [ ] 3.2 Let a Comments descriptor own the editor window and add `changes.show_comments` to the action catalog without a key
- [ ] 3.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua` and see these scenarios pass

## 4. Comments tab rows
Scenarios: `pr: Comments tab lists the threads by file`, `pr: Comments tab row colours`, `pr: Comments tab folds a file`, `pr: Comments tab shows a fetch failure`, `pr: Comments tab matches the approved render`
- [ ] 4.1 Write the integration and screen scenarios in `tests/integration/pr/test_comments_tab.lua` and `tests/screen/pr/test_comments.lua`, using the real Comments tab, `pr482` responses and panel fold action; run them and see them fail
- [ ] 4.2 Add `lua/gleb/pr/comments_tab.lua` on `lua/gleb/ui/tree/` with the Branch header, counts, ordering, loading and failure rows from design.md Decision 2
- [ ] 4.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua` and `make test FILE=tests/screen/pr/test_comments.lua CASE="pr: Comments tab matches the approved render"` and see them pass

## 5. Comments selection
Scenarios: `pr: Selecting a thread shows its line`, `pr: Selecting an unmapped thread shows its diff hunk`
- [ ] 5.1 Write the scenarios in `tests/integration/pr/test_comments_tab.lua`, moving the real panel cursor onto populated thread rows; run the file and see them fail
- [ ] 5.2 Implement the debounced file preview and read-only `gleb-pr://hunk/<thread id>` buffer from design.md Decision 3
- [ ] 5.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua` and see them pass

## 6. Comments Enter
Scenarios: `pr: Enter on a thread opens its line`
- [ ] 6.1 Write the scenario in `tests/integration/pr/test_comments_tab.lua`, press `<CR>` on the real `:22` row, and see it fail
- [ ] 6.2 Add the Comments-row branch of `changes.open` that focuses the editor while preserving the panel
- [ ] 6.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua CASE="pr: Enter on a thread opens its line"` and see it pass

## 7. Peek text
Scenarios: `pr: Peek text is cut at a word boundary`, `pr: Resolved thread matches the approved render`
- [ ] 7.1 Write the truncate table in `tests/unit/pr/test_peek.lua` and the render assertion in `tests/screen/pr/test_comments.lua`; run both scenarios and see them fail
- [ ] 7.2 Add `peek.truncate` from design.md Decision 5 using display widths and first-line word-boundary cutting
- [ ] 7.3 Run `make test FILE=tests/unit/pr/test_peek.lua CASE="pr: Peek text is cut at a word boundary"` and `make test FILE=tests/screen/pr/test_comments.lua CASE="pr: Resolved thread matches the approved render"` and see them pass

## 8. Collapsed and expanded editor peeks
Scenarios: `pr: Open threads peek as one line`, `pr: Peek expands at the cursor line`, `pr: Resolved threads fold to one grey line`, `pr: Outdated threads are hidden in code`, `pr: Peeks follow the threads`
- [ ] 8.1 Write the scenarios in `tests/integration/pr/test_peek.lua`, reading real `gleb_pr_peek` extmarks with `details = true` and stubbing `require("gleb.pr").now`; run the file and see them fail
- [ ] 8.2 Add `lua/gleb/pr/peek.lua` with collapsed, resolved and expanded lines, the `gleb_pr_peek` augroup and window scoping from design.md Decision 4
- [ ] 8.3 Run `make test FILE=tests/integration/pr/test_peek.lua` and see these scenarios pass

## 9. Editor peek screen
Scenarios: `pr: Editor peeks match the approved render`
- [ ] 9.1 Write the real Comments-to-editor screen flow in `tests/screen/pr/test_comments.lua`; run `make test FILE=tests/screen/pr/test_comments.lua CASE="pr: Editor peeks match the approved render"` and see it fail
- [ ] 9.2 Match the extmark text, placement and highlights to design.md's approved peek render
- [ ] 9.3 Run `make test FILE=tests/screen/pr/test_comments.lua CASE="pr: Editor peeks match the approved render"` and see it pass

## 10. Diff view peeks
Scenarios: `pr: Diff view peeks keep the panes aligned`, `pr: Local diff peeks once`
- [ ] 10.1 Write the scenarios in `tests/integration/pr/test_peek.lua` against real Local and Branch diff views and compare `vim.fn.screenpos` for their last lines; run them and see them fail
- [ ] 10.2 Add the decoration-provider list to `lua/gleb/diff/view/`, register the PR provider, and pad the aligned left row from design.md Decision 6
- [ ] 10.3 Run `make test FILE=tests/integration/pr/test_peek.lua` and `make test CAPS=diff` and see them pass

## 11. Thread navigation
Scenarios: `pr: pr.next_thread visits the open threads`, `pr: pr.prev_thread goes back`, `pr: Thread actions are unbound Find Action entries`
- [ ] 11.1 Write the scenarios in `tests/integration/pr/test_peek.lua`, invoking the real action catalog against populated `pr482` files; run the file and see them fail
- [ ] 11.2 Add `pr.next_thread` and `pr.prev_thread` to `lua/gleb/pr/actions.lua` without keys
- [ ] 11.3 Run `make test FILE=tests/integration/pr/test_peek.lua` and see these scenarios pass

## 12. Statusline component
Scenarios: `statusline: Statusline shows the pull request and its open threads`, `statusline: Statusline shows the number before the threads load`, `statusline: Statusline hides the pull request component without a PR`, `statusline: Statusline pull request component runs nothing on redraw`
- [ ] 12.1 Write the scenarios in `tests/integration/statusline/test_pr.lua` against the real lualine component and `pr482` cache states; run the file and see them fail
- [ ] 12.2 Add `lua/gleb/pr/statusline.lua` from design.md Decision 7 and put its cache-only component in `lualine_b` between branch and diff
- [ ] 12.3 Run `make test FILE=tests/integration/statusline/test_pr.lua` and `make test CAPS=statusline` and see them pass

## 13. Statusline colours and screen
Scenarios: `statusline: Statusline pull request colours`, `statusline: Statusline with a pull request matches the approved render`
- [ ] 13.1 Write the highlight assertion in `tests/integration/statusline/test_pr.lua` and the real screen case in `tests/screen/statusline/test_pr.lua`; run both and see them fail
- [ ] 13.2 Add `PrStatuslineNumber` and `PrStatuslineThreads` to `lua/gleb/pr/highlights.lua` and match design.md's statusline render
- [ ] 13.3 Run `make test FILE=tests/integration/statusline/test_pr.lua CASE="statusline: Statusline pull request colours"` and `make test FILE=tests/screen/statusline/test_pr.lua CASE="statusline: Statusline with a pull request matches the approved render"` and see them pass

## 14. Review highlight colours
Scenarios: `pr: Review highlight colours`
- [ ] 14.1 Write the scenario in `tests/integration/pr/test_comments_tab.lua` with `H.expect_hl_colors`; run `make test FILE=tests/integration/pr/test_comments_tab.lua CASE="pr: Review highlight colours"` and see it fail
- [ ] 14.2 Add the remaining palette-backed groups and `gleb_pr_highlights` ColorScheme autocmd to `lua/gleb/pr/highlights.lua`
- [ ] 14.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua CASE="pr: Review highlight colours"` and see it pass

## 15. Full planning gate
Scenarios: `statusline: Statusline with a pull request matches the approved render`
- [ ] 15.1 Run `make render CASE=pr-comments`, compare it with `make colorize FILE=openspec/changes/pr-comments-view/design.md`, and record the mismatch as the failing visual evidence
- [ ] 15.2 Add the `pr-comments` render case to `tests/render/cases.lua` and fix any integrated render differences without changing the approved design
- [ ] 15.3 Run `make check` and see it pass
