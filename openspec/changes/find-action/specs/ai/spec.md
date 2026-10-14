# Spec Delta

## MODIFIED Requirements

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
- **WHEN** the 99 entry mappings are registered
- **THEN** `<S-CR>` has a silent normal mapping, `<A-9>` and `<S-CR>` have silent visual mappings, and `<A-9>` has no normal mapping

#### Scenario: Select mode keeps its default behavior
- **WHEN** the 99 entry mappings are registered and `<A-9>` or `<S-CR>` is queried in select mode
- **THEN** no 99 entry mapping exists for either key in select mode
