## ADDED Requirements

### Requirement: Diff view opens the current file
`diff.open_file` SHALL compare the current file at `HEAD` (left) with the current buffer's lines (right) in a new tab page. The left window SHALL hold a read-only scratch buffer with filetype `gleb-diff`. The right window SHALL show the file's own buffer, with the cursor on the first change. A file without changes SHALL notify `No changes` (INFO). A buffer outside a git work tree SHALL notify `Not in a git repository` (WARN). In both cases nothing opens.

#### Scenario: Diff view opens on the current file
- **WHEN** `internal/user/controller.go` of a fresh copy of the `diffgo` fixture is the current buffer and `diff.open_file` runs
- **THEN** there are 2 tab pages and the current one has exactly two windows:
  - the left buffer has filetype `gleb-diff` and holds the lines of `git show HEAD:internal/user/controller.go`;
  - the right window shows the buffer that was current, unchanged;
  - the cursor is in the right window on line 53.

#### Scenario: Diff view of an unchanged file opens nothing
- **WHEN** `git checkout -- internal/user/controller.go` has run in a copy of the `diffgo` fixture, the file is edited and `diff.open_file` runs
- **THEN** `No changes` is notified at INFO and there is still 1 tab page

#### Scenario: Diff view outside a repository opens nothing
- **WHEN** a file in a temporary directory outside any git work tree is the current buffer and `diff.open_file` runs
- **THEN** `Not in a git repository` is notified at WARN and there is still 1 tab page

#### Scenario: Diff view of a file absent from HEAD
- **WHEN** `internal/user/new.go` is created with the lines `package user`, ``, `var x = 1` in a copy of the `diffgo` fixture, edited, and `diff.open_file` runs
- **THEN** the left buffer is empty and `require("gleb.diff.view").current().fragments` is `{ { start1 = 0, end1 = 0, start2 = 0, end2 = 3 } }`

#### Scenario: Diff view focuses an open view of the same file
- **WHEN** the view of `internal/user/controller.go` is open, `gt` returns to the first tab page and `diff.open_file` runs again there
- **THEN** there are still 2 tab pages and the second, holding the view, is current

### Requirement: Diff view layout
The view SHALL split its area into a left window 40% of the width (rounded down) and a right window. The right window's `statuscolumn` SHALL be a 16-cell gutter: the apply arrow `»` and the include checkbox `☐` on the first row of each change, the left and right line numbers, and a 5-cell change strip. A side with no lines for a change SHALL show `╱` padding rows, so rows stay aligned. Changed rows SHALL be tinted by kind. The winbars SHALL read `<short hash> · HEAD` and `Your version`.

#### Scenario: Diff view matches the approved render
- **WHEN** a `100x30` screen edits `internal/user/controller.go` of a fresh copy of the `diffgo` fixture and `diff.open_file` runs
- **THEN** screen rows 2–29 match design.md "Proposed D — aligned diff of the current file", text and colour mask

#### Scenario: Diff view pads the side without lines
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** the left window shows exactly one `╱` row, between old lines 57 and 58. The right window shows exactly one, between new lines 65 and 66. With every fold open, both windows span the same number of screen rows.

#### Scenario: Diff view gutter shows both line numbers
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** the right window's status column:
  - reads `  52       52   ` on new line 52, the unchanged row;
  - reads `» 53       53 ☐ ` on new line 53, the changed row (with Nerd Font glyphs for `☐`);
  - starts with `»╱╱╱╱` on new line 58, the inserted row.

### Requirement: Diff view folds
Each unchanged run SHALL keep up to 4 lines next to each neighbouring change. When at least 2 more lines remain, they SHALL fold into one closed fold in each window. On the left, the fold row reads `~~ <n> unchanged lines ~~~` to the window's edge; on the right, it is `~` to the edge. `diff.expand_fold` SHALL open the fold under the cursor in both windows. `diff.toggle_folds` SHALL open every fold when any is closed, and otherwise close them all.

#### Scenario: Diff view folds unchanged lines with context 4
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** each window has exactly two closed folds:
  - lines 1–48, shown as `~~ 48 unchanged lines ~~…` on the left;
  - lines 70–151 of both sides, shown as `~~ 82 unchanged lines ~~…`.

  Lines 49–69 of the left and right buffers are not folded.

#### Scenario: Diff view zo opens a fold in both windows
- **WHEN** the cursor is on line 1 of the right window of the `controller.go` view and `zo` is pressed in normal mode
- **THEN** `foldclosed(1)` is `-1` in both windows, and lines 70–151 are still folded in both

#### Scenario: Diff view zR toggles every fold
- **WHEN** `zR` is pressed in normal mode in the right window of the `controller.go` view, and then pressed again
- **THEN** after the first press neither window has a closed fold, and after the second press both have their two folds closed again

### Requirement: Diff view word highlights
Inside a changed fragment, the view SHALL highlight each side's inner ranges with `DiffViewWord`, as `compare_lines` gives them with the `by_word` mode and mapped with `inner_columns`. A zero-width range and a pure insertion or deletion SHALL get no word highlight.

#### Scenario: Diff view highlights changed words
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** the right buffer's line 53 (`\t\treturn wrap(err)`) has `DiffViewWord` exactly on byte columns 9–13 and 17. The left buffer's line 53 and right line 58 have none.

### Requirement: Diff view synchronized scrolling
Scrolling either window SHALL scroll the other so that the same aligned row is at the top, and keep the same `leftcol`. Moving the cursor in one window SHALL put the other window's cursor on the transferred line. That line is the same offset past the start of the enclosing unchanged run or change, clamped to the change's end (IntelliJ `BaseSyncScrollable.transferLine`).

#### Scenario: Diff view scrolls both windows together
- **WHEN** every fold of the `controller.go` view is open and `62zt` is typed in normal mode in the right window
- **THEN** the right window's topline is 62 and the left window's topline is 61

#### Scenario: Diff view maps the cursor across changes
- **WHEN** the right cursor of the `controller.go` view moves to line 58, then to line 59, and then the left cursor moves to line 65
- **THEN** the left cursor is on line 58 after each of the first two moves, and the right cursor is then on line 66

#### Scenario: Layout maps cursor rows across changes
- **WHEN** the layout for the three `controller.go` changes transfers right lines 58 and 59 and left line 65
- **THEN** they map to left lines 58 and 58 and right line 66, and left line 58 belongs to change 2

### Requirement: Diff view change navigation
`diff.next_change` and `diff.prev_change` SHALL move the cursor in the current window to the first line of the next or previous change on that window's side. For a side without lines, that is the line just below the gap. There is no wrap: at the last or first change, the cursor stays.

#### Scenario: Diff view ]c and [c walk the changes
- **WHEN** the view of `controller.go` opens (right cursor on line 53) and `]c` is pressed three times, then `[c` once, in normal mode
- **THEN** the right cursor goes to lines 58, 66 and 66, then 58

#### Scenario: Diff view ]c on the left side
- **WHEN** the left cursor of the `controller.go` view is on line 53 and `]c` is pressed twice in normal mode
- **THEN** the left cursor goes to line 58 and then to line 65

### Requirement: Diff view editing
The left buffer SHALL NOT be modifiable. Each change to the right buffer SHALL re-compare after a 150 ms debounce and redraw tints, padding, folds and gutter. The cursor and the folds opened by the user SHALL stay. When the engine falls back (`too_big` or `timed_out`), the right winbar SHALL read `Your version · approximate diff`.

#### Scenario: Diff view left window is read-only
- **WHEN** `x` is pressed in normal mode on line 53 of the left window of the `controller.go` view
- **THEN** the left buffer's lines are unchanged and its `modifiable` option is off

#### Scenario: Diff view re-diffs after an edit
- **WHEN** `dd` is pressed in normal mode on right line 58 of the `controller.go` view, 300 ms pass, `u` is pressed and 300 ms pass
- **THEN**
  - after `dd`, the view has two fragments (old 53 changed, old 65 deleted) and the left window has no padding row;
  - after `u`, it has the three original fragments again.

#### Scenario: Diff view marks an approximate comparison
- **WHEN** `require("gleb.diff.view").config.timeout_ms` is `0` and `diff.open_file` runs on `controller.go` of the `diffgo` fixture
- **THEN** the right window's winbar reads `Your version · approximate diff`

### Requirement: Diff view closing
`diff.close` in either window SHALL close the view and return to the window that was current before it opened. A view opened by `diff.open_file` closes its tab page. Closing either window by other means SHALL close the other window too. On close, the view SHALL remove its buffer-local mappings, extmarks and autocmds from the file buffer and restore any buffer-local mapping it shadowed.

#### Scenario: Diff view q closes the tab page
- **WHEN** `q` is pressed in normal mode in the right window of the `controller.go` view
- **THEN**
  - there is 1 tab page and the current window shows `controller.go`;
  - that buffer has no buffer-local `]c` mapping and no extmark in the view's namespace.

#### Scenario: Diff view closes with either window
- **WHEN** `:quit` is run in the left window of the `controller.go` view
- **THEN** there is 1 tab page and no window shows a `gleb-diff` buffer

#### Scenario: Diff view restores a shadowed buffer mapping
- **WHEN** `controller.go` has a buffer-local normal-mode `q` mapping, and its view is opened and then closed with `q`
- **THEN** the buffer's `q` mapping is the one it had before the view opened

#### Scenario: Diff view keys stay native outside view windows
- **WHEN** the `controller.go` view is open, lines 1–10 are manually folded in its original window, which also had a buffer-local `]c` mapping, and `zo` then `]c` are pressed there
- **THEN** the manual fold opens and the buffer-local `]c` mapping runs

### Requirement: Diff view embedding
`require("gleb.diff.view").show(win, spec)` SHALL show a view in the area of window `win`, without changing the current window or the tab page count. `spec` holds `path`, `left` (lines), `right` (a buffer or lines), `labels` and an optional `on_next_file`. A later `show` on the same area SHALL replace the view. `diff.next_file` SHALL call `on_next_file`; without one, it does nothing.

#### Scenario: Diff view shows in a given window without focus
- **WHEN** a second window is open, and from the first one `show(<second>, { path = "b.txt", left = { "a", "b" }, right = { "a", "c" }, labels = { "HEAD", "Working tree" } })` runs
- **THEN**
  - the tab page count is unchanged and the first window is still current;
  - the second window's area holds two windows, with lines `a`, `b` on the left and `a`, `c` on the right;
  - the left winbar reads ` HEAD`.

#### Scenario: Diff view ]f calls the next-file hook
- **WHEN** a view shown with an `on_next_file` callback has its right window focused and `]f` is pressed in normal mode
- **THEN** the callback ran once

#### Scenario: Diff view ]f without a list keeps the view
- **WHEN** `]f` is pressed in normal mode in the right window of the `controller.go` view opened by `diff.open_file`
- **THEN** the view, its buffers and the cursor are unchanged

### Requirement: Diff view keys
The view SHALL set its mappings buffer-local (`nowait`) in both windows. They come from the registered `diff.*` actions whose `plugin` is `gleb-diff`, with their `settings/keymap.json` assignments at open time. `diff.open_file` SHALL be a registered action without an assignment.

#### Scenario: Diff view mappings come from diff actions
- **WHEN** the `controller.go` view is open after `VeryLazy`
- **THEN** every buffer-local mapping of both windows invokes the `diff.*` action that `settings/keymap.json` assigns to its lhs. `diff.open_file` has no lhs.

#### Scenario: Diff view uses a reassigned key on reopen
- **WHEN** `diff.close` is reassigned from `q` to `Q` while a view is open, and the view is closed and opened again
- **THEN** `Q` closes the reopened view and `q` is not mapped in its windows

### Requirement: Diff view colours
The view's groups SHALL derive from the gruvbox-material palette:
- `DiffViewAdd`, `DiffViewChange` and `DiffViewDelete` have `bg` = `util.blend(<green|blue|red>, bg0, 0.72 | 0.72 | 0.74)`;
- `DiffViewWord` has `bg` = `util.blend(blue, bg0, 0.5)`;
- `DiffViewGutter*` have `fg` `grey1` on their kind's `bg`;
- `DiffViewArrow*` have `fg` green, blue or red.

The groups SHALL be redefined on `ColorScheme`.

#### Scenario: Diff view highlight colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN**
  - `DiffViewChange` has `bg` `util.blend(blue, bg0, 0.72)` and `DiffViewWord` has `bg` `util.blend(blue, bg0, 0.5)`;
  - `DiffViewGutterAdd` has `fg` `grey1` and `bg` `util.blend(green, bg0, 0.72)`;
  - `DiffViewArrowDelete` has `fg` red;
  - `DiffViewPadding` has `fg` `bg3` and `DiffViewFold` has `fg` `bg5`.
