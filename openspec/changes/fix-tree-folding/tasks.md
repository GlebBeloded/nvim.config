## 1. Reproduce per tree and key

Scenarios: `git: Changes panel arrow keys and zc zo fold without an error`, `references: Arrow keys and zc zo fold groups without an error`, `file-tree: Project tree zo and zc fold without an error`, `folding: Collapse Fold key folds the group under the tree cursor`

- [x] 1.1 Write the four scenarios above (in `tests/integration/git/test_changes.lua`, `tests/integration/references/test_keys.lua`, `tests/integration/file-tree/test_project_tree.lua`, `tests/integration/folding/test_shortcuts.lua`) pressing the real keys, run each with `make test FILE=… CASE=…`, and see every one fail as in the proposal's Evidence table (rows unchanged, E490 for `zo`/`zc`)
- [x] 1.2 Record any key whose result differs from the Evidence table in the proposal before going on

## 2. Shared tree model and verbs

Scenarios: `ui: Tree flattens open groups depth first`, `ui: Tree keeps fold state by id across rebuilds`, `ui: Tree groups start in their default state`, `ui: Close on an open group folds it`, `ui: Close on a leaf folds its parent and selects it`, `ui: Close on a folded group folds its parent`, `ui: Open on a folded group unfolds it`, `ui: Open on an open group selects its first child`, `ui: Open on a leaf does nothing`, `ui: Toggle on a leaf folds its parent`, `ui: Close all selects the top-level ancestor`, `ui: A pinned group never folds`

- [x] 2.1 Write the scenarios in `tests/unit/ui/test_tree.lua` (bare child, no plugins) and see them fail
- [x] 2.2 Add `lua/gleb/ui/tree/model.lua` and `lua/gleb/ui/tree/fold.lua` (design Decisions 2 and 3), typed with LuaCATS
- [x] 2.3 Run `make test FILE=tests/unit/ui/test_tree.lua` and see it pass

## 3. View helper, registry and action factory

Scenarios: `ui: Selection follows its id after a rebuild`, `ui: Selection on a hidden node moves to its visible ancestor`, `ui: Tree fold keys are the same in every tree`

- [x] 3.1 Write the scenarios in `tests/unit/ui/test_tree_view.lua` and `tests/unit/ui/test_tree_keys.lua` and see them fail
- [x] 3.2 Add `lua/gleb/ui/tree/view.lua`, `lua/gleb/ui/tree/actions.lua` and `lua/gleb/ui/tree/init.lua` (design Decisions 4 and 5); add the new action keys to `settings/keymap.json` and move `l` from `file_tree.open` to `file_tree.expand_node`
- [x] 3.3 Run both files and see them pass

## 4. Changes panel on the shared tree

Scenarios: `git: Changes panel h folds a directory and l unfolds it`, `git: Changes panel h on a file folds its directory`, `git: Changes panel l on an open group moves to its first child`, `git: Changes panel l on a file does nothing`, `git: Changes panel za on a file folds its parent`, `git: Changes panel zM and zR fold every group`, `git: Changes panel arrow keys and zc zo fold without an error`, `git: Changes panel mappings come from the shortcut file`, `git: Changes panel leaves gr global`, `git: Changes panel entry points are actions`

- [ ] 4.1 Write the new scenarios in `tests/integration/git/test_changes.lua` and see them fail
- [ ] 4.2 Replace `visible_rows`/`collapsed`/`toggle_fold` in `git/changes/view.lua` with the shared model, verbs and view helper; append the factory actions in `git/changes/actions.lua`
- [ ] 4.3 Run `make test FILE=tests/integration/git/test_changes.lua` and the other `tests/integration/git/test_changes*.lua` files and see them pass (including `git: Changes panel za folds a nest` and `git: Changes panel Enter folds a directory`)

## 5. Find Usages view on the shared tree

Scenarios: `references: h folds a group and l unfolds it`, `references: h on a usage folds its group`, `references: l on an open group moves to its first child`, `references: l on a usage keeps the view open`, `references: zM and zR fold every group`, `references: Arrow keys and zc zo fold groups without an error`, `references: View keys come from the keymap file`, `references: za folds a group`, `references: Return opens a usage at its position`, `references: Escape returns to the origin window`, `references: Built-in close returns to the origin window`

- [ ] 5.1 Write the new scenarios in `tests/integration/references/test_keys.lua`, update the key list of `references: View keys come from the keymap file`, and see them fail
- [ ] 5.2 Replace `visible_nodes`/`folded`/`fold`/`place_cursor` in `references/view.lua` with the shared model, verbs and view helper; append the factory actions in `references/actions.lua`
- [ ] 5.3 Run `make test CAPS=references` and see it pass, screen cases unchanged

## 6. Project tree on the shared tree

Scenarios: `file-tree: Project tree l expands a folder`, `file-tree: Project tree l on an open folder moves to its first child`, `file-tree: Project tree l on a file does nothing`, `file-tree: Project tree l opens a nest`, `file-tree: Project tree arrow keys fold and unfold a folder`, `file-tree: Project tree zo and zc fold without an error`, `file-tree: Project tree keys come from the keymap file`

- [ ] 6.1 Write the new scenarios in `tests/integration/file-tree/test_project_tree.lua` and see them fail
- [ ] 6.2 Back `close_node`, `toggle_fold`, `fold_all`, `unfold_all` and the new `expand_node` with the shared verbs through the expansion adapter (design Decision 3), keeping `expanded`, `expanded_nests`, `expanded.json` and the 5000-row bound
- [ ] 6.3 Run `make test CAPS=file-tree` and see it pass, including every existing fold, nest, limit and render scenario

## 7. Global fold actions and registry

Scenarios: `folding: Collapse Fold key folds the group under the tree cursor`, `folding: Expand Fold key unfolds a project tree folder`, `folding: Collapse All Folds key folds every group of the Find Usages view`, `ui: Every tree buffer is a shared tree`, `folding: Fold keys invoke registered actions`, `folding: Fold keys without a fold do nothing`

- [ ] 7.1 Write the scenarios in `tests/integration/folding/test_shortcuts.lua` and `tests/integration/ui/test_tree_buffers.lua` and see them fail
- [ ] 7.2 Dispatch to `require("gleb.ui.tree").get(0)` first in `folding/actions.lua` (design Decision 6)
- [ ] 7.3 Run both files and see them pass

## 8. Gate

- [ ] 8.1 Run `make check` and see it green; `make trace` lists every scenario of this change as tested

## Agent decisions

- Store a folded boolean for every foldable id, so rebuilds preserve both explicit opens and closes.
- Cache each attached tree's last rendered rows and renderer, so redraws recover the old cursor id and shared actions can redraw without feature-specific dispatch.
