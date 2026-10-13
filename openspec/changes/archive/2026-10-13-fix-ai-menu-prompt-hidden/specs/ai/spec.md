## MODIFIED Requirements

### Requirement: 99 entry keymaps
The config SHALL map `<A-9>` in normal mode to a one-key menu whose `Question`-highlighted prompt remains visible while it waits, including when `cmdheight` starts at zero. It SHALL dispatch `s` to search and `v` to vibe, ignore other keys, restore the prior `cmdheight`, keep the normal and visual `<S-CR>`/`<A-9>` prompt mappings silent, and enter insert mode after opening a prompt.

#### Scenario: Menu shows prompt
- **WHEN** `<A-9>` is pressed in normal mode with `cmdheight = 0`
- **THEN** the message area shows `99> [s]earch [v]ibe: ` while the menu waits for a key

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
