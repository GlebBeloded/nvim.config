## Why
User report (2026-10-15): the shipped Find Action palette "doesn't quite look how I expected". It should match the approved design (find-action design.md, Proposed H1, and its highlight map) in background colours and in the font of the category column (`Git | Diff`). The user also does not see "recently used".

Kind: bug
Adopt: loop/fix-find-action-match-design-20261015-125831

## Evidence
- `evidence/design.png`: the approved design's palette, with a `recently used` section, the selected row Open Differ, and the category column in plain weight.
- `evidence/live.png`: the user's live palette (right half). The selected row's `Git | Diff` is bold and brighter than in the design.
- Sampled colours that match in both images: body `#44403d`, selected row `#59524d`, category `#a59a86`. Find which backgrounds differ by comparing a live render with design.md H1 (row by row, highlight map included) rather than trusting these samples.
- Recently used: `~/.local/state/nvim/find_action_recent.json` holds one id (`tree.toggle_filesystem`). Only palette runs are recorded (`lua/gleb/find_action/palette.lua:256`), so actions run by shortcut never appear. The section is drawn only when a recent action passes the mode/filetype filter (`palette.lua:62-67`).
- Highlights: `lua/gleb/picker/frame.lua:29-37`, `lua/gleb/picker/rows.lua:60-111`. The design's selected-row groups are PmenuSel/PmenuExtraSel (design.md H1 highlight map).

## What Changes
- The live palette matches design H1: backgrounds, and the category column's weight and colour on selected and unselected rows.
- "recently used" shows the user's recent actions. Recommendation: record every action run through the registry (shortcut or palette), not only palette runs.
- The reference screenshots compare colours and attributes against the H1 highlight map, so this kind of drift fails a test.

## Impact
- Code: `lua/gleb/find_action/`, `lua/gleb/picker/` (highlights), action dispatch in `lua/gleb/actions/` (recording).
- Tests: find-action screen and e2e references.

## Rejected run
Run on `loop/fix-find-action-match-design-20261015-125831` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  1. [must-fix] lua/gleb/picker/rows.lua:74,80-83 (with palette.lua `selected_category = true`): unselected shortcut hints now use `PmenuExtra` (fg a89984). Approved H1 maps them to `FloatBorder` (fg 928374): see archive/2026-10-14-find-action/design.md:119, where `Find in Files...  ⌘⇧F` gives `bbb`. Before this diff they were `Comment` (fg 928374), so they matched H1's colour. This change moves them away from H1, against What Changes ("live palette matches approved H1"). Probe in the full config: buffer line 3 `Move left <C-h>` has an extmark {2,11,16,"PmenuExtra"}. Earlier passes missed it because the masks in tests/screen/find-action/test_palette.lua:206-216 only check the selected row and row 20, and row 20 has no shortcut hint. Fix: unselected secondary → `FloatBorder`, selected → `PmenuExtraSel`. Add a color-mask assertion on an unselected row that has a shortcut hint (H1 row 119).
  2. [minor] tests/screen/find-action/test_palette.lua:139-190: `expect_color_mask` still duplicates `H.expect_screen_colors` (tests/helpers.lua:641, docs/testing.md). This carries over from passes 2 and 4.
  3. [minor] tests/e2e/find-action/screens.lua and tests/unit/find-action/test_items.lua are not listed in proposal Impact or tasks.md. The gate needed both: palette opens now record `find_action.open`, and the "Empty query puts recent actions first" test moved to integration at pass 2's request. The test name is unique under tests/.
  4. [minor] context.lua:77-81 and apply.lua:115-130: run-only a
