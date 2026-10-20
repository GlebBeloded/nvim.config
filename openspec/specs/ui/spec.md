# ui Specification

## Purpose
Shared UI components that feature views build on. `lua/gleb/ui/tree/` is the one tree used by the project tree, the Changes panel and the Find Usages view: a pure node model with fold state and selection by id, the fold verbs, a thin buffer view helper and a registry of tree buffers.

## Requirements

### Requirement: Tree model rows
The tree model SHALL hold nodes with stable string ids, a parent and ordered children, and fold state by id. Flattening SHALL list visible nodes depth first with their depth, hiding the descendants of a folded group. A group SHALL start open or folded as its node says. Fold state SHALL be kept by id across rebuilds and dropped for ids that are gone.

#### Scenario: Tree flattens open groups depth first
- **WHEN** a model is built from groups `A` (children leaf `A1`, group `A2` with leaf `A21`) and `B` (leaf `B1`), all starting open, `A2` is folded, and its rows are read
- **THEN** the rows are, as id and depth, `A` 0, `A1` 1, `A2` 1, `B` 0, `B1` 1

#### Scenario: Tree keeps fold state by id across rebuilds
- **WHEN** `A2` of that model is folded, the model is rebuilt from the same nodes without `A1`, then rebuilt without `A2`, then rebuilt with `A2` again
- **THEN** after the first rebuild the rows are `A`, `A2`, `B`, `B1`, and after the third `A21` is listed again under an open `A2`

#### Scenario: Tree groups start in their default state
- **WHEN** a model is built from the same nodes with `B` marked to start folded and its rows are read
- **THEN** the rows are `A`, `A1`, `A2`, `A21`, `B`

### Requirement: Tree fold verbs
Close SHALL fold an open group at the selection, else fold the nearest foldable ancestor and select it. Open SHALL unfold a folded group, select an open group's first child, and leave a leaf alone. Toggle SHALL flip a group and fold a leaf's parent. Close all SHALL fold every group and select the selection's top-level ancestor; open all SHALL unfold every group and keep the selection. A pinned group SHALL never fold.

#### Scenario: Close on an open group folds it
- **WHEN** every group of the `A`/`B` model is open, `A2` is selected and close runs
- **THEN** `A2` is folded, `A21` is not listed and `A2` stays selected

#### Scenario: Close on a leaf folds its parent and selects it
- **WHEN** every group is open, `A21` is selected and close runs
- **THEN** `A2` is folded and selected

#### Scenario: Close on a folded group folds its parent
- **WHEN** `A2` is folded and selected and close runs
- **THEN** `A` is folded and selected, and the rows are `A`, `B`, `B1`

#### Scenario: Open on a folded group unfolds it
- **WHEN** `A2` is folded and selected and open runs
- **THEN** `A21` is listed under `A2` and `A2` stays selected

#### Scenario: Open on an open group selects its first child
- **WHEN** every group is open, `A` is selected and open runs
- **THEN** the rows are unchanged and `A1` is selected

#### Scenario: Open on a leaf does nothing
- **WHEN** every group is open, `B1` is selected and open runs
- **THEN** the rows and the selection are unchanged

#### Scenario: Toggle on a leaf folds its parent
- **WHEN** every group is open, `A1` is selected and toggle runs
- **THEN** `A` is folded and selected

#### Scenario: Close all selects the top-level ancestor
- **WHEN** every group is open, `A21` is selected and close all runs, then open all runs
- **THEN** after close all the rows are `A`, `B` with `A` selected, and after open all every node is listed with `A` still selected

#### Scenario: A pinned group never folds
- **WHEN** a model has a pinned group `R` holding group `A` with leaf `A1`, close runs with `R` selected, then close runs twice starting with `A1` selected, then close all runs
- **THEN** `R` stays open throughout, the first close changes nothing, the second folds `A` and selects it, the third changes nothing, and close all leaves rows `R`, `A`

### Requirement: Tree selection carry-over
After a tree redraws, its cursor SHALL be on the row of the previously selected id; when that node is hidden, on its nearest visible ancestor; when it is gone, the owning view's fallback SHALL place it.

#### Scenario: Selection follows its id after a rebuild
- **WHEN** a tree buffer shows the `A`/`B` model with the cursor on `B1` (row 6), a node `X` is inserted before `B`, and the tree redraws
- **THEN** the cursor is on row 7, which is `B1`

#### Scenario: Selection on a hidden node moves to its visible ancestor
- **WHEN** a tree buffer shows the `A`/`B` model with the cursor on `A21`, `A` is folded, and the tree redraws
- **THEN** the cursor is on row 1, which is `A`

### Requirement: Tree buffers share the component
The project tree, the Changes panel and the Find Usages view SHALL register their tree buffers with the shared tree registry and render their rows through it. Their fold actions SHALL be built by one factory in `ui/tree`, so every tree binds the same fold keys.

#### Scenario: Every tree buffer is a shared tree
- **WHEN** the project tree, the Changes panel and the Find Usages view are each opened and `require("gleb.ui.tree").get(buf)` is called for their tree buffers and for a normal file buffer
- **THEN** each tree buffer returns a tree whose visible row count equals its buffer line count, and the file buffer returns nil

#### Scenario: Tree fold keys are the same in every tree
- **WHEN** `settings/keymap.json` is read for the areas `file_tree`, `changes` and `references`
- **THEN** in each area the fold-close action lists `h`, `<Left>`, `zc`, the expand action `l`, `<Right>`, `zo`, the toggle action `za`, the fold-all action `zM` and the unfold-all action `zR`
