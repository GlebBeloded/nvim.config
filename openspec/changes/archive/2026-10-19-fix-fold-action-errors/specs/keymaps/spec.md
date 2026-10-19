# Spec Delta

## ADDED Requirements

### Requirement: Terminal paste respects buffer mutability
When terminal paste would edit the current buffer, it SHALL leave an unmodifiable buffer unchanged without raising an error. Paste routed to a modifiable buffer, terminal job, or command line SHALL retain Neovim's normal behaviour.

#### Scenario: Terminal paste ignores a read-only project tree
- **WHEN** the populated project tree is focused with `'modifiable'` off and `vim.paste({ "probe" }, -1)` is called
- **THEN** the tree lines stay unchanged and the call does not raise an error

#### Scenario: Terminal paste edits a normal buffer
- **WHEN** a normal modifiable buffer is focused and `vim.paste({ "probe" }, -1)` is called
- **THEN** `probe` is inserted using Neovim's normal paste behaviour

#### Scenario: Terminal paste writes to a terminal buffer
- **WHEN** a terminal buffer is focused and `vim.paste({ "probe" }, -1)` is called
- **THEN** `probe` is sent to the terminal job using Neovim's normal paste behaviour

#### Scenario: Terminal paste edits the command line from a read-only project tree
- **WHEN** the populated project tree is focused, command-line mode is entered, and `vim.paste({ "probe" }, -1)` is called
- **THEN** `probe` is inserted into the command line using Neovim's normal paste behaviour
