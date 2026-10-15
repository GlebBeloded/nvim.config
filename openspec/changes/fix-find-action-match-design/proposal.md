## Why
User report (2026-10-15): the shipped Find Action palette "doesn't quite look how I expected". It should match the approved design (find-action design.md, Proposed H1, and its highlight map) in background colours and in the font of the category column (`Git | Diff`). The user also does not see "recently used".

Kind: bug
Adopt: loop/fix-find-action-match-design-20261015-125831

## Evidence
- `evidence/design.png`: the approved design's palette, with a `recently used` section, the selected row Open Differ, and the category column in plain weight.
- `evidence/live.png`: the user's live palette (right half). The selected row's `Git | Diff` is bold and brighter than in the design.
- `lua/gleb/picker/frame.lua:26-37` hard-codes the picker body and selected backgrounds to palette `bg0`/`bg1`; approved H1 instead maps those cells to `NormalFloat`/`PmenuSel`. `lua/gleb/picker/rows.lua:109-112` always applies unselected `PmenuExtra` to a category, while H1 maps the selected category to `PmenuExtraSel`.
- `lua/gleb/actions/apply.lua:39-61` installs `mapping` and `plug` actions as their raw rhs, while `apply.lua:104-124,231-233` records any matching typed key globally before knowing whether that mapping ran. A headless probe that opened Find Action, typed `<C-h><Esc>`, and inspected history produced `{ "window.move_left" }` even though MiniPick consumed `<C-h>` to scroll its query and the action never ran.
- `tests/screen/find-action/test_palette.lua:65-72` seeds history directly, and its wide case (`test_palette.lua:109-123`) has no H1 color-mask assertion, so it neither exercises real shortcut recording nor catches background and selected-category attribute drift.

## What Changes
- The live palette matches approved design H1's background groups and category-column weight and colour on selected and unselected rows.
- "recently used" records catalog actions run from configured shortcuts as well as from the palette, then shows the applicable actions in most-recently-used order.
- The reference screenshots compare colours and attributes against the H1 highlight map, so this kind of drift fails a test.

## Impact
- Runtime: `lua/gleb/find_action/palette.lua`, action dispatch in `lua/gleb/actions/context.lua` and `lua/gleb/actions/apply.lua`, and Find Action highlight support in `lua/gleb/picker/frame.lua` and `lua/gleb/picker/rows.lua`.
- Tests: `tests/integration/find-action/test_run.lua`, `tests/screen/find-action/test_palette.lua`, `tests/e2e/find-action/screens.lua`, `tests/unit/find-action/test_items.lua`, and the reference screenshots.
- Architecture: no module-layout, load-order, or plugin-wiring change.
- Dependencies: no plugin is added, removed, or upgraded.
- Core keymaps: unchanged.
- Out of scope: changing the approved H1 layout, picker breakpoints, action availability filters, shortcut assignment, or other picker sources' appearance.

## Rejected run
Run on `loop/fix-find-action-match-design-20261015-125831` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  1. [must-fix] lua/gleb/picker/rows.lua:74,80-83 (with palette.lua `selected_category = true`): unselected shortcut hints now use `PmenuExtra` (fg a89984). Approved H1 maps them to `FloatBorder` (fg 928374): see archive/2026-10-14-find-action/design.md:119, where `Find in Files...  ⌘⇧F` gives `bbb`. Before this diff they were `Comment` (fg 928374), so they matched H1's colour. This change moves them away from H1, against What Changes ("live palette matches approved H1"). Probe in the full config: buffer line 3 `Move left <C-h>` has an extmark {2,11,16,"PmenuExtra"}. Earlier passes missed it because the masks in tests/screen/find-action/test_palette.lua:206-216 only check the selected row and row 20, and row 20 has no shortcut hint. Fix: unselected secondary → `FloatBorder`, selected → `PmenuExtraSel`. Add a color-mask assertion on an unselected row that has a shortcut hint (H1 row 119).
  2. [minor] tests/screen/find-action/test_palette.lua:139-190: `expect_color_mask` still duplicates `H.expect_screen_colors` (tests/helpers.lua:641, docs/testing.md). This carries over from passes 2 and 4.
  3. [minor] tests/e2e/find-action/screens.lua and tests/unit/find-action/test_items.lua are not listed in proposal Impact or tasks.md. The gate needed both: palette opens now record `find_action.open`, and the "Empty query puts recent actions first" test moved to integration at pass 2's request. The test name is unique under tests/.
  4. [minor] context.lua:77-81 and apply.lua:115-130: run-only a
