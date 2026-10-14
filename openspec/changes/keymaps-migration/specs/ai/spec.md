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

## MODIFIED Requirements

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
