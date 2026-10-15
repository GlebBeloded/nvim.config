# ai Specification

## Purpose
AI-assisted editing through the ThePrimeagen/99 plugin backed by the Pi CLI: a custom Pi provider (`lua/gleb/ai/pi_provider.lua`), entry keymaps for search/vibe/visual prompts, and a Shift+Enter submit keymap inside 99 prompt buffers (`lua/gleb/ai/prompt_keymaps.lua`), wired in `lua/gleb/plugins/plugins.lua`.

## Requirements

### Requirement: Pi provider command
The config SHALL provide a 99 provider that runs the `pi` CLI ephemerally with low thinking, building the command `pi --no-session --model <context.model> --thinking low --print <query>`, naming itself `PiProvider`, and defaulting to model `openai-codex/gpt-5.6-sol`.

#### Scenario: runs Pi ephemerally with low thinking
- **WHEN** `require("gleb.ai.pi_provider")._build_command(nil, "test query", { model = "openai-codex/gpt-5.6-sol" })` is called
- **THEN** it returns `{ "pi", "--no-session", "--model", "openai-codex/gpt-5.6-sol", "--thinking", "low", "--print", "test query" }`

#### Scenario: defaults to Codex Sol
- **WHEN** `require("gleb.ai.pi_provider")._get_default_model()` is called
- **THEN** it returns `"openai-codex/gpt-5.6-sol"`

#### Scenario: Provider name
- **WHEN** `require("gleb.ai.pi_provider")._get_provider_name()` is called
- **THEN** it returns `"PiProvider"`

#### Scenario: Provider inherits base provider
- **WHEN** a key absent from the Pi provider table is indexed on it
- **THEN** the value is looked up on `require("99").Providers.BaseProvider`

### Requirement: 99 plugin setup
The config SHALL load 99 on `VeryLazy`, configure it with the Pi provider, model `openai-codex/gpt-5.6-sol` and native completion source, then register prompt mappings, entry mappings, and actions. 99 SHALL not depend on Telescope. If 99 is unavailable, setup SHALL return without an error.

#### Scenario: Keymaps exist after VeryLazy
- **WHEN** the full config is loaded and the `VeryLazy` user event has fired
- **THEN** normal `<A-9>` is unmapped, normal `<S-CR>` is described as `99: Vibe`, and visual `<A-9>` and `<S-CR>` are described as `99: Visual`

#### Scenario: Missing 99 is tolerated
- **WHEN** `require("gleb.ai").setup()` is called while the 99 plugin is unavailable
- **THEN** the call returns without an error

#### Scenario: 99 uses native completion
- **WHEN** `require("gleb.ai").setup()` configures the available 99 plugin
- **THEN** its completion source is `native`

### Requirement: 99 entry keymaps
The config SHALL register 99 Search and 99 Vibe as actions and leave `<A-9>` unmapped in normal mode. It SHALL keep normal `<S-CR>` and visual `<S-CR>`/`<A-9>` prompt mappings silent, enter insert mode after opening a prompt, and leave select mode unchanged.

#### Scenario: Menu shows prompt
- **WHEN** the normal-mode `<A-9>` mapping is queried after 99 entry setup
- **THEN** no mapping or one-key menu prompt exists

#### Scenario: Menu s opens search prompt
- **WHEN** the registered 99 Search action is run
- **THEN** a 99 prompt buffer for search is focused and the mode is insert

#### Scenario: Menu v opens vibe prompt
- **WHEN** the registered 99 Vibe action is run
- **THEN** a 99 prompt buffer for vibe is focused and the mode is insert

#### Scenario: Menu ignores other keys
- **WHEN** `<A-9>` then `x` is pressed in normal mode after 99 entry setup
- **THEN** no 99 prompt buffer or one-key menu is opened

#### Scenario: Shift-Enter opens vibe prompt
- **WHEN** `<S-CR>` is pressed in normal mode in a non-99 buffer
- **THEN** a 99 prompt buffer for vibe is focused and the mode is insert

#### Scenario: Visual Alt-9 opens visual prompt
- **WHEN** a line is selected with `V` and `<A-9>` is pressed
- **THEN** a 99 prompt buffer for the visual selection is focused and the mode is insert

#### Scenario: Visual Shift-Enter opens visual prompt
- **WHEN** a line is selected with `V` and `<S-CR>` is pressed
- **THEN** a 99 prompt buffer for the visual selection is focused and the mode is insert

#### Scenario: Entry mappings are silent
- **WHEN** the full config has fired `VeryLazy` and the registered 99 entry mappings are queried
- **THEN** `<S-CR>` has a silent normal mapping, `<A-9>` and `<S-CR>` have silent visual mappings, and `<A-9>` has no normal mapping

#### Scenario: Select mode keeps its default behavior
- **WHEN** the 99 entry mappings are registered and `<A-9>` or `<S-CR>` is queried in select mode
- **THEN** no 99 entry mapping exists for either key in select mode

### Requirement: Prompt submit keymap
The config SHALL, on `FileType` `99` (augroup `gleb_ai_prompt_keymaps`, cleared on each setup), map `<S-CR>` buffer-locally in normal and insert modes to `<Cmd>write<CR>` with description `99: Submit prompt`, overriding the global `<S-CR>` vibe mapping inside prompt buffers.

#### Scenario: submits with Shift+Enter in normal and insert modes
- **WHEN** `require("gleb.ai.prompt_keymaps").setup()` is called, then `:enew` and `vim.bo.filetype = "99"`
- **THEN** `vim.fn.maparg("<S-CR>", "n")` and `vim.fn.maparg("<S-CR>", "i")` both equal `<Cmd>write<CR>`

#### Scenario: Submit mapping is buffer-local
- **WHEN** after the previous scenario, `:enew` creates a buffer with filetype other than `99`
- **THEN** that buffer has no buffer-local `<S-CR>` mapping

#### Scenario: Setup is idempotent
- **WHEN** `require("gleb.ai.prompt_keymaps").setup()` is called twice
- **THEN** `vim.api.nvim_get_autocmds({ group = "gleb_ai_prompt_keymaps" })` returns exactly one autocmd

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
