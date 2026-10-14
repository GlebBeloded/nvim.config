## 1. Build and register the shared picker frame
Scenarios: `picker: Wide picker matches reference screenshot`, `picker: Focused match remains above the hint row`
- [x] 1.1 Write the test `picker: Wide picker matches reference screenshot` in tests/screen/picker/test_frame.lua and see it fail
- [x] 1.2 Declare and lock mini.nvim, add the shared picker setup, complete rounded frame, title/query rendering, reserved joined hint row and palette-backed highlight groups, wire it from `init.lua`, and add architecture rule 8.9
- [x] 1.3 Run `make test FILE=tests/screen/picker/test_frame.lua CASE="Wide picker matches reference screenshot"` and see it pass
- [x] 1.4 Keep mini.pick's viewport limited to match rows so focused matches never enter the attached hint area

## 2. Render picker rows
Scenarios: `picker: Rows expose primary secondary and category text`, `picker: Section header fills its row with a rule`
- [x] 2.1 Write the two row scenarios in tests/unit/picker/test_rows.lua and see them fail
- [x] 2.2 Add the typed row model and renderer for primary, secondary, category, glyph and section rows
- [x] 2.3 Run both scenarios in tests/unit/picker/test_rows.lua and see them pass

## 3. Make picker layout responsive
Scenarios: `picker: Compact picker matches reference screenshot`, `picker: Narrow picker matches reference screenshot`, `picker: Short editor gives the picker full height`, `picker: Resize recomputes picker layout`
- [x] 3.1 Write the four responsive scenarios in tests/screen/picker/test_responsive.lua and see them fail
- [x] 3.2 Add pure breakpoint logic and callable picker geometry that refreshes fields and hints after resize
- [x] 3.3 Run the four scenarios in tests/screen/picker/test_responsive.lua and see them pass

## 4. Give code actions the shared picker mappings
Scenarios: `select: Code action menu receives picker mappings`, `select: Shared code action uses picker mappings`, `select: General selection keeps text input mappings`
- [x] 4.1 Write the scenario in tests/integration/select/test_picker.lua and see it fail
- [x] 4.2 Apply the shared picker's declared mappings to code-action selections
- [x] 4.3 Run `make test FILE=tests/integration/select/test_picker.lua CASE="Code action menu receives picker mappings"` and see it pass
- [x] 4.4 Derive active aliases from the default keymap and apply them only to code actions

## 5. Preserve the selection completion contract
Scenarios: `select: Selection accepts omitted options`, `select: Cancelling a code action completes selection`, `select: Selection callback runs in the target window`
- [x] 5.1 Write the two completion scenarios in tests/integration/select/test_picker.lua and see them fail
- [x] 5.2 Accept omitted options and invoke a cancelled code-action callback exactly once with two nil arguments
- [x] 5.3 Run both completion scenarios in tests/integration/select/test_picker.lua and see them pass
- [x] 5.4 Delegate selection to MiniPick.ui_select so callbacks run in the originating target window

## 6. Fit code-action pickers to the editor
Scenarios: `select: Code action popup fits editor width`
- [x] 6.1 Write the scenario in tests/integration/select/test_picker.lua and see it fail
- [x] 6.2 Measure formatted content and prompt width with padding and the editor-width cap
- [x] 6.3 Run `make test FILE=tests/integration/select/test_picker.lua CASE="Code action popup fits editor width"` and see it pass

## 7. Preview formatted selection items
Scenarios: `select: Selection previews the current item`
- [x] 7.1 Write the scenario in tests/integration/select/test_picker.lua and see it fail
- [x] 7.2 Preserve original items while rendering formatted text and previewing the current item
- [x] 7.3 Run `make test FILE=tests/integration/select/test_picker.lua CASE="Selection previews the current item"` and see it pass

## 8. Move live grep to the shared picker
Scenarios: `keymaps: Alt-F opens live grep`
- [x] 8.1 Update the scenario in tests/integration/keymaps/test_keymaps.lua and see it fail
- [x] 8.2 Change `<A-F>` to open the framed mini.extra live-grep source
- [x] 8.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-F opens live grep"` and see it pass

## 9. Move the references keymap to the shared picker
Scenarios: `keymaps: LSP mappings bound to vim.lsp.buf`, `keymaps: Code action in visual mode`, `keymaps: gr bound to Telescope references`
- [x] 9.1 Update the three LSP mapping scenarios in tests/integration/keymaps/test_keymaps.lua and see the references scenario fail
- [x] 9.2 Change `gr` to open the shared LSP-references source while preserving the other mappings and sole `gr` ownership
- [x] 9.3 Run the three named scenarios in tests/integration/keymaps/test_keymaps.lua and see them pass

## 10. Preserve the Go references workflow
Scenarios: `lsp: References of a Go function list call sites across packages`, `lsp: Selecting a reference opens its file at the call site`
- [x] 10.1 Update the picker driver in tests/e2e/lsp/test_go_references.lua for the two scenarios and see them fail
- [x] 10.2 Implement the shared LSP-references source with current-line inclusion, matching and selection
- [x] 10.3 Run `make e2e` for the two Go references scenarios in the sandbox VM and see them pass

## 11. Preserve gr inside the git status tree
Scenarios: `file-tree: gr keeps its global meaning in git status tree`
- [x] 11.1 Update the scenario in tests/integration/file-tree/test_tree.lua to observe the shared references source and see it fail
- [x] 11.2 Keep `gr` unbound in the git status tree so it inherits the replacement global mapping
- [x] 11.3 Run `make test FILE=tests/integration/file-tree/test_tree.lua CASE="gr keeps its global meaning in git status tree"` and see it pass

## 12. Move dashboard lists and remove Telescope
Scenarios: `picker: Dashboard opens shared list pickers`
- [x] 12.1 Write the scenario in tests/integration/picker/test_dashboard.lua and see it fail
- [x] 12.2 Wire dashboard file, recent-file and grep actions to shared sources; remove its project action, project.nvim integration, Telescope modules and tests, plugin declarations and lock entries
- [x] 12.3 Run `make test FILE=tests/integration/picker/test_dashboard.lua CASE="Dashboard opens shared list pickers"` and see it pass

## 13. Preserve startup session names after cwd changes
Scenarios: `session: project cwd change preserves the startup session name`
- [x] 13.1 After removing project.nvim, run `make test FILE=tests/integration/session/test_session.lua CASE="project cwd change preserves the startup session name"` and see the plugin-specific setup fail
- [x] 13.2 Drive the same cwd change with Neovim's built-in directory command, keeping the session assertion unchanged
- [x] 13.3 Run `make test FILE=tests/integration/session/test_session.lua CASE="project cwd change preserves the startup session name"` and see it pass

## 14. Use 99 native completion
Scenarios: `ai: Keymaps exist after VeryLazy`, `ai: Missing 99 is tolerated`, `ai: 99 uses native completion`
- [x] 14.1 Update the three scenarios in tests/integration/ai/test_setup.lua and tests/unit/ai/test_setup.lua, then see the native-completion scenario fail
- [x] 14.2 Configure 99's native completion source and remove its Telescope dependency without changing its provider, model or keymaps
- [x] 14.3 Run the three named AI scenarios in their test files and see them pass

## 15. Render live-grep results safely
Scenarios: `keymaps: Live grep renders matching rows`
- [x] 15.1 Write the test `keymaps: Live grep renders matching rows` in tests/integration/keymaps/test_keymaps.lua, type a matching query, assert the rendered file, line and text, and see it fail with the NUL-separated result error
- [x] 15.2 Route unstructured source items through `MiniPick.default_show` while retaining the shared frame chrome and structured row renderer
- [x] 15.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Live grep renders matching rows"` and see it pass

## 16. Restore the saved session cwd
Scenarios: `session: bare nvim restores a cwd session after pane id change`
- [x] 16.1 Tighten `session: bare nvim restores a cwd session after pane id change` in tests/integration/session/test_session.lua to assert the saved cwd as well as its buffer and see it fail
- [x] 16.2 Remove the post-load cwd reset so `resession.load` restores the saved session state
- [x] 16.3 Run `make test FILE=tests/integration/session/test_session.lua CASE="bare nvim restores a cwd session after pane id change"` and see it pass

## 17. Keep alternate picker views counter-free
Scenarios: `picker: Alternate picker views keep the border counter-free`
- [x] 17.1 Write the test `picker: Alternate picker views keep the border counter-free` in tests/screen/picker/test_frame.lua, toggle preview and info view, and see the match counter appear
- [x] 17.2 Clear mini.pick's footer through picker lifecycle handling that does not depend on the main results buffer being visible
- [x] 17.3 Run `make test FILE=tests/screen/picker/test_frame.lua CASE="Alternate picker views keep the border counter-free"` and see it pass

## Agent decisions

- Live grep uses mini.pick's built-in `grep_live`, because the installed mini.extra has no live-grep source; frame options preserve the specified shared UI.
- The hint area is an attached non-focusable one-row window whose top border joins mini.pick's frame, keeping mini.pick's viewport limited to match rows.
- Row visibility uses named `show_*` options and built-in `Comment`/`PmenuExtra`/`PmenuKind` groups so responsive callers can hide fields while the frame task remains responsible for palette-backed links.
- Normal picker geometry is a centered 72-by-8-cell frame, while editors below 15 lines use every row, matching the approved wide render and preserving results on short screens.
- Selection items retain their original value and index beside formatted row text so matching uses what users see while callbacks receive the original item.
- Picker aliases use MiniPick custom actions for Tab, Shift-Tab, Control-C and Space because each built-in action accepts only one configurable key.
- After project.nvim is removed, the session scenario uses Neovim's built-in cwd change to preserve its original startup-name guarantee.
- The Go references E2E driver uses mini.pick's public item and match APIs; task 9's mini.extra source already passed both scenarios, so no duplicate source was added.
- Dashboard files use MiniPick's built-in files source and recent files use MiniExtra's oldfiles source because they directly replace Telescope's corresponding list actions.
- Existing unit scenario identities remain authoritative; runtime integration coverage uses distinct scenarios so traceability stays one-to-one.
- Renderer dispatch uses the first item's shape because shared structured sources use tables while mini.pick built-ins emit strings.
- Alternate views update footer and hint chrome from `source.show` using the picker window because movement and resize do not re-enter its buffer.
