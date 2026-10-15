## Why
User report (2026-10-15): the shipped Find Action palette "doesn't quite look how I expected". It should match the approved design (find-action design.md, Proposed H1, and its highlight map) in background colours and in the font of the category column (`Git | Diff`). The user also does not see "recently used".

Kind: bug

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
