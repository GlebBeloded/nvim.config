## Purpose

Define safe lazy.nvim bootstrap behaviour that preserves explicitly managed plugin versions.

## ADDED Requirements

### Requirement: Plugin specification writes do not update dependencies
Writing a plugin specification SHALL NOT invoke a Lazy command. Dependency updates SHALL remain explicit through the repository's plugin-update workflow.

#### Scenario: Writing plugins.lua runs no Lazy command
- **WHEN** a `plugins.lua` buffer is written after the configuration starts
- **THEN** no `Lazy` command is invoked
