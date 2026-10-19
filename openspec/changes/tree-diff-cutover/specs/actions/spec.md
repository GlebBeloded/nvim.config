## MODIFIED Requirements

### Requirement: Exclusive shortcut ownership
After `VeryLazy`, every global or plugin-window mapping in modes `n`, `x`, `s`, `o`, `i`, `c`, and `t` SHALL resolve to an action id in `settings/keymap.json` or an explicit allowlist. The allowlist SHALL contain only Neovim grammar, Mason navigation, lazy.nvim view operations, autopairs insertion, and 99's hardcoded `q` and `<CR>`. A plugin-surface open that blocks SHALL fail its test within 10 seconds with the surface name and recorded child state.

#### Scenario: Every configured mapping is action-owned
- **WHEN** the full config has fired `VeryLazy` and global mappings in modes `n`, `x`, `s`, `o`, `i`, `c`, and `t` are enumerated
- **THEN** each configured mapping resolves to one registered action and one lhs assigned to that action in `settings/keymap.json`, or is on the explicit allowlist

#### Scenario: Plugin-window mappings are action-owned
- **WHEN** project tree, changes panel, diff view, dap-ui, diffview, neotest, mason, lazy, blink, and copilot windows are opened with populated data
- **THEN** each mapping resolves to its registered action and current lhs, or exactly matches an allowlisted Mason navigation, lazy.nvim view, autopairs insertion, or 99 `q`/`<CR>` mapping; if a window blocks while opening, the test fails within 10 seconds with that surface's recorded child state; the blocked-open regression reports phase `opening` and live subprocess command lines, then stops its Neovim child and descendants even if the open returns before the deadline

#### Scenario: Unconfigured defaults are absent
- **WHEN** the full config has fired `VeryLazy` and Neovim and plugin mappings are enumerated
- **THEN** unadopted Neovim defaults and disabled plugin default mappings are absent

#### Scenario: Lazy specs define no shortcut keys
- **WHEN** every plugin spec returned by `lua/gleb/plugins/plugins.lua` is inspected
- **THEN** none has a `keys` field
