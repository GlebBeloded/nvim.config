# Tasks

**Goal:** gitsigns' `┃` is the hunk sign the screen shows. mini.diff and impatient.nvim are gone.

**Spec:** `specs/git/spec.md` ("Gutter signs"), `design.md` (D1–D3, Proposed render).

**Approach:** one setup, `git_hunk(driver)` in `tests/render/cases.lua`, drives the temp repo for the
render case and both tests (a mini.test child satisfies `render.Driver`). An integration test pins the
gitsigns extmark, and a screen test pins what is drawn. Then the two plugin specs are deleted.

## Global Constraints

- The Proposed render in `design.md` is the expected screenshot text. Rows 2-5 at 60x8 only.
- The temp repo is deterministic: `git init`, then `git -c user.name=test -c user.email=test@example.com
  -c commit.gpgsign=false -c core.hooksPath=/dev/null commit`, committed `sample.lua`
  (`local M = {}`, ``, `return M`); the working copy adds `M.x = 1` as line 2. Git runs from the
  test side with `vim.system(...):wait()`, so the child's config does not affect it.
- LuaCATS types on new functions; small named functions, no long anonymous ones.
- No test is deleted or weakened.

## 1. gitsigns is the only hunk sign source

Scenarios: "git: Added line shows bar sign", "git: Added line sign matches reference screenshot"

**Files:**
- Modify: `tests/render/cases.lua` (`git-hunk` case and its named helpers)
- Create: `tests/integration/git/test_gitsigns.lua`, `tests/screen/git/test_git_screen.lua`,
  `tests/screenshots/tests-screen-git-test_git_screen.lua---git--added-line-sign-matches-reference-screenshot`
- Modify: `lua/gleb/plugins/plugins.lua` (delete the `echasnovski/mini.diff` spec, lines 246-252),
  `lazy-lock.json` (`"mini.diff"` entry)

- [x] **1.1 Failing tests.**
  - `tests/render/cases.lua`: `git_hunk(driver)` disables `lua_ls`, builds the temp repo above
    (small named helpers: `git(dir, args)`, `make_hunk_repo()`), runs `cd <dir> | edit sample.lua`,
    and waits until a `gitsigns_signs_` extmark exists on line 2 (`driver.wait(..., 3000)`, design
    Risks). Register it as `["git-hunk"]`.
  - `tests/integration/git/test_gitsigns.lua`: `start` = `start_config()` + `wait_very_lazy()` +
    the `git-hunk` setup with the child as driver.
    `T["git: Added line shows bar sign"]` reads the line-2 extmark of the `gitsigns_signs_`
    namespace (`details = true`) and asserts `vim.trim(sign_text) == "┃"`.
  - `tests/screen/git/test_git_screen.lua`: same `start` with `child.set_size(8, 60)` before the
    setup. `T["git: Added line sign matches reference screenshot"]` asserts
    1. the drawn text of row 2, column 1 equals `┃` (`H.screen_rows(child, 2).text[1][1]`); this is
       the check that fails today, since a missing reference would be created from the buggy screen;
    2. `H.expect_screen_colors(child, 2, mask, { a = "GitSignsAdd" })` with `a` on row 2 column 1 and
       `.` elsewhere (4 rows, 60 cells);
    3. `H.expect_screenshot(H.screen_rows(child, 2, 5))`.
- [x] **1.2 Run, expect FAIL.** `make test FILE=tests/screen/git/test_git_screen.lua` fails on step 1
  with `▒`. `make test FILE=tests/integration/git/test_gitsigns.lua` passes already: the extmark
  exists, it is only hidden (design Context). Both are kept: one pins the source, one the screen.
- [x] **1.3 Implement.** Delete the mini.diff spec from `plugins.lua` and its `lazy-lock.json` entry.
- [x] **1.4 Run, expect PASS.** The screen test passes and creates the reference screenshot (note
  "created"). Check its text block equals the Proposed render in `design.md` rows 2-5, cell by cell.
  `make render CASE=git-hunk COLUMNS=60 LINES=8 MONO=1` shows the same rows.
  `grep -rn "mini.diff\|MiniDiff" lua lazy-lock.json` → no hits. `make trace` lists both scenarios
  as tested, no orphans.
- [x] **1.5 Commit** `fix(git): remove mini.diff, whose signs hid gitsigns` (tests, reference
  screenshot, plugin removal).

**Notes (1.1-1.4):** mini.test children have no `set_size`; the screen test sets
`child.o.lines`/`child.o.columns`. Buffer line 2 is screen row 3 (row 1 is the bufferline), so step 1
reads row 3 and the `a` is in the second mask row. The mask also names the line-number and
treesitter groups the screen draws (`.` = Normal only fits blank cells), which pins more, not less.
`make trace` fails on orphans and reads only `openspec/specs`, so the "Gutter signs" delta is synced
into `openspec/specs/git/spec.md` now. The reference screenshot text equals the Proposed render
(mini.test text has no cursor glyph `█`).

## 2. Remove impatient.nvim

Scenarios: none (D2: dead plugin, no behaviour). The first step is the existing smoke test as the
baseline; its plugin load and healthchecks are the check that nothing depended on it.

**Files:**
- Modify: `lua/gleb/plugins/plugins.lua` (line 17), `lazy-lock.json` (`"impatient.nvim"` entry)

- [x] **2.1 Baseline.** `make smoke` is green before the edit.
- [x] **2.2 Implement.** Delete the `lewis6991/impatient.nvim` line and its lock entry.
  `grep -rn "impatient" lua init.lua lazy-lock.json` → no hits.
- [x] **2.3 Run, expect PASS.** `make smoke` green.
- [x] **2.4 Commit** `chore(plugins): remove impatient.nvim (superseded by vim.loader)`.

**Notes (2.1-2.3):** host load ~50 on 14 cores puts startup at the 400 ms budget both before and after
the edit (baseline 425.5 ms, after 412.0 ms in the same minute); smoke went green on retry (399.7 ms).
Only the startup budget is load-sensitive; plugin load and healthchecks pass on every run.

## 3. Gate

- [ ] 3.1 `make check` green.
