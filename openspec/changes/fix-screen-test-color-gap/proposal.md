## Why
mini.test reference screenshots (`tests/screenshots/`) store text plus attribute *identity*, not colors, so the Normal and Insert statusline screenshots share one attribute layout and a wrong color passes them. Partly addressed since the finding: `tests/helpers.lua:243-291` adds `H.statusline_colors` / `H.expect_colors`, and `tests/screen/statusline/test_statusline_screen.lua:31-42` asserts the resolved colors of three segments (` NORMAL `, ` INSERT `, ` lua`). What is still missing: those checks cover only the first occurrence of a text in the statusline, every other cell (chip caps, diagnostics, tabline, neo-tree, buffer area) is color-blind, and each color has to be hand-written as a hex literal in the test.

Kind: bug

## What Changes
- Add a color-aware screen assertion to `tests/helpers.lua` that works on any screen row, not only the statusline: read the resolved per-cell colors in the child with `vim.api.nvim__inspect_cell(1, row, col)` (verified on NVIM v0.12.5 headless: returns `{ text, { foreground, background, ... } }`) and compare them with an expected mask plus legend of highlight group names, in the same mask/`Legend:` format the design renders use (`docs/workflow.md` (Design renders), `tests/render/colorize.lua`). The expected colors come from `nvim_get_hl` of the legend groups, so tests name groups instead of hex literals.
- Keep `H.expect_colors` for single-segment checks; migrate the statusline screen tests to the mask assertion so an approved design render (text + mask) is directly the expected value.
- Alternative considered: store a color table next to each reference screenshot (attribute id -> fg/bg/bold). Rejected for now because it needs a custom screenshot format beside mini.test's.
- Document the helper in `docs/testing.md` "Screenshots".

## Capabilities
### Modified Capabilities
- None (`skip_specs: true`: test infrastructure only; existing screen scenarios keep their titles and meaning).

## Impact
- Code: `tests/helpers.lua`, `tests/screen/statusline/test_statusline_screen.lua`, possibly shared mask parsing with `tests/render/colorize.lua`; `docs/testing.md`.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: new screen scenarios for other capabilities, the empty glyphs (`fix-empty-nerd-font-glyphs`), and the colored tmux capture of `make render`.
