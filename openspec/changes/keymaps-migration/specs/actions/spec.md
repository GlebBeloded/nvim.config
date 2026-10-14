# actions Specification

## ADDED Requirements

### Requirement: Exclusive shortcut ownership
After `VeryLazy`, the action registry SHALL be the only source of configured mappings in modes `n`, `x`, `s`, `o`, `i`, `c`, and `t`. Every such global or plugin-window mapping SHALL resolve to an action id in `settings/keymap.json`, except Neovim grammar mappings and 99's hardcoded `q` and `<CR>` window mappings on an explicit allowlist.

#### Scenario: Every configured mapping is action-owned
- **WHEN** the full config has fired `VeryLazy` and global mappings in modes `n`, `x`, `s`, `o`, `i`, `c`, and `t` are enumerated
- **THEN** each configured mapping resolves to one registered action and one lhs assigned to that action in `settings/keymap.json`, or is on the explicit allowlist

#### Scenario: Plugin-window mappings are action-owned
- **WHEN** neo-tree, dap-ui, diffview, differ, codediff, neotest, mason, lazy, blink, and copilot windows are opened with populated data
- **THEN** each configured plugin-window mapping resolves to its registered action and current lhs in `settings/keymap.json`, or is one of 99's allowlisted `q` and `<CR>` mappings

#### Scenario: Unconfigured defaults are absent
- **WHEN** the full config has fired `VeryLazy` and Neovim and plugin mappings are enumerated
- **THEN** unadopted Neovim defaults and disabled plugin default mappings are absent

#### Scenario: Lazy specs define no shortcut keys
- **WHEN** every plugin spec returned by `lua/gleb/plugins/plugins.lua` is inspected
- **THEN** none has a `keys` field

### Requirement: Feature-owned action lists
Each feature that exposes configurable behavior SHALL define actions in its `actions.lua`; action definitions SHALL contain behavior and metadata but no lhs. Startup SHALL assemble those lists before applying `settings/keymap.json`.

#### Scenario: Feature actions contain no shortcut keys
- **WHEN** every feature `actions.lua` list registered at startup is inspected
- **THEN** every action has a valid id and behavior and none contains an lhs or shortcut field

#### Scenario: Every configured action is registered
- **WHEN** `settings/keymap.json` is loaded against the startup action catalog
- **THEN** every action id in the file resolves without an unknown-action warning

