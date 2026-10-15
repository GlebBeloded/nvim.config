## 1. Record shortcut and palette use in recent history
Scenarios: `find-action: Empty query puts recent actions first`
- [x] 1.1 Write the test `find-action: Empty query puts recent actions first` in `tests/integration/find-action/test_run.lua`; drive a populated catalog through a configured shortcut and `<CR>` in the real palette, reopen it with `<M-A>`, and see the missing shortcut action make the MRU assertion fail
- [x] 1.2 Route palette and configured-shortcut catalog execution through shared recent-history recording, removing the palette-only recording path
- [x] 1.3 Run `make test FILE=tests/integration/find-action/test_run.lua CASE="Empty query puts recent actions first"` and see it pass

## 2. Match the approved H1 highlights
Scenarios: `find-action: Wide palette matches reference screenshots`
- [x] 2.1 Tighten `tests/screen/find-action/test_palette.lua` with the approved H1 color mask and selected-category attributes, then run `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"` and see it fail
- [x] 2.2 Make the Find Action frame and rows use H1's `NormalFloat`, `PmenuSel`, `PmenuExtra`, and `PmenuExtraSel` roles without changing other picker sources' appearance, then update the intended reference screenshots
- [x] 2.3 Run `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"` and see it pass

## Agent decisions

- Record `find_action.open` when `<M-A>` runs because it is a configured catalog shortcut covered by the same history rule.
- Pass highlight and selected-metadata options from Find Action so shared picker sources retain their existing appearance.
