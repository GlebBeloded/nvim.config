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
- `changes.show_comments` fetches threads only when the review cache is empty, so focusing an already populated Comments tab does not duplicate the request.
- Task 4 absorbs Tasks 5, 7–9 and 12–14 because its spec-mandated whole-screen render requires real selection, peeks, statusline and highlight behavior; merging them preserves the approved scenario without stand-ins or a weakened assertion.
- The screen tests recreate the design captures' editor state with an in-process language server and the captured golangci-lint warning (gopls and null-ls off): gopls' semantic tokens recolour the code once it loads the module, and real lint runs serialise parallel children on the linter's lock.
- Screen text compares in design notation (`H.design_text`: Nerd Font glyphs become `⎇`, `▸`/`▾` or `◆`), the stand-ins the approved renders use.
- The approved masks were corrected where they contradicted their own capture or later base UI: the `func (i Invoice) Total()` row is ibl's scope-start underline (`@ibl.scope.underline.1`), the cell before the diagnostics is lualine's padding in the error colour (as in the Current render), and the peek render's line-31 sign is git-committed-signs' (f358a315, merged after the capture).
- With a pull request, a focused Changes panel's statusline shows the branch too, as the approved Comments render does: lualine's `branch` finds no repository for `gleb-changes://` buffers, so `pr.statusline.branch` falls back to the base's cached branch.
- A Comments selection `:edit`s only when the editor shows another file: re-reading the shown file restarted ufo's folds and its servers and moved the view.
- `pr.locate` also returns whether its callback will run, and concurrent loads of one source blob share one `git show`: the peeks and callers locate the same file at once, and `git show` runs once per `oid:path`.
- Thread navigation puts the cursor on the line's first non-blank; `pr.prev_thread` before the first thread continues in the previous file at its last thread, mirroring `pr.next_thread`.
- In "Diff view peeks keep the panes aligned", the last lines compared are the left side's last line and its aligned right line, since the branch adds lines past the left side's end.
- Diff view peeks inside a folded unchanged range get their marks and left blanks too, so they show when the fold opens.

## 3. Comments tab actions and cycle
Scenarios: `pr: Comments tab follows Branch with a pull request`, `pr: Cmd+G cycles Local, Branch, Comments, then closes`, `pr: Show Pull Request Comments opens the Comments tab`, `pr: Show Pull Request Comments without a pull request`
- [x] 3.1 Write the scenarios in `tests/integration/pr/test_comments_tab.lua` on fresh `billing-branch` copies with the `pr482` responses and drive `changes.review` or `changes.show_comments`; run the file and see them fail
- [x] 3.2 Let a Comments descriptor own the editor window and add `changes.show_comments` to the action catalog without a key
- [x] 3.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua` and see these scenarios pass

## 4. Comments tab rows and approved render
Scenarios: `pr: Comments tab lists the threads by file`, `pr: Comments tab row colours`, `pr: Comments tab folds a file`, `pr: Comments tab shows a fetch failure`, `pr: Selecting a thread shows its line`, `pr: Selecting an unmapped thread shows its diff hunk`, `pr: Peek text is cut at a word boundary`, `pr: Resolved thread matches the approved render`, `pr: Open threads peek as one line`, `pr: Peek expands at the cursor line`, `pr: Resolved threads fold to one grey line`, `pr: Outdated threads are hidden in code`, `pr: Peeks follow the threads`, `pr: Editor peeks match the approved render`, `statusline: Statusline shows the pull request and its open threads`, `statusline: Statusline shows the number before the threads load`, `statusline: Statusline hides the pull request component without a PR`, `statusline: Statusline pull request component runs nothing on redraw`, `statusline: Statusline pull request colours`, `statusline: Statusline with a pull request matches the approved render`, `pr: Review highlight colours`, `pr: Comments tab matches the approved render`
- [x] 4.1 Write the row, selection, truncate, peek, statusline, highlight and complete approved-screen scenarios in the named integration, unit and screen files, using the real Comments tab, `pr482` responses and panel fold action; run each scenario set and see it fail
- [x] 4.2 Add `lua/gleb/pr/comments_tab.lua` on `lua/gleb/ui/tree/`, then implement the real selection, peek, cache-only statusline and palette-backed highlights from design.md Decisions 2–5, 7 and 8 so the approved screen needs no stand-ins
- [x] 4.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua`, `make test FILE=tests/unit/pr/test_peek.lua`, `make test FILE=tests/integration/pr/test_peek.lua`, `make test FILE=tests/integration/statusline/test_pr.lua`, `make test FILE=tests/screen/pr/test_comments.lua`, and `make test FILE=tests/screen/statusline/test_pr.lua` and see them pass, including the whole text and colour mask of `pr: Comments tab matches the approved render`

## 6. Comments Enter
Scenarios: `pr: Enter on a thread opens its line`
- [x] 6.1 Write the scenario in `tests/integration/pr/test_comments_tab.lua`, press `<CR>` on the real `:22` row, and see it fail
- [x] 6.2 Add the Comments-row branch of `changes.open` that focuses the editor while preserving the panel
- [x] 6.3 Run `make test FILE=tests/integration/pr/test_comments_tab.lua CASE="pr: Enter on a thread opens its line"` and see it pass

## 10. Diff view peeks
Scenarios: `pr: Diff view peeks keep the panes aligned`, `pr: Local diff peeks once`
- [x] 10.1 Write the scenarios in `tests/integration/pr/test_peek.lua` against real Local and Branch diff views and compare `vim.fn.screenpos` for their last lines; run them and see them fail
- [x] 10.2 Add the decoration-provider list to `lua/gleb/diff/view/`, register the PR provider, and pad the aligned left row from design.md Decision 6
- [x] 10.3 Run `make test FILE=tests/integration/pr/test_peek.lua` and `make test CAPS=diff` and see them pass

## 11. Thread navigation
Scenarios: `pr: pr.next_thread visits the open threads`, `pr: pr.prev_thread goes back`, `pr: Thread actions are unbound Find Action entries`
- [x] 11.1 Write the scenarios in `tests/integration/pr/test_peek.lua`, invoking the real action catalog against populated `pr482` files; run the file and see them fail
- [x] 11.2 Add `pr.next_thread` and `pr.prev_thread` to `lua/gleb/pr/actions.lua` without keys
- [x] 11.3 Run `make test FILE=tests/integration/pr/test_peek.lua` and see these scenarios pass

## 15. Full planning gate
Scenarios: `statusline: Statusline with a pull request matches the approved render`
- [ ] 15.1 Run `make render CASE=pr-comments`, compare it with `make colorize FILE=openspec/changes/pr-comments-view/design.md`, and record the mismatch as the failing visual evidence
- [ ] 15.2 Add the `pr-comments` render case to `tests/render/cases.lua` and fix any integrated render differences without changing the approved design
- [ ] 15.3 Run `make check` and see it pass
