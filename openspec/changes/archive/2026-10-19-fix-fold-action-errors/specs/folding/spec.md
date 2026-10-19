# Spec Delta

## MODIFIED Requirements

### Requirement: Fold shortcut actions
Folding SHALL expose open-one, close-one, open-all, and close-all actions without lhs values and SHALL obtain their global mappings only from `settings/keymap.json`. One-fold actions SHALL preserve counts and return without error when no applicable fold is under the cursor.

#### Scenario: Fold keys invoke registered actions
- **WHEN** a buffer with closed folds is focused after `VeryLazy` and each configured fold lhs is pressed
- **THEN** the corresponding one-fold or all-fold action changes fold state

#### Scenario: Fold keys without a fold do nothing
- **WHEN** a buffer without folds is focused and `<M-=>` and `<M-->` are pressed in normal mode
- **THEN** its lines and cursor stay unchanged and neither key reports an error
