# autocommands Specification

## ADDED Requirements

### Requirement: Special-buffer close action
The close behavior for `qf`, `help`, `man`, and `lspinfo` buffers SHALL be a filetype-scoped action assigned by `settings/keymap.json`, not a keymap created directly by the autocmd module.

#### Scenario: q closes special buffers through an action
- **WHEN** a `qf`, `help`, `man`, or `lspinfo` buffer is entered after `VeryLazy` and `q` is pressed in normal mode
- **THEN** the window closes through the registered filetype action and the mapping is buffer-local

