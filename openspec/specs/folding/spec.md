# folding Specification

## Purpose
Define buffer-local fold summaries so every visible split describes the folded content it actually contains.

## Requirements

### Requirement: Buffer-local fold text
The editor SHALL select language-specific fold text and read folded lines from the buffer being rendered, regardless of which window is current.

#### Scenario: Split buffers use their own fold text
- **WHEN** Go and Lua buffers with closed folds are visible in separate splits
- **THEN** each split shows fold text generated from that split's filetype and folded lines

### Requirement: Fold shortcut actions
Folding SHALL expose open-one, close-one, open-all, and close-all actions without lhs values and SHALL obtain their global mappings only from `settings/keymap.json`. One-fold actions SHALL preserve counts and return without error when no applicable fold is under the cursor.

#### Scenario: Fold keys invoke registered actions
- **WHEN** a buffer with closed folds is focused after `VeryLazy` and each configured fold lhs is pressed
- **THEN** the corresponding one-fold or all-fold action changes fold state

#### Scenario: Fold keys without a fold do nothing
- **WHEN** a buffer without folds is focused and `<M-=>` and `<M-->` are pressed in normal mode
- **THEN** its lines and cursor stay unchanged and neither key reports an error

### Requirement: Fold actions in tree buffers
When the current buffer is a shared tree (the project tree, the Changes panel or the Find Usages view), `fold.close_one`, `fold.open_one`, `fold.close_all` and `fold.open_all` SHALL run that tree's fold, unfold, fold-all and unfold-all verbs instead of Vim or ufo folds, and SHALL raise no error. In any other buffer they SHALL behave as before.

#### Scenario: Collapse Fold key folds the group under the tree cursor
- **WHEN** `v:errmsg` is empty, the cursor is on the `web/src 1` row of the changes panel on the `billing` fixture, and `<M-->` and then `<M-=>` are pressed in normal mode
- **THEN** after `<M-->` no `price.ts` row remains, after `<M-=>` it is back, and `v:errmsg` is still empty

#### Scenario: Expand Fold key unfolds a project tree folder
- **WHEN** the cursor is on the collapsed `internal` row of the project tree and `<M-=>` and then `<M-->` are pressed in normal mode
- **THEN** after `<M-=>` the `billing` and `money` rows follow `internal`, and after `<M-->` they are gone with the cursor on `internal`

#### Scenario: Collapse All Folds key folds every group of the Find Usages view
- **WHEN** `v:errmsg` is empty, the view is open for `Format` in the `gomod` fixture with default grouping, and `<S-D-->` and then `<S-D-=>` are pressed in normal mode
- **THEN** after `<S-D-->` the rows are `Production 3` and `Test 1`, after `<S-D-=>` the eleven default rows are back, and `v:errmsg` is still empty
