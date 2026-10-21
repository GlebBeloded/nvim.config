## ADDED Requirements

### Requirement: Diff view jump to source
`diff.jump_to_source` (`Jump to Source`, `Git | Diff`, plugin `gleb-diff`, `gf` in `settings/keymap.json`) SHALL close the view, edit its working-tree file (`spec.path`) in the window that held its right side (a view with its own tab page: the window it opened from) and focus it, with the cursor on the right line under the diff cursor, or the right line transferred from the left cursor, clamped to the file's line count. Outside view windows `gf` SHALL stay native.

#### Scenario: Diff view gf opens the file at the cursor line
- **WHEN** the `controller.go` view is opened by `diff.open_file`, the left cursor is on line 65 and `gf` is pressed in normal mode
- **THEN** there is 1 tab page, no window shows a `gleb-diff` buffer, the current window edits `internal/user/controller.go` and its cursor is on line 66

#### Scenario: Diff view gf on a read-only right side
- **WHEN** from the first of two windows `show(<second>, { path = <root>/c.txt, left = { "one", "two" }, right = { "one", "too", "three" }, labels = { "parent", "commit" }, committed = true })` runs for a file `c.txt` holding `one`, `two`, focus moves to the right window, its cursor is put on line 3 and `gf` is pressed in normal mode
- **THEN** no `gleb-diff` window remains, the second window is current and edits `c.txt`, and its cursor is on line 2, the file's last line

## MODIFIED Requirements

### Requirement: Diff view embedding
`require("gleb.diff.view").show(win, spec)` SHALL show a view in the area of window `win`, without changing the current window or the tab page count. `spec` holds `path`, `left` (lines), `right` (a buffer or lines), `labels` and an optional `on_next_file`. The cursor SHALL start on the first change's first line (right) and its transferred line (left). A later `show` on the same area SHALL replace the view. `diff.next_file` SHALL call `on_next_file`; without one, it does nothing.

#### Scenario: Diff view shows in a given window without focus
- **WHEN** a second window is open, and from the first one `show(<second>, { path = "b.txt", left = { "a", "b" }, right = { "a", "c" }, labels = { "HEAD", "Working tree" } })` runs
- **THEN**
  - the tab page count is unchanged and the first window is still current;
  - the second window's area holds two windows, with lines `a`, `b` on the left and `a`, `c` on the right;
  - the left winbar reads ` HEAD`.

#### Scenario: Diff view show starts on the first change
- **WHEN** a second window is open, and from the first one `show(<second>, { path = "d.txt", left = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" }, right = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "J", "k", "l" }, labels = { "HEAD", "Working tree" } })` runs
- **THEN** the first window is still current, the right window's cursor is on line 10 and the left window's cursor is on line 10

#### Scenario: Diff view ]f calls the next-file hook
- **WHEN** a view shown with an `on_next_file` callback has its right window focused and `]f` is pressed in normal mode
- **THEN** the callback ran once

#### Scenario: Diff view ]f without a list keeps the view
- **WHEN** `]f` is pressed in normal mode in the right window of the `controller.go` view opened by `diff.open_file`
- **THEN** the view, its buffers and the cursor are unchanged

### Requirement: Diff view committed layer
A spec with `committed = true` SHALL be a history comparison: not actionable, no include checkboxes, a read-only left side, and a right side read-only when given as lines but editable when given as `right_buf`. It SHALL draw rows, words, gutters, arrows and moved blocks with the same groups as any other spec; no `DiffViewCommitted*` group SHALL be defined. A read-only right side SHALL get the file's Tree-sitter syntax like the left.

#### Scenario: Diff view draws a committed spec in purple
- **WHEN** from the first of two windows `show(<second>, { path = "c.txt", left = { "one", "two" }, right = { "one", "too", "three" }, labels = { "4ccefde · main", "e325463 · HEAD" }, committed = true })` runs
- **THEN**
  - no purple: no extmark or gutter of either window uses a group whose name starts with `DiffViewCommitted`; the right buffer's line extmarks use `DiffViewChange` on row 2 and `DiffViewAdd` on row 3, and row 2 has a `DiffViewWord` range;
  - the gutter of rows 2 and 3 uses `DiffViewGutterChange` and `DiffViewGutterAdd` and holds no checkbox glyph;
  - both diff buffers have `modifiable` off, and `do` in the right window leaves its lines unchanged.

#### Scenario: Diff view committed colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `vim.api.nvim_get_hl(0, { name = <group> })` is empty for `DiffViewCommitted`, `DiffViewCommittedWord`, `DiffViewGutterCommitted` and `DiffViewArrowCommitted`, and `DiffViewChange` still has `bg` `util.blend(blue, bg0, 0.72)`

#### Scenario: Diff view without committed keeps its kind colours
- **WHEN** the same `show` runs without `committed`
- **THEN** row 2 uses `DiffViewChange` and row 3 `DiffViewAdd`, as with `committed`, and the gutter of row 2 holds the include checkbox glyph

#### Scenario: Diff view committed spec keeps a given buffer editable
- **WHEN** a listed buffer of `c.txt` holds `one`, `too`, `three` and from the first of two windows `show(<second>, { path = <its name>, left = { "one", "two" }, right = <its lines>, right_buf = <it>, labels = { "4ccefde · main", "Your version" }, committed = true })` runs, then in the right window `:3delete` runs and 300 ms pass
- **THEN** the right window shows that buffer with `modifiable` on, the buffer holds `one`, `too`, the view has one fragment (`start1 = 1, end1 = 2, start2 = 1, end2 = 2`), and the gutter holds no checkbox glyph

#### Scenario: Diff view committed read-only side has syntax
- **WHEN** from the first of two windows `show(<second>, { path = "c.go", filetype = "go", left = { "package c" }, right = { "package c", "", "var x = 1" }, labels = { "parent", "commit" }, committed = true })` runs
- **THEN** the right buffer has `modifiable` off and `vim.treesitter.highlighter.active[<right buffer>]` is set with language `go`, like the left buffer
