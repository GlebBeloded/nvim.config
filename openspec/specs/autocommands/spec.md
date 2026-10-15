# autocommands Specification

## Purpose
Defines editor event behaviour that keeps automatic actions scoped to the buffer and services that can perform them.

## Requirements

### Requirement: Format on manual save
The config SHALL request formatting before a manual save only when the saved buffer has a language server that supports document formatting. It SHALL scope both the eligibility check and formatting request to that buffer.

#### Scenario: Saving without a formatting server is silent
- **WHEN** `:write` triggers `BufWritePre` for a buffer with no language server that supports document formatting
- **THEN** the buffer is written without a format request or an LSP failure message

#### Scenario: Saving with a formatting server formats the buffer
- **WHEN** `:write` triggers `BufWritePre` for a buffer with a language server that supports document formatting
- **THEN** that buffer is formatted before it is written

### Requirement: Special-buffer close action
The close behavior for `qf`, `help`, `man`, and `lspinfo` buffers SHALL be a filetype-scoped action assigned by `settings/keymap.json`, not a keymap created directly by the autocmd module.

#### Scenario: q closes special buffers through an action
- **WHEN** a `qf`, `help`, `man`, or `lspinfo` buffer is entered after `VeryLazy` and `q` is pressed in normal mode
- **THEN** the window closes through the registered filetype action and the mapping is buffer-local
