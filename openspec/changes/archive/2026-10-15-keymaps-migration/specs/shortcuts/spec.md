# shortcuts Specification

## ADDED Requirements

### Requirement: Shortcut table action identities
For each Neovim mapping row, the shortcut table's *Mapping* column SHALL name the registered action id, or `none`; `settings/keymap.json` SHALL assign the row's *Neovim receives* lhs to that id. Terminal bytes, zellij routing, received keys, and physical shortcut meanings SHALL remain unchanged.

#### Scenario: Shortcut table names action ids
- **WHEN** every shortcut-table row with a Neovim received key is inspected
- **THEN** its *Mapping* value is `none` or a registered action id whose configured lhs is the row's *Neovim receives* value

#### Scenario: Shortcut meanings survive registry migration
- **WHEN** each passed shortcut is sent through the real zellij stack to a full Neovim config after `VeryLazy`
- **THEN** invoking the received key produces the behavior of the action id in that row

