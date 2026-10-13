# Tasks

Layer: screen (visual-only layout, real config). File: `tests/screen/bufferline/test_bufferline_screen.lua`,
modelled on `tests/screen/statusline/test_statusline_screen.lua`. Shared setup: `child.start_config()`,
`child.wait_very_lazy()`, `child.set_size(12, 100)`, `cd` to a fresh `vim.fn.tempname()` dir, `enew`.
Helpers to add in the test file (small, named, LuaCATS-typed): `open_tree()` runs `Neotree filesystem` and
waits for a `neo-tree` window; `tabline_text()` returns row 1 as a string (`H.screen_rows(child, 1, 1)`);
`wait_for_tab(col)` waits until `[No Name]` starts at `col` in row 1 (bufferline redraws asynchronously).

## 1. Tabs start after the open tree

Scenarios: "tabs start after the open tree"

- [x] 1.1 Add `T["bufferline: tabs start after the open tree"]`: `open_tree()`, then assert columns 1-36 of
  `tabline_text()` are spaces and `[No Name]` starts at column 37 (byte-to-display-column via
  `vim.fn.strdisplaywidth` on the prefix, the row holds multibyte glyphs)
- [x] 1.2 Run `make test-screen CASE="bufferline: tabs start after the open tree"`; it fails (`[No Name]` at
  column 8, as in design.md Current)
- [x] 1.3 In `lua/gleb/bufferline.lua` change the offset `filetype` from `"NvimTree"` to `"neo-tree"`; keep
  `text = ""` and `padding = 1`, add no other option (user decision: no separator, default highlight)
- [x] 1.4 Re-run the same case; it passes

## 2. Reference screenshots of the tabline row

Scenarios: "tabline with tree open matches reference screenshot", "tabline without tree matches reference screenshot"

- [x] 2.1 Add `T["bufferline: tabline with tree open matches reference screenshot"]` (`open_tree()`,
  `wait_for_tab(37)`, `H.expect_screenshot(H.screen_rows(child, 1, 1))`) and
  `T["bufferline: tabline without tree matches reference screenshot"]` (`open_tree()`, `Neotree close`,
  `wait_for_tab(1)`, same screenshot call). Before any reference exists, check the tree-open case is red against the
  pre-fix code (the tree-closed case guards unchanged behaviour, so it is green there too). Against the
  pre-fix code: temporarily set the filetype back to `"NvimTree"`, run
  `make test-screen CASE="bufferline: tabline with tree open"` and confirm `wait_for_tab(37)` times out;
  restore `"neo-tree"` and delete any reference file that run created
- [x] 2.2 With the fix in place run `make screenshots` (only the two new references should appear); review
  them with `git status tests/screenshots`: the tree-open text row equals design.md Proposed row 1, the
  tree-closed one equals Current row 1. Commit both references
- [x] 2.3 `make test-screen` passes all three bufferline cases; `make trace` lists the three scenarios as
  tested with no orphans

## 3. Verify

Scenarios: all of the above

- [ ] 3.1 `make render CASE=neo-tree MONO=1 COLUMNS=100 LINES=12` row 1 matches design.md Proposed; colored
  `make render CASE=neo-tree COLUMNS=100 LINES=12` shows the offset in the tree's background
- [ ] 3.2 `make check` is green
