## Why
User report (2026-10-15): the Find Action palette "still looks off… it lacks colors" next to the approved render. Screenshots: `/tmp/find-action-match/render.png` (the approved render: match it) and `/tmp/find-action-match/impl.png` (the live palette today); copies in `evidence/` of this change. Read both images before planning and compare the live palette with render.png row by row (`make render` / a reference screenshot) before handing back.

Kind: bug

## Decision (user, 2026-10-15)
- render.png is the target. Its hint row replaces design H1's: an in-frame darker band, hint keys bright and their words dim, hints left, the match counter (`39/39`) right. Show hints only for features that exist: there is no standalone Remove, so no `Remove ^X` (auditor's reading).

## Evidence (live config, headless dump; gruvbox-material is loaded)
- Body: `colors/transparency.lua:9` clears the `NormalFloat` bg, so the palette body is the terminal bg (#302f2c), not #45403d. `PmenuExtra`/`PmenuKind` keep bg #45403d, which paints patches behind categories, section labels and rules (`lua/gleb/picker/rows.lua:62-63,109-112`).
- Prompt: `lua/gleb/picker/frame.lua:36` sets `MiniPickPromptPrefix` to fg1 (cream). The render's `Find Action ›` is orange (#da8f57, `FloatTitle`).
- Section rows: the label is grey #a59a86 on the plain body, and the rule is dim #8f8475 (`FloatBorder`). Today one bg-carrying group covers the whole line.
- Shortcut labels: `lua/gleb/find_action/rows.lua:61` looks up the raw lhs. `settings/keymap.json` stores `<A-x>`/`<C-h>`, while the label table is keyed `<M-x>`/`<C-H>`. Normalise with `vim.fn.keytrans(vim.keycode(lhs))` (`<A-F>`→`<M-F>`, `<C-h>`→`<C-H>`). The render puts two spaces between title and shortcut (`rows.lua:78` uses one), and its shortcuts are dim #8f8475. `<M-H>` and `<C-S>` have no label entry (`openspec/specs/shortcuts/spec.md:354-360` maps `\eH` to `<M-h>`, but Neovim receives `<M-H>`).
- Footer: a separate bordered float (`frame.lua:79-107`) with a blank row, and `PickerHint` fg is a bg grey (`frame.lua:40`).
- Sampled render colours: body #45403d, selected row #59524d, title #d9c8a5, category #a59a86, shortcut and rule #8f8475, hint band #32302f.

## What Changes
- The palette body, selected row, section rows, categories, shortcuts, prompt and hint row match render.png colours, with no bg patches. Every group the palette uses is fg-only over the palette body bg, and the palette keeps its body bg under the transparency setting.
- Shortcut labels resolve for every lhs spelling (`<A-…>`, lowercase `<C-…>`), two spaces after the title.
- The hint row is the in-frame band from the Decision, with the counter.
- The reference screenshots and their colour masks are regenerated from render.png's colours.
- No plugin dependency is added, removed or upgraded. Core keymaps do not change.
- Out of scope: changing action execution, assignment-dialog behaviour, or the default appearance of other shared pickers.

## Capabilities
- `find-action` (modified): canonical shortcut labels and the approved palette reference screens.
- `picker` (modified): row highlight separation and an opt-in in-frame hint band with a match counter.

## Impact
- Code: `lua/gleb/picker/frame.lua`, `lua/gleb/picker/rows.lua`, `lua/gleb/find_action/palette.lua`, `lua/gleb/find_action/rows.lua`, and `lua/gleb/colors/transparency.lua` (Find Action palette floats only).
- Tests: `tests/unit/picker/test_rows.lua`, `tests/unit/find-action/test_rows.lua`, `tests/screen/picker/test_frame.lua`, `tests/screen/find-action/test_palette.lua`, and their Find Action reference screenshots.
