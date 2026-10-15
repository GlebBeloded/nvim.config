## 1. Record shortcut and palette use in recent history
Scenarios: `find-action: Empty query puts recent actions first`, `find-action: Shortcut and palette use update recent actions`
- [x] 1.1 Write the test `find-action: Shortcut and palette use update recent actions` in `tests/integration/find-action/test_run.lua`; drive a populated catalog through a configured shortcut and `<CR>` in the real palette, reopen it with `<M-A>`, and see the missing shortcut action make the MRU assertion fail
- [x] 1.2 Route palette and configured-shortcut catalog execution through shared recent-history recording, removing the palette-only recording path
- [x] 1.3 Run `make test FILE=tests/integration/find-action/test_run.lua CASE="Shortcut and palette use update recent actions"` and see it pass

## 2. Match the approved H1 highlights
Scenarios: `find-action: Wide palette matches reference screenshots`
- [x] 2.1 Tighten `tests/screen/find-action/test_palette.lua` with the approved H1 color mask and selected-category attributes, then run `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"` and see it fail
- [x] 2.2 Make the Find Action frame and rows use H1's `NormalFloat`, `PmenuSel`, `PmenuExtra`, and `PmenuExtraSel` roles without changing other picker sources' appearance, then update the intended reference screenshots
- [x] 2.3 Run `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"` and see it pass

## 3. Record only shortcuts whose mappings execute
Scenarios: `find-action: Only executed shortcuts update recent actions`
- [x] 3.1 Write the test `find-action: Only executed shortcuts update recent actions` in `tests/integration/find-action/test_run.lua`; drive configured `mapping` and `plug` shortcuts and type a colliding configured key in the real populated Find Action picker, then see the execution-only history assertion fail
- [x] 3.2 Wrap configured `mapping` and `plug` rhs execution with recent-history recording while preserving remap behavior, and remove global typed-key recording
- [x] 3.3 Run `make test FILE=tests/integration/find-action/test_run.lua CASE="Only executed shortcuts update recent actions"` and see it pass

## Agent decisions

- Skip `find_action.open` only when its configured shortcut opens the palette, so palette runs still enter history without every open displacing the reused action.
- Pass highlight and selected-metadata options from Find Action so shared picker sources retain their existing appearance.
- Restore selection from source-match completion because MiniPick item replacement is asynchronous.
- Return plug targets from expression callbacks with remapping enabled so recording wraps execution without changing recursive `<Plug>` resolution.
