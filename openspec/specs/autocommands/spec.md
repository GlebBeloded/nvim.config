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
