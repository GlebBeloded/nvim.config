## 1. Engine and rule syntax

Scenarios: `file-tree: Nesting rule nests by capture`, `file-tree: Nesting patterns match whole names`, `file-tree: Nesting captures are inserted literally`, `file-tree: Broken nesting rules are skipped`, `file-tree: Earlier nesting rule wins a shared child`, `file-tree: Nesting cycles keep rule order`, `file-tree: Folders never nest`

- [ ] 1.1 Write the seven scenarios in `tests/unit/file-tree/test_nesting.lua` (bare child, no plugins; `vim.notify` captured), each with the exact inputs and expected tables of the spec, and see them fail
- [ ] 1.2 Add `lua/gleb/file_tree/nesting.lua` (pure, rule 1.3): `compile(rules)` (anchoring, capture check, `pcall` pattern check, WARN once per rule per load) and `nest(dir, entries, rules)` per design Decision 3, LuaCATS on every export
- [ ] 1.3 Run the file and see it pass

## 2. Programmable rules

Scenarios: `file-tree: Lua nesting rule nests by function`, `file-tree: Failing Lua nesting rule is skipped`

- [ ] 2.1 Write both scenarios in `tests/unit/file-tree/test_nesting.lua` with `package.preload` modules, assert the arguments the function receives, and see them fail
- [ ] 2.2 Resolve `{ lua = … }` rules in `compile` and walk their maps in `nest` (Decision 4)
- [ ] 2.3 Run the file and see it pass

## 3. Settings file and default rules

Scenarios: `file-tree: Default nesting rules nest Go files`, `file-tree: Default nesting rules nest web files`, `file-tree: Default nesting rules nest Python and Rust files`, `file-tree: Default nesting rules nest project files`

- [ ] 3.1 Write the four scenarios in `tests/unit/file-tree/test_nesting.lua`, loading the rules through `require("gleb.file_tree.settings").load()` from the real `settings/file_tree.json`, and see them fail
- [ ] 3.2 Add `settings/file_tree.json` with the table of design Decision 5 (`nesting.enabled = true`, `ignore = []`) and `lua/gleb/file_tree/settings.lua` (`setup`, `load`, `M.state`, `M.reset`, validation per Decision 1)
- [ ] 3.3 Run the file and see it pass

## 4. Rows and chevron

Scenarios: `file-tree: Nests start collapsed under a chevron`, `file-tree: Nest children are indented under the parent`, `file-tree: Nest state survives a refresh`, `file-tree: Invalid settings file disables nesting`, `file-tree: Nesting can be turned off`, `file-tree: Writing the settings file reloads nesting`

- [ ] 4.1 Extend the `treeproj` fixture in `tests/fixtures/build.sh` to exactly design Decision 8 (manifest: the nest map per folder), write the six scenarios in `tests/integration/file-tree/test_nesting.lua` (settings path set to a temporary copy with `settings.setup`), and see them fail
- [ ] 4.2 Feed each folder listing through `nesting.nest` in `model.lua`, keep `expanded_nests` by parent path, render the chevron and nest indent in `render.lua`, and add the `BufWritePost` reload (augroup `gleb_file_tree_settings`) in `view.lua`
- [ ] 4.3 Run the file and see it pass

## 5. Nest actions, follow and ops

Scenarios: `file-tree: za toggles a nest`, `file-tree: h on a nested file closes its nest`, `file-tree: Enter on a nest parent opens the file`, `file-tree: Fold all and unfold all include nests`, `file-tree: Followed nested file expands its nest`, `file-tree: Added nested file is revealed in its nest`, `file-tree: Deleting a nest parent keeps its children`

- [ ] 5.1 Write the seven scenarios in `tests/integration/file-tree/test_nesting.lua` (prompts and confirmations stubbed as `file-tree-ops` tests do), and see them fail
- [ ] 5.2 Teach `file_tree.toggle_fold`, `close_node`, `fold_all` and `unfold_all` about nests, make follow and reveal expand a nest first, and make ops act on the row's own file (Decision 6)
- [ ] 5.3 Run the file and see it pass

## 6. Git tint

Scenarios: `file-tree: Collapsed nest parent shows a changed child`, `file-tree: Nest parent keeps its own status`

- [ ] 6.1 Write both scenarios in `tests/integration/file-tree/test_nesting.lua` (fresh fixture copy each), asserting the highlight group at the name's columns, and see them fail
- [ ] 6.2 Apply the folder tint function to a parent's children when it has no own status (Decision 7)
- [ ] 6.3 Run the file and see it pass

## 7. Screen

Scenarios: `file-tree: File tree nests match the approved render`

- [ ] 7.1 Add the case to `tests/screen/file-tree/test_nesting.lua` at 100x30 with the reference screenshot from "Proposed — nests under a chevron" (real glyphs, attribute blocks per the mask groups), plus `H.expect_screen_colors` with the render's mask and legend for the tree columns, and see it fail
- [ ] 7.2 Make it pass, then compare `make render` of the case with `renders/nest_proposed.ansi` and `make colorize FILE=openspec/changes/file-tree-nesting/design.md`
- [ ] 7.3 Run `make check`
