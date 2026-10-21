# plugins Specification

## Purpose
Define safe lazy.nvim bootstrap behaviour that preserves explicitly managed plugin versions.

## Requirements

### Requirement: Plugin specification writes do not update dependencies
Writing a plugin specification SHALL NOT invoke a Lazy command. Dependency updates SHALL remain explicit through the repository's plugin-update workflow.

#### Scenario: Writing plugins.lua runs no Lazy command
- **WHEN** a `plugins.lua` buffer is written after the configuration starts
- **THEN** no `Lazy` command is invoked

### Requirement: Real configuration starts within the snappy budget
Neovim SHALL complete a warmed, isolated startup of the real configuration within a 120 ms base budget. The measurement SHALL normalize the budget for current host load and SHALL exclude dependency installation and cold-cache setup.

#### Scenario: Warm real-config startup stays within budget
- **WHEN** `make smoke-startup` launches the real configuration after its warm-up start
- **THEN** the measured startup passes the 120 ms base budget after host-load normalization
