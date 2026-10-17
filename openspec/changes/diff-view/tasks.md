## 1. Fixture and pure layout

Scenarios: `diff: Diff view pads the side without lines`, `diff: Diff view folds unchanged lines with context 4`, `diff: Diff view maps the cursor across changes`, `diff: Diff view gutter shows both line numbers`

- [x] 1.1 Add the `diffgo` function (design Decision 12, verbatim) to `tests/fixtures/build.sh`, its name to the header and the `case` list, and the manifest keys to `fixtures.Manifest` in `tests/fixtures.lua`.
- [x] 1.2 Write `tests/unit/diff/test_layout.lua`, and see it fail. It covers:
  - rows, pads and folds for the three `controller.go` fragments;
  - `transferLine` for lines 58, 59 and left 65;
  - the gutter strings of rows 52, 53 and 58;
  - a change at line 1 (pad above the first line);
  - a file absent from `HEAD` (no checkbox).
- [x] 1.3 Add `lua/gleb/diff/view/layout.lua` (pure: no `vim.api`, typed), following design Decisions 4, 5 and 8.
- [x] 1.4 Run `make test FILE=tests/unit/diff/test_layout.lua` and see it pass

## 2. Open, windows and rendering

Scenarios: `diff: Diff view opens on the current file`, `diff: Diff view of an unchanged file opens nothing`, `diff: Diff view outside a repository opens nothing`, `diff: Diff view of a file absent from HEAD`, `diff: Diff view focuses an open view of the same file`, `diff: Diff view pads the side without lines`, `diff: Diff view gutter shows both line numbers`, `diff: Diff view folds unchanged lines with context 4`, `diff: Diff view highlights changed words`, `diff: Diff view highlight colours`

- [x] 2.1 Write these scenarios in `tests/integration/diff/test_view.lua` (fixture via `F.copy("diffgo", …)`), and see them fail
- [x] 2.2 Add:
  - `source.lua`, `windows.lua`, `render.lua`, `highlights.lua` and `view/init.lua` (`open`, `current`, `M.state`, `M.reset`, `M.config`), following design Decisions 2, 3, 5 and 6;
  - `lua/gleb/diff/init.lua`, required from `init.lua`.
- [x] 2.3 Add `diff.open_file` to `lua/gleb/diff/actions.lua` and register the list in `init.lua`'s `gleb.actions.setup` call.
- [x] 2.4 Run the file and see it pass

## 3. Folds, sync, navigation and editing

Scenarios: `diff: Diff view zo opens a fold in both windows`, `diff: Diff view zR toggles every fold`, `diff: Diff view scrolls both windows together`, `diff: Diff view maps the cursor across changes`, `diff: Diff view ]c and [c walk the changes`, `diff: Diff view ]c on the left side`, `diff: Diff view left window is read-only`, `diff: Diff view re-diffs after an edit`, `diff: Diff view marks an approximate comparison`

- [ ] 3.1 Write these scenarios in `tests/integration/diff/test_view_keys.lua`, and see them fail
- [ ] 3.2 Implement:
  - the fold actions;
  - `WinScrolled`/`CursorMoved` sync with its guard (Decision 7);
  - `]c`/`[c` (Decision 8);
  - the debounced re-diff with kept folds and the fallback label (Decision 9);
  - the view actions with `plugin = "gleb-diff"`, the adapter `lua/gleb/actions/adapters/gleb_diff.lua`, and the keys in `settings/keymap.json`.
- [ ] 3.3 Run the file and see it pass

## 4. Close, embedding and keys

Scenarios: `diff: Diff view q closes the tab page`, `diff: Diff view closes with either window`, `diff: Diff view restores a shadowed buffer mapping`, `diff: Diff view shows in a given window without focus`, `diff: Diff view ]f calls the next-file hook`, `diff: Diff view ]f without a list keeps the view`, `diff: Diff view mappings come from diff actions`, `diff: Diff view uses a reassigned key on reopen`

- [x] 4.1 Write these scenarios in `tests/integration/diff/test_view_close.lua`, and see them fail
- [x] 4.2 Implement the one cleanup path (Decision 10), `show(win, spec)` and `close`, and `diff.next_file` with `on_next_file`.
- [x] 4.3 Run the file and see it pass, then `make test CAPS=actions,find-action,git` to confirm that the existing ownership and differ scenarios still pass.

## 5. Screen

Scenarios: `diff: Diff view matches the approved render`

- [x] 5.1 Write `tests/screen/diff/test_view.lua`, and see it fail:
  - a `100x30` child on `diffgo`;
  - `H.expect_screenshot` of rows 2–29;
  - `H.expect_screen_colors` from row 2 with the mask and legend of "Proposed D", with the syntax-coloured code cells masked from the real capture.
- [x] 5.2 Make it pass. Compare `make render` (add a `diff-view` case to `tests/render/cases.lua`) with `renders/proposed_view.ansi`.
- [x] 5.3 Update `docs/architecture.md`:
  - add or extend the module-map row for `diff/` (engine and viewer, spec `diff`);
  - add a key-decisions line: the right pane is the real buffer, with window-scoped decorations.

  Then run `make check`.

## Agent decisions

- Layout rows carry optional 1-based `left` and `right` lines, with fold metadata in the same ordered list, so rendering and synchronization can consume one model.
- Public helpers use snake-case names (`transfer_line`, `change_at_line`) to follow the repository's Lua naming convention.
- Untracked files derive their repository-relative path after the required `ls-files` call returns empty, so `git show` can represent an absent HEAD side.
- Diff windows detach nvim-ufo before creating manual folds, because its asynchronous provider otherwise replaces the paired ranges on the real file buffer.
- Embedded views save the host buffer and window-local options, so their one cleanup path restores the hosting area exactly.
- Shadowed mappings are restored with their full `maparg()` dictionaries, preserving callbacks and mapping options.
- The left scratch buffer inherits the real buffer's tab width so identical source stays visually aligned.
- The rendered checkbox uses the approved U+F0131 Nerd Font glyph; prose keeps `☐` as its stand-in.
- A virtual delete gutter draws `╱` in its last cell so the approved padding row remains continuous.

## Stuck

Task 3 is left unticked with its failing integration scenarios. The scroll-sync probe printed:

```text
left = { cursor = 61, topline = 52 }
right = { cursor = 62, topline = 52 }
```

- Attempt 1 added paired fold actions, cursor and scroll autocmds, navigation mappings, debounced re-diff, fallback labeling and the `gleb-diff` adapter. Eight scenarios passed, but `62zt` left the right topline at 52 instead of 62 because the peer viewport was clamped around its old cursor and echoed back.
- Attempt 2 transferred the peer cursor before `winrestview` and consumed one deferred peer `WinScrolled` event. The same assertion still reported right topline 52 instead of 62.

The complete second production attempt is saved in `artifacts/runs/20817010-c87a-4cc5-95db-e0c0d18840d7/stuck-attempt.diff`; production edits were reverted and the red test remains.
