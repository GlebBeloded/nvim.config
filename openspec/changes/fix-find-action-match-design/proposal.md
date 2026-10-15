## Why
User report (2026-10-15): the shipped Find Action palette "doesn't quite look how I expected". It should match the approved design (find-action design.md, Proposed H1, and its highlight map) in background colours and in the font of the category column (`Git | Diff`). The user also does not see "recently used".

Kind: bug
Adopt: loop/fix-find-action-match-design

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
- Tests: `tests/integration/find-action/test_run.lua`, `tests/screen/find-action/test_palette.lua`, and its reference screenshots.
- Architecture: no module-layout, load-order, or plugin-wiring change.
- Dependencies: no plugin is added, removed, or upgraded.
- Core keymaps: unchanged.
- Out of scope: changing the approved H1 layout, picker breakpoints, action availability filters, shortcut assignment, or other picker sources' appearance.
