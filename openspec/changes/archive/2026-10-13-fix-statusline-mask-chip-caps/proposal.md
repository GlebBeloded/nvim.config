## Why
On `auto` b9ad8af both statusline screen cases fail in their color mask (`tests/screen/statusline/test_statusline_screen.lua`). Two branches each changed the chip and merged without a git conflict. fix-screen-test-color-gap wrote the masks for the chip without caps (7 cells). fix-empty-nerd-font-glyphs restored the rounded caps U+E0B6 / U+E0B4 and regenerated only the reference screenshots. Each cap is 1 cell wide, so the chip is now 9 cells (columns 72–80) and the masks are 2 columns off. The glyphs and the screenshots are correct (root cause: `artifacts/runs/2a8b3599-…/root-cause.md`).

The test also says it shows the "no LSP" cap, but none-ls attaches `null-ls` to `sample.lua` shortly after start. That turns the left cap from `StatuslineLangCapError` (red) to `StatuslineLangCapOk` (green) partway through the case. With empty caps nobody could see this. With caps restored, a corrected mask flakes on that cell.

Kind: bug

## What Changes
- Update both masks and legends in the statusline screen test to the 9-cell chip: left cap at column 72 in `StatuslineLangCapError`, right cap at column 80 in `StatuslineLangEdge`, and diagnostics moved 2 columns left.
- Make the "no LSP client" state of the screen cases deterministic: no LSP client, null-ls included, attaches to the test buffer for the whole case.
- Spec: the two reference-screenshot scenarios state the no-LSP precondition and the chip with both caps, so the red left cap is part of the asserted screen.
- Keep the Decision of fix-empty-nerd-font-glyphs (caps U+E0B6 / U+E0B4). Do not change the glyphs, their width or the committed screenshots.

## Capabilities
### New Capabilities
None.

### Modified Capabilities
- `statusline`: "Statusline visual style": the two reference-screenshot scenarios name the no-LSP state and the capped chip.

## Impact
- Code: none in `lua/`; tests only: `tests/screen/statusline/test_statusline_screen.lua`. References in `tests/screenshots/` stay as committed (they already show the caps).
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: chip glyphs, width or colors; none-ls configuration in the real config; the Copilot glyph and other screen tests.
