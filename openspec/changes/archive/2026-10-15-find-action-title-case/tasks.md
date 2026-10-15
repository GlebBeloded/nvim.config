## 1. Make the real catalog labels match the approved vocabulary
Scenarios: `find-action: Catalog rows use standalone Title Case labels`
- [x] 1.1 Write the test `find-action: Catalog rows use standalone Title Case labels` in `tests/integration/find-action/test_run.lua`; drive `<M-A>` into the real picker with the populated action catalog and see the old titles and categories fail
- [x] 1.2 Update palette-visible action metadata to the approved standalone Title Case titles and category hierarchy without changing action ids or shortcuts; update description expectations that derive from that metadata
- [x] 1.3 Run `make test FILE=tests/integration/find-action/test_run.lua CASE="Catalog rows use standalone Title Case labels"` and see it pass

## 2. Render hierarchical categories with a dim separator
Scenarios: `find-action: Wide palette matches reference screenshots`
- [x] 2.1 Update `find-action: Wide palette matches reference screenshots` in `tests/screen/find-action/test_palette.lua` to open the real picker from `<M-A>` with populated catalog data, assert the separator highlight, and see the approved wide reference fail
- [x] 2.2 Render ` | ` separately from both category names with [FindActionSeparator], then update and review the affected Find Action reference screenshots against `design.md`
- [x] 2.3 Run `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"` and see it pass

## Agent decisions

- Used IntelliJ-style verb-object labels with the affected object named explicitly, so each title remains clear outside its category.
- Applied `Git | Diff` to differ and diffview actions, `Edit | Find` to file search, and `View | Tool Windows` to tree toggles to match the approved hierarchy.
- Reused the palette's existing dim color for `FindActionSeparator`, keeping the separator secondary to both category names.
- Sourced changed screenshot actions from their production action modules, so future metadata drift fails the render scenario.
