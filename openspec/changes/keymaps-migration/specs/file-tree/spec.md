# file-tree Specification

## ADDED Requirements

### Requirement: Neo-tree mapping ownership
Neo-tree SHALL disable its default mappings and build common, filesystem, and git-status mapping tables from registered file-tree actions and current `settings/keymap.json` assignments whenever setup runs.

#### Scenario: Tree mappings come from the shortcut file
- **WHEN** a populated filesystem or git-status tree is opened after `VeryLazy`
- **THEN** every configured tree lhs invokes the file-tree action assigned by `settings/keymap.json`

#### Scenario: Neo-tree defaults stay disabled
- **WHEN** a populated tree is opened and its buffer-local normal mappings are enumerated
- **THEN** an unconfigured neo-tree default lhs is absent

