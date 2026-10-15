# keymaps Specification

## ADDED Requirements

### Requirement: Action-backed core mappings
Core editor behavior SHALL be exposed from feature action lists and assigned only by `settings/keymap.json`. Registry-created mappings SHALL be silent and non-recursive unless their rhs is a `<Plug>` target, and their descriptions SHALL be `<Category>: <Title>` from action metadata.

#### Scenario: Core mappings resolve through actions
- **WHEN** the full config has fired `VeryLazy` and each previously configured core lhs is queried in its mode
- **THEN** its mapping invokes the action assigned by `settings/keymap.json`, is non-recursive and silent, and has the action description

#### Scenario: Unadopted built-in mappings are removed
- **WHEN** the full config has fired `VeryLazy` and Neovim default mappings including `grn`, `gra`, `grr`, `gri`, `grt`, `gO`, `]d`, `[q`, and `]q` are queried
- **THEN** each default not assigned to a registered action is absent

#### Scenario: Adopted built-in mappings are registry actions
- **WHEN** an adopted Neovim default lhs including `[d` is queried after `VeryLazy`
- **THEN** it resolves to the action assigned by `settings/keymap.json`, not the built-in mapping

#### Scenario: Surround mappings use registered actions
- **WHEN** nvim-surround is loaded and its configured normal, visual, and operator-pending lhs values are queried
- **THEN** plugin defaults are disabled and each mapping invokes the registered action's `<Plug>` target

#### Scenario: Counts preserve mapped operations
- **WHEN** counted visual indent, normal comment, and single-fold shortcuts are pressed through their registered mappings
- **THEN** each underlying operation receives the count and repeats accordingly

## MODIFIED Requirements

### Requirement: Mapping options
Every core action mapping SHALL be silent, have a `<Category>: <Title>` description, and be non-recursive unless its rhs is a registered `<Plug>` target.

#### Scenario: Core mappings are noremap and silent
- **WHEN** the full config has fired `VeryLazy` and the mapping for `gb` is queried
- **THEN** it has `noremap == 1` and `silent == 1`

#### Scenario: Every core mapping has an area-action desc
- **WHEN** each configured core action mapping is queried after `VeryLazy`
- **THEN** every description matches the Lua pattern `^%u[%w ]*: %S.*$`

### Requirement: Visual mode editing helpers
The edit action list SHALL keep the selection after `<` and `>`, preserve the unnamed register when visual `p` replaces text, and move selected lines with `J`/`<A-j>` and `K`/`<A-k>`. These actions SHALL be assigned once in `x` mode only, leaving select mode unmapped.

#### Scenario: Indent keeps selection
- **WHEN** lines 1-2 are selected with `Vj` and `>` is pressed
- **THEN** lines 1-2 are indented by one `shiftwidth` and the mode is still linewise visual

#### Scenario: Outdent keeps selection
- **WHEN** lines 1-2 are indented, selected with `Vj`, and `<` is pressed
- **THEN** lines 1-2 are outdented by one `shiftwidth` and the mode is still linewise visual

#### Scenario: Paste over selection keeps register
- **WHEN** the unnamed register contains `foo`, the word `bar` is selected with `viw`, and `p` is pressed
- **THEN** the buffer contains `foo` in place of `bar` and the unnamed register is still `foo`

#### Scenario: Move selected lines down
- **WHEN** line 1 of `a`, `b`, `c` is selected and `J` or `<A-j>` is pressed
- **THEN** the lines become `b`, `a`, `c` and the mode is visual

#### Scenario: Move selected lines up
- **WHEN** line 3 of `a`, `b`, `c` is selected and `K` or `<A-k>` is pressed
- **THEN** the lines become `a`, `c`, `b` and the mode is visual

#### Scenario: Alt-j moves selected lines down
- **WHEN** a buffer contains lines `a`, `b`, `c`, line 1 is selected with `V`, and `<A-j>` is pressed
- **THEN** the buffer lines are `b`, `a`, `c` and the mode is visual

#### Scenario: Alt-k moves selected lines up
- **WHEN** a buffer contains lines `a`, `b`, `c`, line 3 is selected with `V`, and `<A-k>` is pressed
- **THEN** the buffer lines are `a`, `c`, `b` and the mode is visual

#### Scenario: Visual helpers are not mapped in select mode
- **WHEN** the full config is loaded and each visual-helper lhs is queried in select mode
- **THEN** each returns no mapping

#### Scenario: Typing p in select mode inserts p
- **WHEN** select mode covers the first character of `bar baz` and `p` is typed while the unnamed register contains `foo`
- **THEN** the buffer line is `par baz` and the mode is Insert
