# Tasks

All integration cases go in `tests/integration/keymaps/test_keymaps.lua` (real config, `start()` and
`two_windows`/`callback_is` helpers already there); the screen case in a new
`tests/screen/keymaps/test_keymaps_screen.lua`. Run one case with
`CASE="<name>" make test-integration`; `make quick` before each commit.

## 1. Area-action descs via one map helper

Scenarios: "Every core mapping has an area-action desc", "Core mappings are noremap and silent".

- [x] 1.1 Add the failing case `T["keymaps: Every core mapping has an area-action desc"]`: a list of
  `{ mode, lhs }` pairs exactly as in the scenario (normal, `i` `jk`, `x` visual maps), read
  `vim.fn.maparg(lhs, mode, false, true).desc` in the child for each, and `eq` the list of pairs whose
  desc is nil or does not match `^%u[%w ]*: %S.*$` to `{}` (one assert, every offender in the diff).
- [x] 1.2 Run `CASE="keymaps: Every core mapping" make test-integration`: fails, listing all 38 maps.
- [x] 1.3 In `lua/gleb/keymaps.lua`, replace `opts`/`kmap` with a LuaCATS-typed local
  `map(mode, lhs, rhs, desc)` calling `vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })`
  (`---@param mode string|string[]`, `---@param rhs string|function`). Convert every call; descs use
  the areas of design.md (`Window`, `Jump`, `Buffer`, `Edit`, `Tree`, `Git`, `Search`, `LSP`,
  `Diagnostic`). Do not change any rhs or mode here.
- [x] 1.4 Both scenario cases pass, plus the whole file (`FILE=tests/integration/keymaps/test_keymaps.lua make test`);
  `make quick` green. Commit.

## 2. `<Cmd>` for the normal-mode Ex maps

Scenarios: "Command maps do not enter the command line"; regression: "Increase height",
"Decrease height", "Decrease width", "Increase width".

- [x] 2.1 Add the failing case `T["keymaps: Command maps do not enter the command line"]`:
  `two_windows("split")`, create a `CmdlineEnter` autocmd in the child that increments
  `vim.g.cmdline_enters` (start 0), `type_keys` `<C-Up>`, `<C-Down>`, `<C-Left>`, `<C-Right>`, then
  `eq(child.g.cmdline_enters, 0)`.
- [x] 2.2 Run it: fails with count 4.
- [x] 2.3 Change the rhs of `<C-Up>`/`<C-Down>`/`<C-Left>`/`<C-Right>` to
  `<Cmd>resize ±2<CR>` / `<Cmd>vertical resize ±2<CR>`, `<A-g>` to `<Cmd>Differ<CR>`, `<A-F>` to
  `<Cmd>Telescope live_grep<CR>`. Leave the visual `:move` maps unchanged (they need `'<`/`'>`).
- [x] 2.4 The new case and the four resize cases pass; `make quick` green. Commit.

## 3. `<C-q>` closes via vim-bbye `Bdelete`

Scenarios: "Close buffer keeps split layout", "Close modified buffer is refused"; regression:
"Close current buffer".

- [x] 3.1 Add the failing case `T["keymaps: Close buffer keeps split layout"]`: edit `<dir>/a`, then
  `<dir>/b`, `vsplit`, press `<C-q>`; assert `#nvim_tabpage_list_wins(0) == 2`, neither window's
  buffer is `b`, and `buflisted(b) == 0`.
- [x] 3.2 Add the case `T["keymaps: Close modified buffer is refused"]`: edit `<dir>/a`, then
  `<dir>/b` with `setlocal filetype=gitcommit` (the auto-save `condition` skips it, so it stays
  modified), set lines, press `<C-q>`; assert the current buffer is still `b`, listed, and
  `modified`. It passes today (`:bdelete` refuses too); it guards the `Bdelete` (no `!`) choice.
- [x] 3.3 Run both: "keeps split layout" fails (one window left).
- [x] 3.4 Map `<C-q>` to `<Cmd>Bdelete<CR>` (desc `Buffer: Close`).
- [x] 3.5 Both cases and "Close current buffer" pass; `make quick` green. Commit.

## 4. Reference screenshot of `<C-q>` in a split

Scenario: "Close buffer in split matches reference screenshot".

- [x] 4.1 Add a `close-buffer-split` case to `tests/render/cases.lua` (named setup function, like
  `lua_file`): `lua_ls` disabled, a temp dir with `init.lua` = `require("sample")` and `sample.lua` =
  `local M = {}`, ``, `return M`; `edit init.lua | edit sample.lua | vsplit`, wait for
  `filetype == "lua"`, then `type_keys("<C-q>")` and wait until no window shows `sample.lua`.
- [x] 4.2 Add `tests/screen/keymaps/test_keymaps_screen.lua` with
  `T["keymaps: Close buffer in split matches reference screenshot"]`: a child sized 12x80
  (`child.set_size(12, 80)`), the render case's setup driven by the child, then
  `H.expect_screenshot(child.get_screenshot())`. Delete any old reference, run it, then
  `make screenshots`.
- [x] 4.3 Check the reference's text block equals the approved Proposed render in `design.md`
  (also `make render CASE=close-buffer-split MONO=1 COLUMNS=80 LINES=12`). If they differ, stop and
  escalate; do not edit the design render.
- [x] 4.4 `make test-screen` passes; commit the reference with the test.

## 5. Delete the dead debugging keybindings

Scenario: "Smart-splits resize keys are not remapped".

- [x] 5.1 Add `T["keymaps: Smart-splits resize keys are not remapped"]`: for `<A-H>`, `<A-J>`,
  `<A-K>`, `<A-L>`, `callback_is(lhs, "n", 'require("smart-splits").resize_left')` (…`_down`,
  `_up`, `_right`), after `child.wait_very_lazy()` so `gleb.debugging` has loaded.
- [x] 5.2 Prove it fails: temporarily uncomment `require("gleb.debugging.keybindings")` in
  `lua/gleb/debugging/init.lua`, run it (fails on `<A-J>`/`<A-H>`/`<A-L>`), revert.
- [x] 5.3 Delete `lua/gleb/debugging/keybindings.lua` and the commented require on
  `lua/gleb/debugging/init.lua:1`.
- [x] 5.4 The case passes; `grep -rn "debugging.keybindings" lua` finds nothing; `make quick` green.
  Commit.

## 6. Verify

- [x] 6.1 `make check` green (types, lint, trace with no orphans, every layer). `make trace VERBOSE=1`
  shows every scenario of `specs/keymaps/spec.md` in this change as tested.
