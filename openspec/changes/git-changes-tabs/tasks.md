## 1. Fixture and pure rules

Scenarios: `git: Cycle rules`, `git: Branch summary wording`, `git: Commit ages are short relative times`

- [ ] 1.1 Write the scenarios in tests/unit/git/test_changes_tabs.lua and see them fail
- [ ] 1.2 Add the `billing-branch` fixture to tests/fixtures/build.sh exactly as design.md Decision 8 (reuse the `billing` file contents; per-commit author and committer dates; `origin/main` and `origin/HEAD` refs; manifest with merge-base, HEAD, commits, Branch and Local files) and check that `git log` shows `e325463`, `07cb52e`, `b5435c5` on `4ccefde`
- [ ] 1.3 Add `lua/gleb/git/changes/tabs.lua` (tab descriptors, `first`, `next`) and the pure parts of `lua/gleb/git/changes/branch.lua` (`summary`, `age`, `now`, commit and name-status parsing), with LuaCATS types
- [ ] 1.4 Run `make test FILE=tests/unit/git/test_changes_tabs.lua` and see it pass

## 2. Committed layer in the diff view

Scenarios: `diff: Diff view draws a committed spec in purple`, `diff: Diff view committed colours`, `diff: Diff view without committed keeps its kind colours`

- [ ] 2.1 Write the scenarios in tests/integration/diff/test_committed.lua and see them fail
- [ ] 2.2 Add `committed?: boolean` to `gleb.diff.view.Spec`/`View`; in `diff/view/render.lua` use the `Committed` suffix for added, changed and deleted rows and `DiffViewCommittedWord` for words, keep moved groups, leave the checkbox column blank; define the four groups in `diff/view/highlights.lua` from the palette (design.md Decision 6)
- [ ] 2.3 Run the file and see it pass, together with tests/integration/diff/ (no existing diff scenario changes)

## 3. Tab strip, cycle and state

Scenarios: `git: Changes tabs show Local and Branch on a feature branch`, `git: Changes tabs show only Local on the default branch`, `git: Changes tab colours`, `git: Cmd+G cycles Local, Branch, then closes`, `git: First review opens Branch when nothing is uncommitted`, `git: Review on the default branch opens only Local`, `git: Review from the diff window advances the tab`, `git: Changes panel review shows the current file's diff`, `git: Changes panel review without a changed current file`, `git: Toggle reopens the last tab`, `git: Review starts the cycle again after a close`

- [ ] 3.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua (fake `gh` and fixture from `git-branch-base`) and see the new ones fail; the two existing review scenarios keep passing
- [ ] 3.2 Build the winbar strip from `tabs.lua` in `git/changes/view.lua` (`winhighlight` `WinBar`/`WinBarNC` → `FileTreeNormal`), add the tab groups to `git/changes/highlights.lua`, and the Branch availability from `gleb.git.base`
- [ ] 3.3 Rewrite `review` in `git/changes/init.lua` with `first`/`next` (design.md Decision 2) and keep `M.state.by_root` (Decision 9); `M.reset()` clears it
- [ ] 3.4 Run the file and tests/integration/git/test_changes.lua and see them pass

## 4. Branch tab files, commits and hint row

Scenarios: `git: Branch tab lists the branch files`, `git: Branch tab header without a pull request`, `git: Branch tab colours committed files`, `git: c shows the branch commits`, `git: c again shows the branch files`, `git: Expanding a commit lists its files`, `git: Expanding All changes shows every branch file`, `git: c on the Local tab does nothing`, `git: Branch tab hint names the commit view key`, `git: Branch tab hint follows a reassigned key`, `git: Branch tab keeps the last row above the hint`, `git: Local tab has no hint row`, `git: Branch tab refreshes after a commit`

- [ ] 4.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua and see them fail
- [ ] 4.2 Finish `branch.lua` (async files, commits and per-commit files with generation guards; `ui/tree` nodes with the ids of design.md Decision 4) and its rows in `git/changes/render.lua` (header, summary, purple names, commit rows with `…` and ages)
- [ ] 4.3 Add `changes.toggle_commits` to `git/changes/actions.lua` and `c` to `settings/keymap.json`
- [ ] 4.4 Add `lua/gleb/git/changes/hint.lua` (design.md Decision 7) and refresh the Branch tab with the Local tab's triggers and `gleb.git.base` updates
- [ ] 4.5 Run the file and see it pass

## 5. Branch diffs and tab actions

Scenarios: `git: Branch tab shows the merge-base diff`, `git: Branch tab shows a commit's diff`, `git: Branch tab shows an added file`, `git: Branch tab ]f steps through the branch files`, `git: Branch tab Enter opens the working file`, `git: Branch tab ignores staging keys`, `git: Tab actions are in the catalog`, `git: Show Branch Commits opens the commit view`, `git: Show Branch on the default branch`

- [ ] 5.1 Write the scenarios in tests/integration/git/test_changes_tabs.lua and see them fail
- [ ] 5.2 Add the branch variant of `git.load_diff` in `git/changes/git.lua` (design.md Decision 5, labels of Decision 10) and route selection, `]f` and `<CR>` by the active tab; make `<Space>`, `A` and `X` no-ops on the Branch tab
- [ ] 5.3 Add `changes.show_local`, `changes.show_branch`, `changes.show_branch_commits` to `git/changes/actions.lua` (no keys) with the WARN on the default branch
- [ ] 5.4 Run the file and see it pass

## 6. Screens and the real-key cycle

Scenarios: `git: Local tab matches the approved render`, `git: Branch tab matches the approved render`, `git: Branch commits match the approved render`, `git: Changes panel with the diff view matches the approved render`, `git: Changes panel matches the approved render`, `git: Real Cmd+G presses cycle the changes tabs`

- [ ] 6.1 Write tests/screen/git/test_changes_tabs.lua from design.md "Proposed — Local tab", "Proposed — Branch tab, files" and "Proposed — Branch tab, commits" (real glyphs where the render has stand-ins, full colour masks), point the two existing panel screen cases at "Proposed — Local only on main", add the e2e Cmd+G cycle on `billing-branch`, and see them fail
- [ ] 6.2 Add a `changes-branch` case to tests/render/cases.lua (Branch tab of `billing-branch`, fake `gh`, stubbed clock)
- [ ] 6.3 Make `make test-screen` and `make e2e` (sandbox VM) pass, then `make check`; compare `make render CASE=changes-branch COLUMNS=100 LINES=30` with `renders/branch_files.ansi`
