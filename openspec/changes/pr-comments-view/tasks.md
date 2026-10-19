## 1. Highlight groups
Scenarios: `pr: Review highlight colours`, `statusline: Statusline pull request colours`
- [ ] 1.1 Write the scenarios in `tests/integration/pr/test_comments_tab.lua` and `tests/integration/statusline/test_pr.lua` with `H.expect_hl_colors`, and see them fail
- [ ] 1.2 Add `lua/gleb/pr/highlights.lua` (design.md, Decision 8) with the `gleb_pr_highlights` ColorScheme autocmd
- [ ] 1.3 Run both files and see them pass

## 2. Peek text
Scenarios: `pr: Peek text is cut at a word boundary`
- [ ] 2.1 Write the table in `tests/unit/pr/test_peek.lua` and see it fail
- [ ] 2.2 Add `peek.truncate` (Decision 5) with display widths
- [ ] 2.3 Run `make test FILE=tests/unit/pr/test_peek.lua` and see it pass

## 3. Comments tab
Scenarios: `pr: Comments tab follows Branch with a pull request`, `pr: Cmd+G cycles Local, Branch, Comments, then closes`, `pr: Show Pull Request Comments opens the Comments tab`, `pr: Show Pull Request Comments without a pull request`, `pr: Comments tab lists the threads by file`, `pr: Comments tab row colours`, `pr: Comments tab folds a file`, `pr: Comments tab shows a fetch failure`
- [ ] 3.1 Write the scenarios in `tests/integration/pr/test_comments_tab.lua` on fresh `billing-branch` copies with the `pr482` responses, and see them fail
- [ ] 3.2 Append the `comments` descriptor to `git/changes/tabs.lua` with `editor = "file"` (Decision 1), add `lua/gleb/pr/comments_tab.lua` (Decision 2) on `ui/tree`, and redraw on `GlebPrThreads`
- [ ] 3.3 Add `changes.show_comments` to the changes actions (no key)
- [ ] 3.4 Run the file and see it pass

## 4. Selection and Enter
Scenarios: `pr: Selecting a thread shows its line`, `pr: Selecting an unmapped thread shows its diff hunk`, `pr: Enter on a thread opens its line`
- [ ] 4.1 Write the scenarios in `tests/integration/pr/test_comments_tab.lua` and see them fail
- [ ] 4.2 Implement the debounced preview, the `gleb-pr://hunk/<id>` buffer and the Comments branch of `changes.open` (Decision 3)
- [ ] 4.3 Run the file and see it pass

## 5. Editor peeks
Scenarios: `pr: Open threads peek as one line`, `pr: Peek expands at the cursor line`, `pr: Resolved threads fold to one grey line`, `pr: Outdated threads are hidden in code`, `pr: Peeks follow the threads`
- [ ] 5.1 Write the scenarios in `tests/integration/pr/test_peek.lua`, reading `gleb_pr_peek` extmarks with `details = true`, with `require("gleb.pr").now` stubbed at 2026-01-02T01:00:00Z, and see them fail
- [ ] 5.2 Add `lua/gleb/pr/peek.lua` (Decision 4): collapsed, resolved and expanded lines, the `gleb_pr_peek` augroup, window scoping
- [ ] 5.3 Run the file and see it pass

## 6. Diff view peeks
Scenarios: `pr: Diff view peeks keep the panes aligned`, `pr: Local diff peeks once`
- [ ] 6.1 Write the scenarios in `tests/integration/pr/test_peek.lua`, comparing `vim.fn.screenpos` of the last aligned left and right lines, and see them fail
- [ ] 6.2 Add the decoration provider list to `diff/view` with left padding at the aligned row, and register the PR provider (Decision 6)
- [ ] 6.3 Run the file and `make test CAPS=diff` and see them pass

## 7. Thread navigation
Scenarios: `pr: pr.next_thread visits the open threads`, `pr: pr.prev_thread goes back`, `pr: Thread actions are unbound Find Action entries`
- [ ] 7.1 Write the scenarios in `tests/integration/pr/test_peek.lua` and see them fail
- [ ] 7.2 Add `pr.next_thread` and `pr.prev_thread` to `lua/gleb/pr/actions.lua` (no keys)
- [ ] 7.3 Run the file and see it pass

## 8. Statusline component
Scenarios: `statusline: Statusline shows the pull request and its open threads`, `statusline: Statusline shows the number before the threads load`, `statusline: Statusline hides the pull request component without a PR`, `statusline: Statusline pull request component runs nothing on redraw`
- [ ] 8.1 Write the scenarios in `tests/integration/statusline/test_pr.lua` and see them fail
- [ ] 8.2 Add `lua/gleb/pr/statusline.lua` (Decision 7) and put it in `lualine_b` between `branch` and `diff`
- [ ] 8.3 Run the file and `make test CAPS=statusline` and see them pass

## 9. Screens
Scenarios: `pr: Comments tab matches the approved render`, `pr: Editor peeks match the approved render`, `pr: Resolved thread matches the approved render`, `statusline: Statusline with a pull request matches the approved render`
- [ ] 9.1 Write the screen cases in `tests/screen/pr/test_comments.lua` and `tests/screen/statusline/test_pr.lua` with the captions' size, steps and clock, the colour masks from design.md, and see them fail
- [ ] 9.2 Fix what differs, compare `make render` of a new `pr-comments` case in `tests/render/cases.lua` with `make colorize FILE=openspec/changes/pr-comments-view/design.md`
- [ ] 9.3 Run `make check` and see it pass
