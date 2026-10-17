## ADDED Requirements

### Requirement: Diff view revert
`diff.apply` SHALL replace the right buffer's lines of the change at the cursor with the change's left lines, as one undo step, without writing the file. The view then re-compares at once. It works in either window. The change at the cursor is the one whose range on the cursor's side contains the cursor line, or whose empty range lies just above it. Off a change, it SHALL do nothing.

#### Scenario: Diff view do reverts a changed line
- **WHEN** the right cursor of the `controller.go` view (`diffgo` fixture) is on line 53 and `do` is pressed in normal mode
- **THEN** right line 53 is `\t\treturn err`, the buffer is modified and not written, and the view has two fragments

#### Scenario: Diff view dp reverts a deletion from the left window
- **WHEN** the left cursor of the `controller.go` view is on line 65 and `dp` is pressed in normal mode
- **THEN** right line 66 is `\tc.stats.LastRun.Touch()`, right line 67 is `\treturn nil`, and the left window is still current

#### Scenario: Diff view reverts an insertion as one undo step
- **WHEN** `do` is pressed in normal mode on right line 58 of the `controller.go` view, and then `u`
- **THEN** after `do` the right buffer has 150 lines and no `c.stats.Skipped.Inc()` line. After `u` it has 151 lines again and three fragments.

#### Scenario: Diff view revert off a change does nothing
- **WHEN** `do` is pressed in normal mode on right line 50 of the `controller.go` view
- **THEN** the right buffer's `changedtick` is unchanged and nothing is notified

### Requirement: Diff view include checkbox
Each change of a file present in `HEAD` SHALL show its index state in its checkbox cell, comparing `HEAD`, the index and the right buffer:
- `☑` (`U+F0132`) when the index holds the change's right lines in place of its left lines;
- `☐` (`U+F0131`) when the index holds its left lines;
- `◪` (`U+F0856`) otherwise.

The states SHALL refresh after each comparison and each toggle.

#### Scenario: Diff view checkboxes follow the index
- **WHEN** `d.txt` of a fresh copy of the `dirty` fixture (line 1 staged, line 3 not) is edited and `diff.open_file` runs
- **THEN** the view has two changes: line 1's checkbox is `☑` and line 3's is `☐`

#### Scenario: Diff view checkbox of a partly staged change
- **WHEN** `<Space>` is pressed in normal mode on right line 53 of the `controller.go` view, right line 53 is then changed to `\t\treturn wrap(err, id)` without writing, and 300 ms pass
- **THEN** the checkbox of the change on line 53 is `◪`

### Requirement: Diff view hunk staging
`diff.toggle_include` SHALL unstage the change at the cursor when it is `☑`, and stage it otherwise. It builds the new index text for that change only. It SHALL pipe the `vim.text.diff` patch from the current to the new index text to `git apply --cached --whitespace=nowarn -`, run as an argument list in the repository root, so that other staged changes stay. A failure SHALL notify `Stage failed: <stderr>` or `Unstage failed: <stderr>` at ERROR.

#### Scenario: Diff view Space stages one change
- **WHEN** `<Space>` is pressed in normal mode on right line 53 of the `controller.go` view
- **THEN**
  - `git diff --cached -U0` changes exactly `-\t\treturn err` to `+\t\treturn wrap(err)`;
  - `git diff -U0` still holds the insertion of line 58 and the deletion of old line 65;
  - the checkbox on line 53 is `☑`.

#### Scenario: Diff view Space unstages a staged change
- **WHEN** `<Space>` is pressed twice in normal mode on right line 53 of the `controller.go` view
- **THEN** `git diff --cached` is empty and the checkbox on line 53 is `☐`

#### Scenario: Diff view stages an insertion and a deletion separately
- **WHEN** `<Space>` is pressed in normal mode on right line 58 and then on right line 66 of the `controller.go` view
- **THEN** `git diff --cached -U0` adds exactly `\t\tc.stats.Skipped.Inc()` and removes exactly `\tc.stats.LastRun.Touch()`, and line 53 is still unstaged

#### Scenario: Diff view reports a staging failure
- **WHEN** `.git/index.lock` exists in the `diffgo` copy and `<Space>` is pressed in normal mode on right line 53 of the `controller.go` view
- **THEN** a notification starting with `Stage failed: ` is shown at ERROR, `git diff --cached` is empty, and the checkbox stays `☐`

#### Scenario: Diff view staged change matches the approved render
- **WHEN** a `100x30` screen opens the `controller.go` view of a fresh `diffgo` copy and `<Space>` is pressed in normal mode on right line 53
- **THEN** screen rows 2–29 match design.md "Proposed E1 — first change staged", text and colour mask

### Requirement: Diff view moved blocks
The view SHALL request moves from the engine. Each move's left lines and right lines SHALL be tinted `DiffViewMoved` instead of their add or delete tint. The strip SHALL read `→<first right line>` on the original end's first row and `←<first left line>` on the moved end's first row. `diff.jump_move` on a line of either end SHALL focus the other window, on the other end's first line. Off a move, it SHALL do nothing.

#### Scenario: Diff view marks both ends of a moved block
- **WHEN** `internal/user/ids.go` of the `diffgo` fixture is edited and `diff.open_file` runs
- **THEN**
  - left lines 3–9 and right lines 11–17 carry `DiffViewMoved` line highlights;
  - the gutter strip reads `→11` on the row of left line 3, and `←3` on the row of right line 11.

#### Scenario: Diff view gm jumps between the ends of a move
- **WHEN** the right cursor of the `ids.go` view is on line 13, `gm` is pressed in normal mode, and then `gm` again
- **THEN** after the first press the left window is current with its cursor on line 3, and after the second the right window is current with its cursor on line 11

#### Scenario: Diff view gm off a move does nothing
- **WHEN** `gm` is pressed in normal mode on right line 1 of the `ids.go` view
- **THEN** the right window is still current and its cursor is still on line 1

#### Scenario: Diff view moved block matches the approved render
- **WHEN** a `100x30` screen edits `internal/user/ids.go` of a fresh `diffgo` copy, `diff.open_file` runs and the right cursor moves to line 11
- **THEN** screen rows 2–29 match design.md "Proposed E2 — moved block", text and colour mask

### Requirement: Diff view whitespace policy
The actions `diff.ignore_none`, `diff.ignore_trim`, `diff.ignore_whitespaces` and `diff.ignore_whitespaces_chunks` SHALL set the comparison policy (`default`, `trim_whitespaces`, `ignore_whitespaces`, `ignore_whitespaces_chunks`) for every open and later view, and re-compare the open ones. They are radio toggles, available while a diff view is in the current tab page, and unbound. The choice SHALL persist in `stdpath("state")/diff.json`.

#### Scenario: Diff view trim policy hides a trailing space
- **WHEN** a space is appended to right line 50 of the `controller.go` view, 300 ms pass, and `diff.ignore_trim` runs
- **THEN** before the action there is a change at line 50; after it there is none, and the view has its three original fragments

#### Scenario: Diff view whitespace policy persists
- **WHEN** `diff.ignore_whitespaces` runs in a view, Neovim restarts with the same state directory, and a view opens
- **THEN** `diff.json` holds `"policy":"ignore_whitespaces"`, the new view compares with that policy, and Find Action shows "Ignore Whitespaces" as on

### Requirement: Diff view highlight mode
The actions `diff.highlight_words`, `diff.highlight_split`, `diff.highlight_chars`, `diff.highlight_lines` and `diff.highlight_none` SHALL set the engine mode (`by_word` default, `by_word_split`, `by_char`, `by_line`, `none`) for every open and later view, re-compare the open ones, and persist it in `diff.json`. They are unbound radio toggles, available while a view is current. With `none`, the view SHALL show both texts without tints, padding, folds or gutter marks.

#### Scenario: Diff view line mode drops word highlights
- **WHEN** `diff.highlight_lines` runs while the `controller.go` view is open
- **THEN** neither buffer has a `DiffViewWord` extmark, and line 53 still has its `DiffViewChange` line highlight in both windows

#### Scenario: Diff view no-highlight mode shows plain texts
- **WHEN** `diff.highlight_none` runs while the `controller.go` view is open, and then `]c` is pressed in normal mode in the right window
- **THEN**
  - neither window has a closed fold, a padding row or a `DiffView*` line highlight;
  - the gutter has no `»`;
  - the cursor did not move.

#### Scenario: Diff view highlight mode persists
- **WHEN** `diff.highlight_chars` runs, Neovim restarts with the same state directory, and a view opens
- **THEN** `diff.json` holds `"highlight":"by_char"` and Find Action shows "Highlight Symbols" as on

### Requirement: Diff view action colours
The groups SHALL derive from the gruvbox-material palette and be redefined on `ColorScheme`:
- `DiffViewMoved` has `bg` = `util.blend(aqua, bg0, 0.72)`;
- `DiffViewGutterMoved` has `fg` `grey1` on that `bg`;
- `DiffViewMovedMarker` has `fg` aqua on that `bg`.

#### Scenario: Diff view move colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `DiffViewMoved` has `bg` `util.blend(aqua, bg0, 0.72)`, and `DiffViewMovedMarker` has `fg` aqua and the same `bg`
