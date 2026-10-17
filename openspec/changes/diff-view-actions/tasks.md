## 1. Index states and patches (pure)

Scenarios: `diff: Diff patch states of a change, an insertion and a deletion`, `diff: Diff patch state of a partly staged change`, `diff: Diff patch stages one change`, `diff: Diff patch stages an insertion and a deletion`

- [x] 1.1 Write `tests/unit/diff/test_patch.lua`, and see it fail. It covers:
  - the states `☐`/`☑`/`◪`;
  - the staged and unstaged index texts for a change, an insertion and a deletion;
  - overlapping staged edits;
  - a file without a final newline, whose patch passes `git apply --cached --check` in a temp repo.
- [x] 1.2 Add `lua/gleb/diff/patch.lua` (pure, typed), following design Decision 3.
- [x] 1.3 Run the file and see it pass

## 2. Revert and staging in the view

Scenarios: `diff: Diff view do reverts a changed line`, `diff: Diff view dp reverts a deletion from the left window`, `diff: Diff view reverts an insertion as one undo step`, `diff: Diff view revert off a change does nothing`, `diff: Diff view checkboxes follow the index`, `diff: Diff view checkbox of a partly staged change`, `diff: Diff view Space stages one change`, `diff: Diff view Space unstages a staged change`, `diff: Diff view stages an insertion and a deletion separately`, `diff: Diff view reports a staging failure`

- [x] 2.1 Write these scenarios in `tests/integration/diff/test_actions.lua` (`diffgo` and `dirty` fixtures), and see them fail
- [x] 2.2 Add:
  - `layout.change_at` (Decision 1);
  - `diff.apply` (Decision 2);
  - `lua/gleb/diff/stage.lua` (Decision 4);
  - checkbox states in `layout.lua`/`render.lua` (Decision 5);
  - the actions with their keys in `settings/keymap.json` (`do`, `dp`, `<Space>`).
- [x] 2.3 Run the file and see it pass, together with `tests/integration/diff/test_view_close.lua` (the key ownership scenarios).

## 3. Moved blocks

Scenarios: `diff: Diff view marks both ends of a moved block`, `diff: Diff view gm jumps between the ends of a move`, `diff: Diff view gm off a move does nothing`, `diff: Diff view move colours`

- [x] 3.1 Write these scenarios in `tests/integration/diff/test_moves.lua` (`diffgo`, `internal/user/ids.go`), and see them fail
- [x] 3.2 Compare with `moves = true` and add:
  - the `Moved` rows and markers (Decision 6);
  - `diff.jump_move` on `gm`;
  - the three groups (Decision 9).
- [x] 3.3 Run the file and see it pass

## 4. Whitespace policy and highlight mode

Scenarios: `diff: Diff view trim policy hides a trailing space`, `diff: Diff view whitespace policy persists`, `diff: Diff view line mode drops word highlights`, `diff: Diff view no-highlight mode shows plain texts`, `diff: Diff view highlight mode persists`, `diff: Diff settings validate diff.json`

- [x] 4.1 Write these scenarios in `tests/integration/diff/test_settings.lua` and the `diff.json` validation in `tests/unit/diff/test_settings.lua`, and see them fail
- [x] 4.2 Add `lua/gleb/diff/settings.lua` and the nine radio actions (Decisions 7 and 8), and re-compare open views on change.
- [x] 4.3 Run both files and see them pass

## 5. Screens

Scenarios: `diff: Diff view staged change matches the approved render`, `diff: Diff view moved block matches the approved render`

- [x] 5.1 Add both cases to `tests/screen/diff/test_view.lua`, and see them fail:
  - a `100x30` child on `diffgo`;
  - rows 2–29 screenshot plus `H.expect_screen_colors` with the masks of Proposed E1 and E2.
- [x] 5.2 Make them pass. Re-run `diff: Diff view matches the approved render` unchanged.
- [x] 5.3 Compare `make render` (cases `diff-view-staged` and `diff-view-moved` in `tests/render/cases.lua`) with `renders/*.ansi`, then run `make check`.

## Agent decisions

- Expose `state`, `update_index(..., include)` and `make_patch(..., final-newline flags)` so index math and serialization stay independently testable.
- Keep the index snapshot and its final-newline bit on each view so redraws stay synchronous and toggles can refresh it explicitly.
- Keep each moved row's original change kind separately so its arrow retains the add/delete colour while the row uses the moved tint.
- Pair no-highlight rows through the longer side and leave unmatched cells plain, preserving both complete texts without diff padding.
- Set `arrow_kind` only when a row becomes moved, so plain change rows keep their original layout model.
- Draw a padding row's blank arrow as `Normal` and its blank checkbox slot as a `DiffViewPadding` `╱`, one ordered `virt_lines` extmark per padding run, as Proposed E2 shows.
- Keep the shared scenario names on the integration cases and name the pure `patch.lua` cases after added `Diff patch …` scenarios.
- Report unsupported revert and staging actions as unavailable at WARN, naming the missing comparable `HEAD` text so the no-op is explicit.

## 6. Review fixes

- [x] Guard revert and staging for files without a usable `HEAD` text, and reject staged overlap outside the selected change.
- [x] Keep hidden and fully reverted views open, while deriving staging and checkbox state from the default policy in one pass.
- [x] Build move row lookups once and preserve longer `<leader>` mappings in every window showing the right buffer.
