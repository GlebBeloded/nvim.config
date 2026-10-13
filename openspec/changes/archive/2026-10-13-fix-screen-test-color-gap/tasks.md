# Tasks

**Goal:** Screen tests check the drawn color of every cell of a row against a design-render mask + legend, starting with the statusline in Normal and Insert mode.

**Architecture:** One child-side chunk in `tests/helpers.lua` primes `nvim__inspect_cell`, runs `redraw!`, reads the cells of the requested rows and resolves the legend groups with `nvim_get_hl`. The runner side compares the fields each group defines (design D3) and fails with an expected/actual mask diff (D4). The old `nvim_eval_statusline` helpers go away (D6).

**Spec:** `proposal.md`, `design.md` (D1–D6, Normal-mode mask). `skip_specs: true`: no spec delta; the two statusline screenshot scenarios keep their titles.

## Global Constraints

- NVIM v0.12.5; `nvim__inspect_cell(grid, row, col)` is 0-based and lives only in the one child-side chunk (D1).
- Legend values are exact highlight group names; masks hold no hex literals. The absolute colors the old `H.expect_colors` checks pinned (accents, chip) stay pinned as hex next to the mask (task 4): the mask alone compares cells with their own group, so a wrong palette color would pass.
- `.` and space in a mask mean `Normal` (shared with `make colorize`, D5).
- Mask rows are exactly `vim.o.columns` cells wide, counted with `vim.fn.strchars`.
- Reference screenshots in `tests/screenshots/` stay byte-identical (`git diff tests/screenshots` empty).
- LuaCATS types on every new function; small named functions, no long anonymous ones.
- No test is deleted or weakened: each `H.expect_colors` check is replaced by a full-row mask that covers it.

## Review Focus

- A mask row narrower or wider than the screen (or with a multibyte glyph miscounted) → fails naming the row and both widths, never compares shifted cells. Pinned in 1.4.
- A legend group that does not exist (typo, or created only on first draw and not drawn yet) → fails naming the letter and group, not a silent `Normal` fallback. Pinned in 1.4.
- Reading without the priming call returns stale attributes → the test must fail, proving the check is not color-blind. Pinned in 1.4.
- A wrong legend letter on one segment → the failure shows expected and actual mask rows aligned plus the first bad cell with `#rrggbb` values. Pinned in 1.4.
- Negative `row` (`-1` = statusline with `cmdheight=0`) must map to the same row `H.screen_rows(child, -1)` returns. Pinned by 1.1 asserting the same row the screenshot asserts.

---

## 1. Full-row color assertion, Normal-mode statusline

Scenarios: "statusline: statusline matches reference screenshot"

**Files:**
- Modify: `tests/helpers.lua` (new section after `M.screen_rows`)
- Modify: `tests/render/colorize.lua:14-15` (D5)
- Test: `tests/screen/statusline/test_statusline_screen.lua`

**Interfaces:**
- Produces:
  - `M.DEFAULT_GROUP: string` (`"Normal"`) and `M.UNMASKED: table<string, true>` (`.`, space).
  - `---@class test.CellAttrs` with `fg?`, `bg?`, `sp?: integer` and `bold?`, `italic?`, `underline?`, `undercurl?`, `strikethrough?`, `reverse?: boolean`.
  - `M.expect_screen_colors(child: MiniTest.child, row: integer, mask: string[], legend: table<string, string>)`: `row` as in `H.screen_rows`; checks rows `row .. row + #mask - 1`.
  - Child-side chunk `SCREEN_CELLS_LUA(first_row0: integer, count: integer, groups: string[])` → `{ cells: { text: string, attrs: test.CellAttrs }[][], hls: table<string, test.CellAttrs|vim.NIL> }`; maps `foreground`/`background`/`special` to `fg`/`bg`/`sp`.

- [x] **1.1 Failing test.** In the Normal case, keep `expect_statusline_screenshot("NORMAL")`, replace both `H.expect_colors(...)` calls with:

  ```lua
  H.expect_screen_colors(child, -1, {
  	"aaaaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccccceeeeewwwwtlttttt",
  }, {
  	a = "lualine_a_normal",
  	c = "lualine_c_normal",
  	e = "lualine_x_diagnostics_error_normal",
  	w = "lualine_x_diagnostics_warn_normal",
  	t = "StatuslineLangText",
  	l = "StatuslineLang_lua",
  })
  ```

  Leave the Insert case and the `DARK`/`CHIP` constants for task 2.
- [x] **1.2 Run it, expect FAIL.** `make test-screen FILE=tests/screen/statusline/test_statusline_screen.lua CASE="statusline matches reference screenshot"` → fails with `attempt to call field 'expect_screen_colors' (a nil value)`.
- [x] **1.3 Implement** in `tests/helpers.lua`:
  - `M.DEFAULT_GROUP`, `M.UNMASKED`; `colorize.lua` drops its local copies and uses `H.DEFAULT_GROUP` / `H.UNMASKED`.
  - `SCREEN_CELLS_LUA`: one `nvim__inspect_cell(1, 0, 0)` priming call, `redraw!`, then all cells of the rows, then `nvim_get_hl(0, { name = g, link = false })` for each legend group plus `Normal` (`vim.NIL` when `hlexists` is 0). Row conversion: `row < 0 → vim.o.lines + row`, else `row - 1`.
  - `local function check_width(mask: string[], columns: integer)`: `error` naming the mask row and both widths.
  - `local function cell_matches(attrs: test.CellAttrs, hl: test.CellAttrs, normal: test.CellAttrs): boolean`: D3 (fg/bg/sp only where `hl` sets them, missing actual colors filled from `normal`; the six flags always, absent = false).
  - `local function actual_mask(cells, legend, hls, normal): string[]`: first legend letter in sorted order that matches, `.` for Normal, else `?` (D4).
  - `M.expect_screen_colors`: undefined group → `error("legend <letter>: unknown highlight group [<group>]")`; on mismatch `error` with `expected:`/`actual:` rows one above the other plus column, character, group and expected/actual attrs as `#rrggbb`.
- [x] **1.4 Prove it is not color-blind (temporary edits, reverted after each).** Run the 1.2 command each time; each must FAIL with the stated message:
  1. swap `e` and `w` in the legend → mask diff, first bad cell at column 65 with `#rrggbb` values;
  2. comment out the priming call → mask diff (stale attrs);
  3. legend `l = "StatuslineLang_lux"` → `legend l: unknown highlight group [StatuslineLang_lux]`;
  4. drop the last mask character → width error naming 79 vs 80.
- [x] **1.5 Run, expect PASS.** Same command → PASS; `git diff --exit-code tests/screenshots` → exit 0; `make colorize FILE=openspec/changes/fix-screen-test-color-gap/design.md` prints the statusline render in color.
- [x] **1.6 Commit** `test(statusline): assert full-row colors of the Normal statusline with a mask`.

## 2. Insert-mode statusline, remove the old color helpers

Scenarios: "statusline: insert mode accent matches reference screenshot"

**Files:**
- Modify: `tests/screen/statusline/test_statusline_screen.lua`
- Modify: `tests/helpers.lua` (remove `test.Colors`, `STATUSLINE_HL_LUA`, `hex` unless 1.3 reuses it, `M.statusline_colors`, `M.expect_colors`)
- Modify: `docs/testing.md` ("Screenshots", last bullet)

**Interfaces:**
- Consumes: `H.expect_screen_colors` from task 1.

- [x] **2.1 Failing test.** In the Insert case replace the `H.expect_colors(...)` call with `H.expect_screen_colors(child, -1, mask, legend)`: the Normal mask with `INSERT` in place of `NORMAL` (same widths), legend `a = "lualine_a_insert"`, `c = "lualine_c_insert"`, `e = "lualine_x_diagnostics_error_insert"`, `w = "lualine_x_diagnostics_warn_insert"`, `t`/`l` unchanged. Delete `DARK` and `CHIP`.
- [x] **2.2 Run it.** `make test-screen FILE=tests/screen/statusline/test_statusline_screen.lua CASE="insert mode accent"`. If it fails, the failure names an unknown group or prints the actual mask: correct the legend to the groups lualine really draws in Insert mode, read from the printed actual mask and attrs. Never widen a letter to `?`, and the `a` segment must stay distinct from Normal's. Then PASS. Result: `lualine_c_insert` is undefined (the theme has no Insert `c` section), lualine draws `c` with `lualine_c_normal`; the legend uses that.
- [x] **2.3 Prove the accent is checked.** Temporarily set `a = "lualine_a_normal"` → FAIL with a mask diff at column 1. Revert.
- [x] **2.4 Remove the old helpers** (D6). `grep -rn "statusline_colors\|expect_colors\|test.Colors" tests docs` → no hits; `make types` → green.
- [x] **2.5 Docs.** Replace the `expect_colors` bullet in `docs/testing.md` "Screenshots": `H.expect_screen_colors(child, row, mask, legend)` checks drawn colors per cell in the design-render mask/legend notation, and the failure's actual mask is what to paste after an intended color change. No implementation details.
- [x] **2.6 Run, expect PASS.** `make test-screen FILE=tests/screen/statusline/test_statusline_screen.lua` → both cases PASS; `git diff --exit-code tests/screenshots` → exit 0.
- [x] **2.7 Commit** `test(statusline): assert Insert statusline colors with a mask; drop expect_colors`.

## 4. Pin the accent and chip colors (review: the mask alone is self-referential)

Scenarios: "statusline: statusline matches reference screenshot", "statusline: insert mode accent matches reference screenshot"

**Files:**
- Modify: `tests/helpers.lua`, `tests/screen/statusline/test_statusline_screen.lua`, `docs/testing.md`

**Interfaces:**
- Produces: `M.expect_hl_colors(child: MiniTest.child, group: string, expected: test.HlColors)` with `---@class test.HlColors` `fg?`, `bg?: string` (`#rrggbb`), `bold?: boolean`; compares only the keys `expected` sets against `nvim_get_hl(0, { name = group, link = false })`.

- [x] **4.1 Failing test.** Restore the removed pins next to the masks: Normal `lualine_a_normal` `{ fg = DARK, bg = "#a9b665", bold = true }` and `StatuslineLangText` `CHIP`; Insert `lualine_a_insert` `{ fg = DARK, bg = "#7daea3", bold = true }` and `CHIP`. Comment why Insert's `c` is `lualine_c_normal`.
- [x] **4.2 Run it, expect FAIL** (`expect_hl_colors` is nil).
- [x] **4.3 Implement** `M.expect_hl_colors`; failure names the group and both values.
- [x] **4.4 Prove it.** Temporarily set `insert = fg.green` in `lua/gleb/statusline/palette.lua` → the Insert case FAILS. Revert.
- [x] **4.5 Docs, run, commit** `test(statusline): pin accent and chip colors next to the masks`.

## 3. Gate

- [x] 3.1 `make check` green; `make trace` reports no orphans.
