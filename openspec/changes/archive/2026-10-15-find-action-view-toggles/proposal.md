## Why
User request (2026-10-15): add an on/off toggle to the palette to see how it renders. render.png shows "Soft Wrap" with a green ● (on) and "Spell Check" with a grey ○ (off), both under `View | Editor`. Screenshots: `/tmp/find-action-match/render.png` (the approved render: match it) and `/tmp/find-action-match/impl.png` (the live palette today); copies in `evidence/` of this change. Read both images before planning and compare the live palette with render.png row by row (`make render` / a reference screenshot) before handing back.

Kind: feature
Depends: fix-find-action-colors

## Evidence
- The populated catalog has 136 actions and zero toggles, and there are no wrap or spell actions, so no ●/○ can render. `PmenuKind` also carries a bg patch (fixed by fix-find-action-colors).

## What Changes
- New actions "Soft Wrap" (`wrap`) and "Spell Check" (`spell`), category `View | Editor`, each with a toggle state (get/set) so the palette draws ● (green #aab66e, on) or ○ (grey, off) before the category. Choosing one flips the option in the current window and the glyph updates without closing the palette.
- No default shortcut.

## Capabilities
- `find-action`: add real window-local Soft Wrap and Spell Check toggle actions to the populated palette.

## Impact
- Architecture: add `lua/gleb/view/actions.lua` and wire it into the action catalog in `init.lua`.
- Code: the existing Find Action toggle execution and row-rendering paths are reused; no plugin dependency is added, removed, or upgraded.
- Tests: integration coverage for both window-local options and the live glyph refresh; screen reference coverage with both states.
- Core keymaps do not change; neither action receives a default shortcut.
- Out of scope: new toggle styling, global option changes, additional editor toggles, and shortcut assignment defaults.
