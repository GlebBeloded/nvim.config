# Tasks

## 1. Statusline screen masks match the capped chip

Scenarios: "statusline: statusline matches reference screenshot", "statusline: insert mode accent matches reference screenshot"

Layer: screen (`tests/screen/statusline/test_statusline_screen.lua`). Tests only, nothing in `lua/`.

- [x] 1.1 Failing test: in both cases set the mask to `aaaaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccceeeeewwwwrtltttttg` (80 cells: `r` at column 72, `g` at column 80). Add `r = "StatuslineLangCapError"` and `g = "StatuslineLangEdge"` to each legend, and pin the red cap with `H.expect_hl_colors(child, "StatuslineLangCapError", { fg = "#ea6962" })` (palette `err` = gruvbox-material `red`). Also assert the no-LSP precondition right after the screenshot in each case: `MiniTest.expect.equality(child.lua_get("#vim.lsp.get_clients({ bufnr = 0 })"), 0)`. Run `make test FILE=tests/screen/statusline/test_statusline_screen.lua` a few times (`for i in 1 2 3; do …; done`): the client-count assertion fails (null-ls attached), and the mask flakes at column 72 (`StatuslineLangCapOk` drawn instead of `StatuslineLangCapError`).
- [x] 1.2 Make "no LSP client" deterministic in `start()`, in the test child only: before `:edit sample.lua`, next to `vim.lsp.enable("lua_ls", false)`, disable none-ls's Lua sources with its built-in API `require("null-ls").disable({ filetypes = { "lua" } })`, so none-ls has no available source for the buffer and never attaches. Update the `start()` doc comment to say both lua_ls and null-ls are kept off. Both cases pass 5 runs in a row.
- [x] 1.3 `git diff --exit-code tests/screenshots` is empty: the committed references already show the caps (Decision of fix-empty-nerd-font-glyphs: U+E0B6 / U+E0B4 kept; no `make screenshots`).

## 2. Verify

- [ ] 2.1 `make trace` lists both scenarios as tested; `make check` green.
