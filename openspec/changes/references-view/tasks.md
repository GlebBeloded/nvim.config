## 1. Build the usage tree
Scenarios: `references: Go usages are grouped by scope and folder`, `references: Nested folders become one row`, `references: Regrouping keeps the selected usage`
- [x] 1.1 Write the three scenarios in tests/unit/references/test_tree.lua against fixture-shaped usage records, plus unit cases for the hidden and mixed tests modes and folders off, and see them fail
- [x] 1.2 Add the pure `lua/gleb/references/tree.lua`:
  - scope from `references.scope`;
  - the tests modes grouped, hidden and mixed (mixed tags test usages);
  - one folder node per full relative directory, or relative-path rows when folders are off;
  - `<file>:<line>` usage nodes;
  - counts and stable node ids;
  - selection carry-over by uri, line and column.
- [x] 1.3 Run `make test FILE=tests/unit/references/test_tree.lua` and see them pass

## Agent decisions

- Tree output is a flat preorder node list with `parent_id` and `selected_id`; usage ids contain uri, line and column but no grouping state, so rendering and selection survive regrouping.
- Icon resolution accepts tree nodes and returns glyph plus icon and label groups, so the later view can apply extmarks without duplicating palette or devicon logic.
- Preview scratch buffers retain source line coordinates (with disk reads capped at 10,000 lines), so syntax captures, usage marks and line numbers match regular buffers directly.
- Missing or invalid persisted grouping falls back to grouped tests with folders on, preserving the documented first-use defaults.
- The client-side declaration filter is dropped: `includeDeclaration = false` already excludes it, and the filter removed the usage under the cursor when `gr` ran on a call site (V1 counts 4).
- The tree's left padding is a one-cell status column, so tree buffer lines stay the row labels that tests and selection read.
- Preview tabs are 4 cells wide, as in render V1, whatever the source buffer's `tabstop`.
- A clipped preview line ends in a `…` overlay with `hl_mode = "combine"`, so the cell keeps its syntax colour (render V1 clipping and mask).
- The preview's topline is computed (centred, window `scrolloff` 0): the global `scrolloff = 15` moved a `zz` view.
- Both status columns pick their groups per line by expression, with no `CursorLineNr`/`LineNr` remap: `nvim_get_hl` resolves legend groups through the current window's `winhighlight`.
- Preview mask colours: choose option A—regenerate the V1–V3 preview code cells and `WIDE_DEFAULT_MASK` from the real Go captures, with legend entries for `@punctuation.bracket`, `@variable.parameter`, `@operator`, `@type`, `@function.method` and `@function.builtin`, because this preserves the user's regular-buffer-highlighting decision and the Usage preview requirement while retaining full colour coverage.
- A filter that removes every usage keeps the view open with a one-row empty tree and cleared preview, so the persisted state and in-view toggle behave consistently.

## 2. Icons and label shades
Scenarios: `references: Icons and label shades match the palette`
- [x] 2.1 Write the scenario in tests/integration/references/test_icons.lua, plus a unit test for the palette mix in tests/unit/references/test_icons.lua, and see them fail
- [x] 2.2 Add `lua/gleb/references/icons.lua`:
  - glyphs U+F427, U+F499 and U+F0256, plus the devicon lookup;
  - the `ReferencesProduction`, `ReferencesTest` and `ReferencesFolder` groups and their `…Label` groups;
  - a `ReferencesFileLabel<DevIconGroup>` group per devicon;
  - `LABEL_PALENESS = 0.7`, computed from the gruvbox-material palette helpers and recomputed on `ColorScheme`.
- [x] 2.3 Run both test files and see them pass

## 3. Request references and open the view
Scenarios: `references: gr opens the view in a Go module`, `references: gr with no usages notifies and opens nothing`, `references: gr without a references-capable client notifies`, `references: The first usage is selected and previewed`, `keymaps: gr bound to Telescope references`, `file-tree: gr keeps its global meaning in git status tree`
- [x] 3.1 Write the scenarios in tests/integration/references/test_open.lua (gomod fixture via `F.copy`, gopls). Update the keymaps and file-tree tests to expect the view. See them fail.
- [x] 3.2 Add:
  - `request.lua`: async; only clients with `referencesProvider`; de-duplicated; declaration excluded.
  - The frame, tree and preview windows in `view.lua`, including both geometries.
  - The `references.*` actions, with keys in `settings/keymap.json`.
  - Point `lsp.references` at the view, and remove the old source from `lua/gleb/picker/actions.lua`.
- [x] 3.3 Run the scenarios and see them pass

## 4. Preview
Scenarios: `references: Preview follows the selection`, `references: Preview highlighting matches a regular buffer`, `references: Preview falls back to Vim syntax without a parser`, `references: Preview leaves no buffer or client behind`, `references: Preview shows unsaved edits`, `references: P toggles the preview pane`
- [x] 4.1 Write the six scenarios in tests/integration/references/test_preview.lua and see them fail
- [x] 4.2 Add `preview.lua`:
  - a scratch buffer;
  - `vim.treesitter.start` when the parser exists, else `syntax = <filetype>`;
  - text from the loaded buffer, else a bounded `readfile`;
  - [CursorLineNr] on the usage's line number, and every usage marked [Search];
  - `P` switching between the wide and fitted geometries.
- [x] 4.3 Run `make test FILE=tests/integration/references/test_preview.lua` and see all six pass

## 5. Grouping controls, keys and persistence
Scenarios: `references: Tests key cycles grouped, hidden and mixed`, `references: Mixed tests without folders is a flat list`, `references: Grouping persists across sessions`, `references: Return opens a usage at its position`, `references: za folds a group`, `references: Escape returns to the origin window`, `references: View keys come from the keymap file`
- [x] 5.1 Write the scenarios in tests/integration/references/test_keys.lua and see them fail
- [x] 5.2 Add:
  - the `t` (tests-mode cycle) and `f` (folders) actions, rebuilding in place;
  - the hint-row states, with key labels from the keymap file;
  - fold state per node id;
  - open and close behaviour;
  - persistence in `state.lua`.
- [x] 5.3 Run `make test FILE=tests/integration/references/test_keys.lua` and see them pass

## 6. Screens and the real-key workflow
Scenarios: `references: Wide view matches reference screenshot`, `references: Narrow view fits its content`, `lsp: References of a Go function list call sites across packages`, `lsp: Selecting a reference opens its file at the call site`
- [x] 6.1 Write the screen scenarios in tests/screen/references/test_view.lua with Proposed V1–V4 as references, and see them fail. The screenshot text uses the real glyphs where the render shows stand-ins; the attribute blocks must match the mask groups.
- [x] 6.2 Update tests/e2e/lsp/test_go_references.lua to the view:
  1. a real `gr`;
  2. then `t`;
  3. then move to `summary.go:7` and press Return.
  Compare each step's zellij dump with its render.
- [x] 6.3 Make `make test-screen` and `make e2e` (sandbox VM) pass, then `make check`. Compare `make render` of the view with `renders/view_v*.ansi`.
- [x] 6.4 Add `references` to the module map in `docs/architecture.md`
