# Spec Delta

## ADDED Requirements

### Requirement: Terminal paste respects buffer mutability
Terminal paste SHALL leave an unmodifiable buffer unchanged without raising an error. In a modifiable buffer, terminal paste SHALL retain Neovim's normal insertion behaviour.

#### Scenario: Terminal paste ignores a read-only project tree
- **WHEN** the populated project tree is focused with `'modifiable'` off and `vim.paste({ "probe" }, -1)` is called
- **THEN** the tree lines stay unchanged and the call does not raise an error

#### Scenario: Terminal paste edits a normal buffer
- **WHEN** a normal modifiable buffer is focused and `vim.paste({ "probe" }, -1)` is called
- **THEN** `probe` is inserted using Neovim's normal paste behaviour
