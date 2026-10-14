# select Specification

## Purpose
Configures custom selection interfaces, including the code-action picker.

## Requirements

### Requirement: Code action picker uses its default keymap
The shared code-action picker SHALL give its menu the declared mappings: `j`, `<Down>` and `<Tab>` focus next; `k`, `<Up>` and `<S-Tab>` focus previous; `<Esc>` and `<C-c>` close; `<CR>` and `<Space>` submit.

#### Scenario: Code action menu receives picker mappings
- **WHEN** a shared code-action picker builds its menu
- **THEN** the menu keymap equals the picker's declared default keymap

### Requirement: Selection completion contract
The shared selection interface SHALL accept omitted options and SHALL complete a cancelled code-action selection by invoking its choice callback exactly once with both arguments `nil`.

#### Scenario: Selection accepts omitted options
- **WHEN** `vim.ui.select({ "x" }, nil, on_choice)` is called
- **THEN** the selection request proceeds without raising an error

#### Scenario: Cancelling a code action completes selection
- **WHEN** a code-action selection opened by `vim.ui.select(items, { kind = "codeaction" }, on_choice)` receives `<Esc>` in Normal mode
- **THEN** `on_choice` is called exactly once with `(nil, nil)`

### Requirement: Code action picker fits the editor
The shared code-action picker SHALL set its content width to the greater display width of its formatted items and prompt, plus two columns of padding, capped at `vim.o.columns - 4`.

#### Scenario: Code action popup fits editor width
- **WHEN** code-action popup options are calculated in an 80-column editor for a prompt and formatted items that exercise both short and longer-than-screen content
- **THEN** short content uses its measured display width plus two columns and long content is capped at 76 columns

### Requirement: Selection previews formatted items
The shared selection interface SHALL format each item with `opts.format_item` when supplied and invoke `opts.preview_item` for the current item when supplied.

#### Scenario: Selection previews the current item
- **WHEN** `vim.ui.select` receives `format_item` and `preview_item` callbacks and the current item changes
- **THEN** the row uses the formatted text and `preview_item` is called with the current item

### Requirement: Shared selection runtime integration
The shared selection interface SHALL apply its declared mappings and measured width to the active picker while preserving optional arguments and callback arity.

#### Scenario: Shared code action uses picker mappings
- **WHEN** a code-action selection opens in the shared picker
- **THEN** its active move, choose and stop mappings match the declared picker mappings

#### Scenario: General selection keeps text input mappings
- **WHEN** a selection without `kind = "codeaction"` opens in the shared picker
- **THEN** letters and spaces remain available for its query

#### Scenario: Omitted options open shared selection
- **WHEN** `vim.ui.select({ "x" }, nil, on_choice)` is called
- **THEN** the shared picker opens without raising an error

#### Scenario: Shared code action cancellation preserves callback arity
- **WHEN** a shared code-action picker receives `<Esc>` in Normal mode
- **THEN** its callback is called once with exactly two `nil` arguments

#### Scenario: Selection callback runs in the target window
- **WHEN** an item is chosen while the shared picker float is current
- **THEN** the choice callback runs in the window and buffer that opened the picker

#### Scenario: Formatted code action width configures shared picker
- **WHEN** code-action width is measured from formatted items in an 80-column editor
- **THEN** short content uses its measured width plus padding and long content is capped at 76 columns
