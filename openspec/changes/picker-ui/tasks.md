## 1. Build the shared picker frame
Scenarios: `picker: Wide picker matches reference screenshot`
- [ ] 1.1 Write the test `picker: Wide picker matches reference screenshot` in tests/screen/picker/test_frame.lua and see it fail
- [ ] 1.2 Add the mini.pick setup, complete rounded frame, title/query rendering, reserved joined hint row and palette-backed highlight groups in `lua/gleb/picker/`; add architecture rule 8.9
- [ ] 1.3 Run `make test FILE=tests/screen/picker/test_frame.lua CASE="Wide picker matches reference screenshot"` and see it pass

## 2. Render picker rows
Scenarios: `picker: Rows expose primary secondary and category text`, `picker: Section header fills its row with a rule`
- [x] 2.1 Write the tests `picker: Rows expose primary secondary and category text` and `picker: Section header fills its row with a rule` in tests/unit/picker/test_rows.lua and see them fail
- [x] 2.2 Add the typed row model and `source.show` renderer for primary, secondary, category, glyph and section rows
- [x] 2.3 Run `make test FILE=tests/unit/picker/test_rows.lua CASE="Rows expose primary secondary and category text"` and `make test FILE=tests/unit/picker/test_rows.lua CASE="Section header fills its row with a rule"` and see them pass

## 3. Make picker layout responsive
Scenarios: `picker: Compact picker matches reference screenshot`, `picker: Narrow picker matches reference screenshot`, `picker: Short editor gives the picker full height`, `picker: Resize recomputes picker layout`
- [x] 3.1 Write the tests for the four responsive picker scenarios in tests/screen/picker/test_responsive.lua and see them fail
- [x] 3.2 Add pure breakpoint logic and a callable mini.pick window config that refreshes fields, hints and geometry after resize
- [x] 3.3 Run `make test FILE=tests/screen/picker/test_responsive.lua CASE="Compact picker matches reference screenshot"`, `CASE="Narrow picker matches reference screenshot"`, `CASE="Short editor gives the picker full height"` and `CASE="Resize recomputes picker layout"` and see them pass

## 4. Replace the selection interface
Scenarios: `select: Code action menu receives picker mappings`, `select: Selection accepts omitted options`, `select: Cancelling a code action completes selection`, `select: Code action popup fits editor width`, `select: Selection previews the current item`
- [ ] 4.1 Write or update the five selection tests in tests/integration/select/test_picker.lua and see them fail
- [ ] 4.2 Implement `vim.ui.select` and code actions on the shared picker, preserving width, mappings and exactly-once cancellation while supporting formatting and previews; remove the nui selection implementation
- [ ] 4.3 Run `make test FILE=tests/integration/select/test_picker.lua` with `CASE="Code action menu receives picker mappings"`, `CASE="Selection accepts omitted options"`, `CASE="Cancelling a code action completes selection"`, `CASE="Code action popup fits editor width"` and `CASE="Selection previews the current item"` and see them pass

## 5. Move live grep to the shared picker
Scenarios: `keymaps: Alt-F opens live grep`
- [ ] 5.1 Update the test `keymaps: Alt-F opens live grep` in tests/integration/keymaps/test_keymaps.lua and see it fail
- [ ] 5.2 Change `<A-F>` to open the framed mini.extra live-grep source
- [ ] 5.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-F opens live grep"` and see it pass

## 6. Move references to the shared picker
Scenarios: `keymaps: LSP mappings bound to vim.lsp.buf`, `keymaps: Code action in visual mode`, `keymaps: gr bound to Telescope references`
- [ ] 6.1 Update the three LSP mapping tests in tests/integration/keymaps/test_keymaps.lua and see the references test fail
- [ ] 6.2 Change `gr` to open the framed mini.extra LSP-references source while preserving the other LSP mappings and sole `gr` ownership
- [ ] 6.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua` with `CASE="LSP mappings bound to vim.lsp.buf"`, `CASE="Code action in visual mode"` and `CASE="gr bound to Telescope references"` and see them pass

## 7. Move dashboard lists and remove Telescope
Scenarios: `picker: Dashboard opens shared list pickers`
- [ ] 7.1 Write the test `picker: Dashboard opens shared list pickers` in tests/integration/picker/test_dashboard.lua and see it fail
- [ ] 7.2 Wire the dashboard file, recent-file and grep actions to shared sources; remove its project action, project.nvim integration, Telescope modules and tests, plugin declarations and lock entries; wire `lua/gleb/picker/` from `init.lua`
- [ ] 7.3 Run `make test FILE=tests/integration/picker/test_dashboard.lua CASE="Dashboard opens shared list pickers"` and see it pass

## 8. Use 99 native completion
Scenarios: `ai: Keymaps exist after VeryLazy`, `ai: Missing 99 is tolerated`, `ai: 99 uses native completion`
- [ ] 8.1 Update `ai: Keymaps exist after VeryLazy` in tests/integration/ai/test_setup.lua and `ai: Missing 99 is tolerated` plus `ai: 99 uses native completion` in tests/unit/ai/test_setup.lua, then see the native-completion test fail
- [ ] 8.2 Configure 99's native completion source and remove its Telescope dependency without changing its provider, model or keymaps
- [ ] 8.3 Run `make test FILE=tests/integration/ai/test_setup.lua CASE="Keymaps exist after VeryLazy"`, `make test FILE=tests/unit/ai/test_setup.lua CASE="Missing 99 is tolerated"` and `make test FILE=tests/unit/ai/test_setup.lua CASE="99 uses native completion"` and see them pass

## Stuck

## Agent decisions

- Row visibility uses named `show_*` options and built-in `Comment`/`PmenuExtra`/`PmenuKind` groups so responsive callers can hide fields while the frame task remains responsible for palette-backed links.
- Normal picker geometry is a centered 72-by-8-cell frame, while editors below 15 lines use every row, matching the approved wide render and preserving results on short screens.
