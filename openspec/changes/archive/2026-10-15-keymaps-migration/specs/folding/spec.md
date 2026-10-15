# folding Specification

## ADDED Requirements

### Requirement: Fold shortcut actions
Folding SHALL expose open-one, close-one, open-all, and close-all actions without lhs values and SHALL obtain their global mappings only from `settings/keymap.json`.

#### Scenario: Fold keys invoke registered actions
- **WHEN** a buffer with closed folds is focused after `VeryLazy` and each configured fold lhs is pressed
- **THEN** the corresponding one-fold or all-fold action changes fold state

