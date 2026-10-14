# ai Specification

## ADDED Requirements

### Requirement: AI shortcut ownership
99 entry and prompt-submit mappings SHALL be registered actions assigned through `settings/keymap.json`. Prompt-submit SHALL remain buffer-local to filetype `99`. The plugin's hardcoded `q` and `<CR>` window mappings SHALL remain the only 99 mapping exceptions on the ownership allowlist.

#### Scenario: 99 entry mappings come from AI actions
- **WHEN** the full config has fired `VeryLazy` and the configured normal and visual 99 entry lhs values are queried
- **THEN** each mapping invokes the AI action assigned by `settings/keymap.json` with the action description

#### Scenario: Prompt submit comes from a filetype action
- **WHEN** a buffer enters filetype `99` after `VeryLazy`
- **THEN** its configured submit lhs is buffer-local in normal and insert modes and invokes the registered submit action

#### Scenario: 99 hardcoded mappings are the only exceptions
- **WHEN** a populated 99 plugin window's mappings are compared with registry ownership
- **THEN** only the plugin-hardcoded `q` and `<CR>` mappings may lack action ownership

