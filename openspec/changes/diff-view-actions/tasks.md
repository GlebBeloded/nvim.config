## 1. Index checkbox states

Scenarios: `diff: Diff patch states of a change, an insertion and a deletion`, `diff: Diff patch state of a partly staged change`, `diff: Diff patch computes checkbox states in one pass`

- [x] 1.1 Write the scenarios in `tests/unit/diff/test_patch.lua` against `require("gleb.diff.patch").state` and see them fail
- [x] 1.2 Add the typed, pure state calculation in `lua/gleb/diff/patch.lua`, using one HEAD-to-index comparison for all changes
- [x] 1.3 Run `make test FILE=tests/unit/diff/test_patch.lua` and see them pass

## 2. Index text and patch generation

Scenarios: `diff: Diff patch stages one change`, `diff: Diff patch stages an insertion and a deletion`

- [x] 2.1 Write the scenarios in `tests/unit/diff/test_patch.lua` against `update_index` and `make_patch`, including `git apply --cached --check`, and see them fail
- [x] 2.2 Add typed index mutation and patch serialization to `lua/gleb/diff/patch.lua`
- [x] 2.3 Run `make test FILE=tests/unit/diff/test_patch.lua` and see them pass

## 3. Revert actions

Scenarios: `diff: Diff view do reverts a changed line`, `diff: Diff view dp reverts a deletion from the left window`, `diff: Diff view reverts an insertion as one undo step`, `diff: Diff view revert off a change does nothing`

- [x] 3.1 Write the scenarios in `tests/integration/diff/test_actions.lua`, driving `do` and `dp` in populated `diffgo` views, and see them fail
- [x] 3.2 Add `diff.apply`, reuse `layout.change_at_line`, and map `do` and `dp` through the `gleb-diff` adapter
- [x] 3.3 Run `make test FILE=tests/integration/diff/test_actions.lua` and see them pass

## 4. Revert safeguards

Scenarios: `diff: Diff view actions reject a file absent from HEAD`, `diff: Diff view reverting the last change keeps the view open`

- [x] 4.1 Write the scenarios in `tests/integration/diff/test_actions.lua`, driving the real actions in untracked and one-change views, and see them fail
- [x] 4.2 Reject sources without comparable HEAD text and keep zero-fragment views open without folds
- [x] 4.3 Run `make test FILE=tests/integration/diff/test_actions.lua` and see them pass

## 5. Hunk staging actions

Scenarios: `diff: Diff view Space stages one change`, `diff: Diff view Space unstages a staged change`, `diff: Diff view stages an insertion and a deletion separately`, `diff: Diff view reports a staging failure`, `diff: Diff view refuses staging over other staged lines`

- [x] 5.1 Write the scenarios in `tests/integration/diff/test_actions.lua`, driving `<Space>` in populated `diffgo` views and using the real index lock path, and see them fail
- [x] 5.2 Add `lua/gleb/diff/stage.lua` and `diff.toggle_include`, preserving unrelated index edits and reporting stage or unstage failures
- [x] 5.3 Run `make test FILE=tests/integration/diff/test_actions.lua` and see them pass

## 6. Include checkbox drawing

Scenarios: `diff: Diff view checkboxes follow the index`, `diff: Diff view checkbox of a partly staged change`

- [x] 6.1 Write the scenarios in `tests/integration/diff/test_actions.lua`, opening real `dirty` and `diffgo` data, and see them fail
- [x] 6.2 Thread the default-policy index states through `view/layout.lua` and `view/render.lua`, refreshing after comparisons and toggles
- [x] 6.3 Run `make test FILE=tests/integration/diff/test_actions.lua` and see them pass

## 7. Final-line staging

Scenarios: `diff: Diff view stages a final line without a newline`

- [x] 7.1 Write the scenario in `tests/integration/diff/test_actions.lua`, drive `<Space>` on the populated final-line change with `noeol nofixeol`, and see it fail
- [x] 7.2 Pass the buffer final-newline state to patch generation when staging the final-line change
- [x] 7.3 Run `make test FILE=tests/integration/diff/test_actions.lua CASE="Diff view stages a final line without a newline"` and see it pass

## 8. Final-line unstaging

Scenarios: `diff: Diff view unstages a final line with a different newline`

- [x] 8.1 Write the test `diff: Diff view unstages a final line with a different newline` in `tests/integration/diff/test_actions.lua`, drive `<Space>` twice on the populated final-line change, and see it fail with a non-empty `git diff --cached`
- [x] 8.2 Record HEAD's final-newline state from `git show` in `lua/gleb/diff/view/source.lua`, carry it on the view, and use it as the patch's new-side newline when unstaging a final-line change in `lua/gleb/diff/view/init.lua`
- [x] 8.3 Run `make test FILE=tests/integration/diff/test_actions.lua CASE="Diff view unstages a final line with a different newline"` and see it pass

## 9. Moved-block interaction

Scenarios: `diff: Diff view marks both ends of a moved block`, `diff: Diff view gm jumps between the ends of a move`, `diff: Diff view gm off a move does nothing`

- [x] 9.1 Write the scenarios in `tests/integration/diff/test_moves.lua`, driving `gm` in the populated `ids.go` view, and see them fail
- [x] 9.2 Request engine moves, build one line-to-row lookup, retain each side's kind, draw both move ends, and add `diff.jump_move` on `gm`
- [x] 9.3 Run `make test FILE=tests/integration/diff/test_moves.lua` and see them pass

## 10. Persisted diff settings

Scenarios: `diff: Diff settings validate diff.json`

- [x] 10.1 Write the test `diff: Diff settings validate diff.json` in `tests/unit/diff/test_settings.lua` against real temporary state files and see it fail
- [x] 10.2 Add typed validation, defaults, loading, and saving in `lua/gleb/diff/settings.lua`
- [x] 10.3 Run `make test FILE=tests/unit/diff/test_settings.lua CASE="Diff settings validate diff.json"` and see it pass

## 11. Whitespace policy actions

Scenarios: `diff: Diff view trim policy hides a trailing space`, `diff: Diff view policy hiding every change keeps the view open`, `diff: Diff view whitespace policy persists`

- [x] 11.1 Write the scenarios in `tests/integration/diff/test_settings.lua`, invoking the real radio actions on populated views, and see them fail
- [x] 11.2 Add the four whitespace actions, persist the policy, recompare every open view, and keep zero-fragment views open without folds
- [x] 11.3 Run `make test FILE=tests/integration/diff/test_settings.lua` and see them pass

## 12. Highlight mode actions

Scenarios: `diff: Diff view line mode drops word highlights`, `diff: Diff view highlight mode persists`

- [x] 12.1 Write the scenarios in `tests/integration/diff/test_settings.lua`, invoking the real radio actions on populated views, and see them fail
- [x] 12.2 Add the five highlight actions, persist the mode, and recompare every open view
- [x] 12.3 Run `make test FILE=tests/integration/diff/test_settings.lua` and see them pass

## 13. No-highlight layout

Scenarios: `diff: Diff view no-highlight mode shows plain texts`

- [x] 13.1 Write the test `diff: Diff view no-highlight mode shows plain texts` in `tests/integration/diff/test_settings.lua`, invoke `diff.highlight_none` on the populated view, and see it fail
- [x] 13.2 Pair rows through the longer side and suppress tints, padding, folds, gutter marks, and change navigation while keeping both texts
- [x] 13.3 Run `make test FILE=tests/integration/diff/test_settings.lua CASE="Diff view no-highlight mode shows plain texts"` and see it pass

## 14. Leader mapping ownership

Scenarios: `diff: Diff view leader mapping works inside the view`, `diff: Diff view leader mapping works in another window of the same file`

- [x] 14.1 Write the scenarios in `tests/integration/diff/test_view_close.lua`, driving `<leader>x` in the real diff and peer windows, and see them fail
- [x] 14.2 Preserve longer leader mappings with the per-view namespace and augroup, keeping `FocusGained` in `view.augroup`
- [x] 14.3 Run `make test FILE=tests/integration/diff/test_view_close.lua` and see them pass

## 15. Moved-block colours

Scenarios: `diff: Diff view move colours`

- [x] 15.1 Write the test `diff: Diff view move colours` in `tests/integration/diff/test_moves.lua`, reload the real colorscheme, and see it fail
- [x] 15.2 Add the palette-derived `DiffViewMoved`, `DiffViewGutterMoved`, and `DiffViewMovedMarker` groups and redefine them on `ColorScheme`
- [x] 15.3 Run `make test FILE=tests/integration/diff/test_moves.lua CASE="Diff view move colours"` and see it pass

## 16. Staged-change screen

Scenarios: `diff: Diff view staged change matches the approved render`

- [x] 16.1 Write the test `diff: Diff view staged change matches the approved render` in `tests/screen/diff/test_view.lua`, driving `<Space>` in the real `diffgo` view and using the design mask, and see it fail
- [x] 16.2 Match Proposed E1 and add its independent `tests/render/cases.lua` capture
- [x] 16.3 Run `make test FILE=tests/screen/diff/test_view.lua CASE="Diff view staged change matches the approved render"` and see it pass

## 17. Moved-block screen

Scenarios: `diff: Diff view moved block matches the approved render`

- [x] 17.1 Write the test `diff: Diff view moved block matches the approved render` in `tests/screen/diff/test_view.lua`, opening the real `ids.go` view and using the design mask, and see it fail
- [x] 17.2 Match Proposed E2 and add its independent `tests/render/cases.lua` capture
- [x] 17.3 Run `make test FILE=tests/screen/diff/test_view.lua CASE="Diff view moved block matches the approved render"` and see it pass

## Agent decisions

- Expose `state`, `update_index(..., include)` and `make_patch(..., final-newline flags)` so index math and serialization stay independently testable.
- Keep the index snapshot and its final-newline bit on each view so redraws stay synchronous and toggles can refresh it explicitly.
- Keep each moved row's original change kind separately so its arrow retains the add/delete colour while the row uses the moved tint.
- Pair no-highlight rows through the longer side and leave unmatched cells plain, preserving both complete texts without diff padding.
- Set `arrow_kind` only when a row becomes moved, so plain change rows keep their original layout model.
- Draw a padding row's blank arrow as `Normal` and its blank checkbox slot as a `DiffViewPadding` `╱`, one ordered `virt_lines` extmark per padding run, as Proposed E2 shows.
- Keep the shared scenario names on the integration cases and name the pure `patch.lua` cases after added `Diff patch …` scenarios.
- Report unsupported revert and staging actions as unavailable at WARN, naming the missing comparable `HEAD` text so the no-op is explicit.
