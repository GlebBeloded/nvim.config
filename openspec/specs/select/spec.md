# select Specification

## Purpose
Configures custom selection interfaces, including the code-action picker.

## Requirements

### Requirement: Code action picker uses its default keymap
The code-action picker SHALL give its menu the declared mappings: `j`, `<Down>` and `<Tab>` focus next; `k`, `<Up>` and `<S-Tab>` focus previous; `<Esc>` and `<C-c>` close; `<CR>` and `<Space>` submit.

#### Scenario: Code action menu receives picker mappings
- **WHEN** a code-action picker builds its menu
- **THEN** the menu keymap equals the picker's declared default keymap
