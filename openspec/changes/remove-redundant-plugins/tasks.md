# Tasks

**Goal:** gitsigns' `┃` is the hunk sign the screen shows. mini.diff and impatient.nvim are gone.

**Spec:** `specs/git/spec.md` ("Gutter signs"), `design.md` (D1–D3, Proposed render).

## Global Constraints

- The Proposed render in `design.md` is the expected screenshot text. Rows 2-5 at 60x8 only.
- The temp repo is deterministic: `git init`, a fixed author and message, committed `sample.lua`
  (`local M = {}`, ``, `return M`), working copy adds `M.x = 1` as line 2.
- LuaCATS types on new functions; small named functions, no long anonymous ones.
- No test is deleted or weakened.

## 1. gitsigns is the only hunk sign source

Scenarios: "git: Added line sign matches reference screenshot", "git: Added line shows bar sign"

**Files:**
- Create: `tests/screen/git/test_git_screen.lua`, `tests/screenshots/<generated name>`
- Modify: `tests/render/cases.lua` (`git-hunk` case, same setup as the test)
- Modify: `lua/gleb/plugins/plugins.lua` (remove the `echasnovski/mini.diff` spec), `lazy-lock.json`

- [ ] **1.1 Failing test.** `tests/screen/git/test_git_screen.lua`: child at 60x8,
  `start_config()` + `wait_very_lazy()`, `lua_ls` disabled, temp repo as above, `cd` + `edit sample.lua`.
  Wait until a `gitsigns_signs_` extmark exists on line 2. Then:
  - `T["git: Added line shows bar sign"]` asserts the sign text `┃` on that extmark.
  - `T["git: Added line sign matches reference screenshot"]` runs `H.expect_screenshot(H.screen_rows(child, 2, 5))`.
  Write the reference screenshot by hand from the Proposed render (or run `make screenshots` and
  check that its text equals the render).
- [ ] **1.2 Run it, expect FAIL.** `make test-screen FILE=tests/screen/git/test_git_screen.lua`. The
  screenshot case fails with `▒` in row 2, column 1. The extmark case passes, as design Context
  explains.
- [ ] **1.3 Implement.** Remove the mini.diff spec from `plugins.lua` and its `lazy-lock.json` entry.
  Add the `git-hunk` render case.
- [ ] **1.4 Run, expect PASS.** Same command passes. `make render CASE=git-hunk COLUMNS=60 LINES=8 MONO=1`
  rows 2-5 equal the Proposed render. `grep -rn "mini.diff\|MiniDiff" lua lazy-lock.json` → no hits.
- [ ] **1.5 Commit** `fix(git): remove mini.diff, whose signs hid gitsigns`.

## 2. Remove impatient.nvim

Scenarios: none (D2: dead plugin, no behaviour). Covered by the existing smoke test.

**Files:**
- Modify: `lua/gleb/plugins/plugins.lua`, `lazy-lock.json`

- [ ] **2.1 Baseline.** `make smoke` is green before the edit.
- [ ] **2.2 Implement.** Remove the `lewis6991/impatient.nvim` line and its lock entry.
  `grep -rn "impatient" lua lazy-lock.json` → no hits.
- [ ] **2.3 Run, expect PASS.** `make smoke` green.
- [ ] **2.4 Commit** `chore(plugins): remove impatient.nvim (superseded by vim.loader)`.

## 3. Gate

- [ ] 3.1 `make check` green; `make trace` reports no orphans for the new scenario.
