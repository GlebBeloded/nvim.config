## Why
User request (2026-10-15): add an on/off toggle to the palette to see how it renders. render.png shows "Soft Wrap" with a green ● (on) and "Spell Check" with a grey ○ (off), both under `View | Editor`. Screenshots: `/tmp/find-action-match/render.png` (the approved render: match it) and `/tmp/find-action-match/impl.png` (the live palette today); copies in `evidence/` of this change. Read both images before planning and compare the live palette with render.png row by row (`make render` / a reference screenshot) before handing back.

Kind: feature
Depends: fix-find-action-colors

## Evidence
- No catalog action has `toggle` (0 of about 150), and there are no wrap or spell actions, so no ●/○ can render. `PmenuKind` also carries a bg patch (fixed by fix-find-action-colors).

## What Changes
- New actions "Soft Wrap" (`wrap`) and "Spell Check" (`spell`), category `View | Editor`, each with a toggle state (get/set) so the palette draws ● (green #aab66e, on) or ○ (grey, off) before the category. Choosing one flips the option in the current window and the glyph updates without closing the palette.
- No default shortcut.

## Impact
- Code: a view/editor actions module, `lua/gleb/find_action/rows.lua` if the glyph path needs it.
- Tests: integration (toggle flips, glyph updates), screen reference with both states.
