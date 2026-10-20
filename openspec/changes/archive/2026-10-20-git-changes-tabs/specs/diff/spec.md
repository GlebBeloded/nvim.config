## ADDED Requirements

### Requirement: Diff view committed layer
A spec with `committed = true` SHALL draw every added, changed and deleted row with `DiffViewCommitted` (line), `DiffViewGutterCommitted` (gutter) and `DiffViewArrowCommitted` (arrow), changed words with `DiffViewCommittedWord`, keep the moved-block groups, show no include checkboxes, and act as not actionable with both sides read-only. Colours: line `bg` `util.blend(purple, bg0, 0.74)`, word `bg` 0.5, gutter `fg` grey1 and arrow `fg` purple on the line `bg`, redefined on `ColorScheme`.

#### Scenario: Diff view draws a committed spec in purple
- **WHEN** from the first of two windows `show(<second>, { path = "c.txt", left = { "one", "two" }, right = { "one", "too", "three" }, labels = { "4ccefde · main", "e325463 · HEAD" }, committed = true })` runs
- **THEN**
  - the right buffer's line extmarks on rows 2 and 3 use `DiffViewCommitted`, row 2 has a `DiffViewCommittedWord` range, and no extmark of either window uses `DiffViewAdd`, `DiffViewChange`, `DiffViewDelete` or `DiffViewWord`;
  - the gutter of rows 2 and 3 uses `DiffViewGutterCommitted` and holds no checkbox glyph;
  - both diff buffers have `modifiable` off, and `do` in the right window leaves its lines unchanged.

#### Scenario: Diff view committed colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `DiffViewCommitted` has `bg` `util.blend(purple, bg0, 0.74)`, `DiffViewCommittedWord` has `bg` `util.blend(purple, bg0, 0.5)`, `DiffViewGutterCommitted` has `fg` grey1 on that line `bg`, and `DiffViewArrowCommitted` has `fg` purple on that line `bg`

#### Scenario: Diff view without committed keeps its kind colours
- **WHEN** the same `show` runs without `committed`
- **THEN** row 2 uses `DiffViewChange` and row 3 `DiffViewAdd`, and no extmark uses a `DiffViewCommitted` group
