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
The config SHALL load the 99 plugin on the `VeryLazy` event, configure it with the Pi provider and model `openai-codex/gpt-5.6-sol`, and then register the prompt keymaps and the entry keymaps.

#### Scenario: Keymaps exist after VeryLazy
- **WHEN** the full config is loaded and the `VeryLazy` user event has fired
- **THEN** `vim.fn.maparg("<A-9>", "n", false, true).desc == "99: Menu"` and `vim.fn.maparg("<S-CR>", "n", false, true).desc == "99: Vibe"`

### Requirement: 99 entry keymaps
The config SHALL map `<A-9>` in normal mode to a one-key menu that echoes `99> [s]earch [v]ibe: ` (highlight `Question`), reads one key, redraws, and opens the 99 search prompt for `s` or the vibe prompt for `v`, doing nothing for any other key. It SHALL map `<S-CR>` in normal mode to open the vibe prompt, and `<A-9>` and `<S-CR>` in visual mode to open the visual prompt for the selection. After opening any prompt it SHALL enter insert mode (scheduled).

#### Scenario: Menu shows prompt
- **WHEN** `<A-9>` is pressed in normal mode
- **THEN** the message area shows `99> [s]earch [v]ibe: `

#### Scenario: Menu s opens search prompt
- **WHEN** `<A-9>` then `s` is pressed in normal mode
- **THEN** a 99 prompt buffer for search is focused and the mode is insert

#### Scenario: Menu v opens vibe prompt
- **WHEN** `<A-9>` then `v` is pressed in normal mode
- **THEN** a 99 prompt buffer for vibe is focused and the mode is insert

#### Scenario: Menu ignores other keys
- **WHEN** `<A-9>` then `x` is pressed in normal mode
- **THEN** no 99 prompt buffer is opened and the mode is normal

#### Scenario: Shift-Enter opens vibe prompt
- **WHEN** `<S-CR>` is pressed in normal mode in a non-99 buffer
- **THEN** a 99 prompt buffer for vibe is focused and the mode is insert

#### Scenario: Visual Alt-9 opens visual prompt
- **WHEN** a line is selected with `V` and `<A-9>` is pressed
- **THEN** a 99 prompt buffer for the visual selection is focused and the mode is insert

#### Scenario: Visual Shift-Enter opens visual prompt
- **WHEN** a line is selected with `V` and `<S-CR>` is pressed
- **THEN** a 99 prompt buffer for the visual selection is focused and the mode is insert

### Requirement: Prompt submit keymap
The config SHALL, on `FileType` `99` (augroup `99PromptKeymaps`, cleared on each setup), map `<S-CR>` buffer-locally in normal and insert modes to `<Cmd>write<CR>` with description `99: Submit prompt`, overriding the global `<S-CR>` vibe mapping inside prompt buffers.

#### Scenario: submits with Shift+Enter in normal and insert modes
- **WHEN** `require("gleb.ai.prompt_keymaps").setup()` is called, then `:enew` and `vim.bo.filetype = "99"`
- **THEN** `vim.fn.maparg("<S-CR>", "n")` and `vim.fn.maparg("<S-CR>", "i")` both equal `<Cmd>write<CR>`

#### Scenario: Submit mapping is buffer-local
- **WHEN** after the previous scenario, `:enew` creates a buffer with filetype other than `99`
- **THEN** that buffer has no buffer-local `<S-CR>` mapping

#### Scenario: Setup is idempotent
- **WHEN** `require("gleb.ai.prompt_keymaps").setup()` is called twice
- **THEN** `vim.api.nvim_get_autocmds({ group = "99PromptKeymaps" })` returns exactly one autocmd
