# keymaps Specification

## ADDED Requirements

### Requirement: Action-backed core mappings
Core editor behavior SHALL be exposed from feature action lists and assigned only by `settings/keymap.json`. Registry-created mappings SHALL remain non-recursive and silent, and their descriptions SHALL be `<Category>: <Title>` from action metadata.

#### Scenario: Core mappings resolve through actions
- **WHEN** the full config has fired `VeryLazy` and each previously configured core lhs is queried in its mode
- **THEN** its mapping invokes the action assigned by `settings/keymap.json`, is non-recursive and silent, and has the action description

#### Scenario: Unadopted built-in mappings are removed
- **WHEN** the full config has fired `VeryLazy` and Neovim default mappings including `grn`, `gra`, `grr`, `gri`, `grt`, `gO`, `]d`, `[q`, and `]q` are queried
- **THEN** each default not assigned to a registered action is absent

#### Scenario: Adopted built-in mappings are registry actions
- **WHEN** an adopted Neovim default lhs including `[d` is queried after `VeryLazy`
- **THEN** it resolves to the action assigned by `settings/keymap.json`, not the built-in mapping

#### Scenario: Surround mappings use registered actions
- **WHEN** nvim-surround is loaded and its configured normal, visual, and operator-pending lhs values are queried
- **THEN** plugin defaults are disabled and each mapping invokes the registered action's `<Plug>` target

