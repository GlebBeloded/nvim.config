# Spec Delta

## MODIFIED Requirements

### Requirement: 99 plugin setup
The config SHALL load the 99 plugin on the `VeryLazy` event, configure it with the Pi provider and model `openai-codex/gpt-5.6-sol`, and then register the prompt keymaps and the entry keymaps. If 99 is unavailable, setup SHALL return without an error.

#### Scenario: Keymaps exist after VeryLazy
- **WHEN** the full config is loaded and the `VeryLazy` user event has fired
- **THEN** `vim.fn.maparg("<A-9>", "n", false, true).desc == "99: Menu"` and `vim.fn.maparg("<S-CR>", "n", false, true).desc == "99: Vibe"`

#### Scenario: Missing 99 is tolerated
- **WHEN** `require("gleb.ai").setup()` is called while the 99 plugin is unavailable
- **THEN** the call returns without an error

### Requirement: 99 entry keymaps
The config SHALL map `<A-9>` in normal mode to a one-key menu that echoes `99> [s]earch [v]ibe: ` (highlight `Question`), reads one key, redraws, and opens the 99 search prompt for `s` or the vibe prompt for `v`, ignoring other keys. It SHALL map `<S-CR>` in normal mode to open the vibe prompt, and `<A-9>` and `<S-CR>` in visual mode only (not select mode) to open the visual-selection prompt. All four mappings SHALL be silent. After opening any prompt it SHALL enter insert mode (scheduled).

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

#### Scenario: Entry mappings are silent
- **WHEN** the 99 entry mappings are registered
- **THEN** `<A-9>` and `<S-CR>` have silent mappings in normal and visual modes

#### Scenario: Select mode keeps its default behavior
- **WHEN** the 99 entry mappings are registered and `<A-9>` or `<S-CR>` is queried in select mode
- **THEN** no 99 entry mapping exists for either key in select mode
