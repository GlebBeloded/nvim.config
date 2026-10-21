## 1. Reproduce the three issues

Scenarios: `diff: Diff view draws a committed spec in purple`, `diff: Diff view show starts on the first change`, `git: Changes Branch diff starts on the first change`, `git: Branch diff right pane is the working file`, `git: Commit diff is read-only and navigable`

- [x] 1.1 Write the five scenarios above (`tests/integration/diff/test_committed.lua`, `tests/integration/diff/test_view.lua`, new `tests/integration/git/test_changes_diff_interaction.lua` on a fresh `billing-branch` copy with the fake `gh` reporting PR 482), typing the real keys with `child.type_keys`; run each with `make test FILE=… CASE=…` and see it fail as in proposal.md `## Evidence`: `DiffViewCommitted` extmarks (purple), right and left cursors on line 1 instead of 9/10, a `nofile` unnamed right buffer with `modifiable` off, no Tree-sitter highlighter on the commit diff's right buffer
- [x] 1.2 Record in proposal.md `## Evidence` any result that differs from the repro before going on

## 2. Committed layer in kind colours

Scenarios: `diff: Diff view draws a committed spec in purple`, `diff: Diff view committed colours`, `diff: Diff view without committed keeps its kind colours`, `diff: Diff view committed spec keeps a given buffer editable`, `diff: Diff view committed read-only side has syntax`

- [x] 2.1 Update the three existing scenarios in `tests/integration/diff/test_committed.lua` to the new bodies (keep their names) and add the two new ones; run `make test FILE=tests/integration/diff/test_committed.lua` and see them fail
- [x] 2.2 In `lua/gleb/diff/view/render.lua` drop the `Committed` suffix, arrow kind and word group (kind groups for every spec) while a committed spec still leaves the checkbox cell blank; delete the four `DiffViewCommitted*` definitions in `lua/gleb/diff/view/highlights.lua`; keep `committed` on the view as "not actionable" (design.md Decisions 2 and 3)
- [x] 2.3 Start Tree-sitter for `spec.filetype` on a read-only right buffer (`lua/gleb/diff/view/init.lua` `readonly_buffer` or `windows.lua`), as `left_buffer` does (Decision 5)
- [x] 2.4 Run `make test FILE=tests/integration/diff/test_committed.lua` and `tests/integration/diff/` and see them pass

## 3. Cursor on the first change

Scenarios: `diff: Diff view show starts on the first change`, `diff: Diff view shows in a given window without focus`, `git: Changes Local diff starts on the first change`, `git: Changes Branch diff starts on the first change`, `git: Changes commit diff starts on the first change`, `git: Changes ]f starts the next file on its first change`

- [x] 3.1 Write the scenarios (diff ones in `tests/integration/diff/test_view.lua`, git ones in `tests/integration/git/test_changes_diff_interaction.lua`) and see the new ones fail
- [x] 3.2 In `lua/gleb/diff/view/init.lua` `show`, place the right cursor on the first change as `navigate` would and the left on `layout.transfer_line`, without changing the current window (Decision 4); share the placement with `open`
- [x] 3.3 Run the two test files and `tests/integration/git/test_changes_diff.lua` and see them pass

## 4. Branch diffs on the working-tree buffer

Scenarios: `git: Branch tab shows the merge-base diff`, `git: Branch tab shows a commit's diff`, `git: Branch tab shows an added file`, `git: Branch tab ]f steps through the branch files`, `git: Branch tab Enter opens the working file`, `git: Branch tab ignores staging keys`, `git: Branch diff right pane is the working file`, `git: Branch diff edits are saved and re-diffed`

- [x] 4.1 Update the Branch tab diff scenarios in `tests/integration/git/test_changes_tabs.lua` to the new bodies (keep their names) and write the two new ones in `tests/integration/git/test_changes_diff_interaction.lua`; see them fail
- [x] 4.2 In `lua/gleb/git/changes/git.lua` build a Branch file spec from the merge-base text and the working-tree file loaded as `load_diff` loads it (return the loaded buffer; deleted or binary as read-only lines), right label `Your version`, `committed = true`, not actionable; commit rows keep `<commit>^` → `<commit>` lines (Decision 1)
- [x] 4.3 In `lua/gleb/git/changes/view.lua` record a Branch-loaded buffer in `loaded_buffers` like a Local one and keep `diff_target` reusing the owned view
- [x] 4.4 Run `tests/integration/git/test_changes_tabs.lua` and `tests/integration/git/test_changes_diff_interaction.lua` and see them pass

## 5. Moving and editing in the panes

Scenarios: `git: Window keys enter the diff panes`, `git: Branch diff panes move together`, `git: Commit diff is read-only and navigable`

- [x] 5.1 Write the scenarios in `tests/integration/git/test_changes_diff_interaction.lua` with `child.type_keys`, waiting for each key's effect, and see any that fail
- [x] 5.2 Fix whatever the tests show (focus, sync or read-only handling) without new panel keys (Decision 7)
- [x] 5.3 Run `make test FILE=tests/integration/git/test_changes_diff_interaction.lua` and see it pass

## 6. Jump to Source

Scenarios: `diff: Diff view gf opens the file at the cursor line`, `diff: Diff view gf on a read-only right side`, `git: gf in a commit diff opens the working file`

- [x] 6.1 Write the diff scenarios in `tests/integration/diff/test_view_keys.lua` and the git one in `tests/integration/git/test_changes_diff_interaction.lua`; see them fail
- [x] 6.2 Add `diff.jump_to_source` (`Jump to Source`, `Git | Diff`, plugin `gleb-diff`) to `lua/gleb/diff/actions.lua` and `"diff.jump_to_source": ["gf"]` to `settings/keymap.json`; close a panel-owned view through the panel so its diff state clears, then edit `spec.path` in the right side's window at the mapped, clamped line and focus it (Decision 6)
- [x] 6.3 Run the test files and `tests/integration/diff/test_view_keys.lua` ("Diff view mappings come from diff actions") and see them pass

## 7. Approved renders

Scenarios: `git: Branch tab matches the approved render`, `git: Branch commits match the approved render`

- [ ] 7.1 Update `tests/screen/git/test_changes_tabs.lua`: columns 37-100 of rows 2-29 compare with design.md "Proposed — Branch diff in kind colours" and "Proposed — commit diff in kind colours" (text and mask), columns 1-36 keep git-changes-tabs' panel masks; run it and see it fail
- [ ] 7.2 Run it after tasks 2-4 and see it pass; compare `make render CASE=changes-branch COLUMNS=100 LINES=30` with `make colorize FILE=openspec/changes/fix-changes-diff-interaction/design.md` and move `renders/` out of the repo root

## 8. Real terminal

Scenarios: `git: Real key presses move, scroll and edit in the Branch diff`

- [ ] 8.1 Write the scenario in `tests/e2e/git/` (real key presses through Alacritty and zellij, as the existing git e2e cases do) and see it fail on the current code; if it passes before the fix, record what differs from the user's report under `## Agent decisions`
- [ ] 8.2 Run `make e2e` (sandbox VM only) after tasks 2-4 and see it pass

## Agent decisions

- Detect a Branch working-tree binary with `git diff --numstat <merge-base> -- <path>`, so the read-only fallback covers both committed and uncommitted content.
- Clamp `layout.transfer_line` to the peer's line count, so synchronization and callers agree at an unequal-length file's end.
- Match a diff view against the Changes panels to select panel-owned teardown, so the action clears panel state without coupling the diff view to its owner.
