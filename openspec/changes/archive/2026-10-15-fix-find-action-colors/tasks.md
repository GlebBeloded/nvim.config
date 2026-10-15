## 1. Separate picker row spacing and highlights
Scenarios: `picker: Rows expose primary secondary and category text`, `picker: Section header fills its row with a rule`
- [x] 1.1 Tighten `tests/unit/picker/test_rows.lua` for two spaces before secondary text, foreground-only metadata groups, and separate section label/rule groups; run `make test FILE=tests/unit/picker/test_rows.lua CASE="Rows expose primary secondary and category text"` and `make test FILE=tests/unit/picker/test_rows.lua CASE="Section header fills its row with a rule"` and see them fail
- [x] 1.2 Update `lua/gleb/picker/rows.lua` with the two-space separator and small named highlight ranges for section labels, rules, shortcuts, categories, and state glyphs
- [x] 1.3 Run `make test FILE=tests/unit/picker/test_rows.lua CASE="Rows expose primary secondary and category text"` and `make test FILE=tests/unit/picker/test_rows.lua CASE="Section header fills its row with a rule"` and see them pass

## 2. Canonicalize Find Action shortcut labels
Scenarios: `find-action: Rows show action metadata`, `find-action: Rows fall back to Vim notation`, `find-action: Rows normalize shortcut spellings`
- [x] 2.1 Extend `tests/unit/find-action/test_rows.lua` with populated actions using `<A-F>`, `<C-h>`, `<M-H>`, `<C-S>`, and an unknown shortcut; run `make test FILE=tests/unit/find-action/test_rows.lua CASE="Rows normalize shortcut spellings"` and see the raw spellings fail
- [x] 2.2 Update `lua/gleb/find_action/rows.lua` to canonicalize each first lhs before physical-label lookup and supply the missing known physical labels
- [x] 2.3 Run `make test FILE=tests/unit/find-action/test_rows.lua CASE="Rows normalize shortcut spellings"` and the two existing row cases and see them pass

## 3. Add the opt-in in-frame hint band
Scenarios: `picker: Source-specific hint band shows hints and counter`
- [x] 3.1 Add `picker: Source-specific hint band shows hints and counter` to `tests/screen/picker/test_frame.lua`, start the real shared picker with populated matches and hint-band options, and run `make test FILE=tests/screen/picker/test_frame.lua CASE="Source-specific hint band shows hints and counter"` to see the separate counter-free footer fail
- [x] 3.2 Extend `lua/gleb/picker/frame.lua` with an opt-in final inner hint row, segmented hint highlights, and a live current/total counter while preserving the default shared-picker frame
- [x] 3.3 Run `make test FILE=tests/screen/picker/test_frame.lua CASE="Source-specific hint band shows hints and counter"` and see it pass

## 4. Match the approved Find Action palette
Scenarios: `find-action: Wide palette matches reference screenshots`, `find-action: Compact palette matches reference screenshot`, `find-action: Narrow palette matches reference screenshot`
- [x] 4.1 Tighten `tests/screen/find-action/test_palette.lua` and its approved references to assert the real `<M-A>` palette's body, selected row, orange prompt, split section colours, dim metadata, two-space shortcuts, darker in-frame hint band, bright hint keys, applicable hints, and counter; run each named case and see the current palette fail
- [x] 4.2 Configure `lua/gleb/find_action/palette.lua`, `lua/gleb/picker/frame.lua`, and `lua/gleb/colors/transparency.lua` so only Find Action uses the approved semantic colours and opaque body under transparency, opts into the hint band, and omits unsupported hints
- [x] 4.3 Run the three cases in `tests/screen/find-action/test_palette.lua`, regenerate their reference screenshots and colour masks, compare `make render` row by row with `openspec/changes/fix-find-action-colors/evidence/render.png`, and see them pass

## Agent decisions

- Use generic foreground-only picker groups and source-local remaps so selected and normal row backgrounds stay continuous.
- Count matched non-section rows against all non-section rows because section headings are chrome, not matches.
- Keep approved sampled colours in the palette helper and apply them only through Find Action window overrides.
- Draw the hint band as a float over the main window's bottom border with native side and bottom borders, so MiniPick's height-based visible range equals the item rows and no match sits under the band.
