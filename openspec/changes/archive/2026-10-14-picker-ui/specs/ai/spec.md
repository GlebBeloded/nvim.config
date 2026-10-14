## MODIFIED Requirements

### Requirement: 99 plugin setup
The config SHALL load 99 on `VeryLazy`, configure it with the Pi provider, model `openai-codex/gpt-5.6-sol` and native completion source, then register prompt and entry keymaps. 99 SHALL not depend on Telescope. If 99 is unavailable, setup SHALL return without an error.

#### Scenario: Keymaps exist after VeryLazy
- **WHEN** the full config is loaded and the `VeryLazy` user event has fired
- **THEN** `vim.fn.maparg("<A-9>", "n", false, true).desc == "99: Menu"` and `vim.fn.maparg("<S-CR>", "n", false, true).desc == "99: Vibe"`

#### Scenario: Missing 99 is tolerated
- **WHEN** `require("gleb.ai").setup()` is called while the 99 plugin is unavailable
- **THEN** the call returns without an error

#### Scenario: 99 uses native completion
- **WHEN** `require("gleb.ai").setup()` configures the available 99 plugin
- **THEN** its completion source is `native`
