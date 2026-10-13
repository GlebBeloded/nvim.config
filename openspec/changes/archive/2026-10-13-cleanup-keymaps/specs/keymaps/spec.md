## MODIFIED Requirements

### Requirement: Mapping options
The config SHALL define every keymap in `lua/gleb/keymaps.lua` as non-recursive (`noremap`) and silent, with a `desc` of the form `<Area>: <Action>` (a capitalised area, a colon, a space, then a non-empty action, e.g. `Window: Move left`, `LSP: Rename`).

#### Scenario: Core mappings are noremap and silent
- **WHEN** the full config is loaded and `vim.fn.maparg("gb", "n", false, true)` is called
- **THEN** the returned dict has `noremap == 1` and `silent == 1`

#### Scenario: Every core mapping has an area-action desc
- **WHEN** the full config is loaded and `vim.fn.maparg(lhs, mode, false, true).desc` is read for each of: normal `<C-h>`, `<A-j>`, `<A-k>`, `<C-l>`, `gb`, `gB`, `<C-Up>`, `<C-Down>`, `<C-Left>`, `<C-Right>`, `<A-H>`, `<A-J>`, `<A-K>`, `<A-L>`, `<C-q>`, `<A-e>`, `<A-g>`, `<A-G>`, `<A-F>`, `<C-CR>`, `gD`, `gd`, `K`, `gi`, `gr`, `<A-r>`, `<A-w>`, `[d`, `ge`; insert `jk`; visual (`x`) `<`, `>`, `p`, `J`, `K`, `<A-j>`, `<A-k>`, `<C-CR>`
- **THEN** every `desc` matches the Lua pattern `^%u[%w ]*: %S.*$`

### Requirement: Window resizing
The config SHALL map, in normal mode, `<C-Up>`/`<C-Down>` to `:resize +2`/`:resize -2`, `<C-Left>`/`<C-Right>` to `:vertical resize -2`/`:vertical resize +2`, and `<A-H>`, `<A-J>`, `<A-K>`, `<A-L>` to smart-splits resize left, down, up and right. No other module SHALL map `<A-H>`, `<A-J>`, `<A-K>` or `<A-L>` in normal mode.

#### Scenario: Increase height
- **WHEN** two windows exist stacked (`:split`) and `<C-Up>` is pressed in normal mode in the top window
- **THEN** the top window height increases by 2

#### Scenario: Decrease height
- **WHEN** two windows exist stacked (`:split`) and `<C-Down>` is pressed in normal mode in the top window
- **THEN** the top window height decreases by 2

#### Scenario: Decrease width
- **WHEN** two windows exist side by side (`:vsplit`) and `<C-Left>` is pressed in normal mode in the left window
- **THEN** the left window width decreases by 2

#### Scenario: Increase width
- **WHEN** two windows exist side by side (`:vsplit`) and `<C-Right>` is pressed in normal mode in the left window
- **THEN** the left window width increases by 2

#### Scenario: Smart-splits resize changes window size
- **WHEN** two windows exist side by side (`:vsplit`), the cursor is in the left window, and `<A-L>` is pressed in normal mode
- **THEN** the left window width differs from its width before the key press

#### Scenario: Smart-splits resize keys are not remapped
- **WHEN** the full config is loaded (including `gleb.debugging`) and `vim.fn.maparg(lhs, "n", false, true).callback` is read for `<A-H>`, `<A-J>`, `<A-K>`, `<A-L>`
- **THEN** the callbacks equal `require("smart-splits").resize_left`, `resize_down`, `resize_up`, `resize_right` respectively

### Requirement: Buffer close
The config SHALL map `<C-q>` in normal mode to close the current buffer while keeping the window layout (vim-bbye `:Bdelete`): every window that showed the buffer stays open and shows another buffer. A modified buffer SHALL NOT be closed.

#### Scenario: Close current buffer
- **WHEN** two listed buffers exist, the current one is unmodified, and `<C-q>` is pressed in normal mode
- **THEN** the previously current buffer is no longer listed

#### Scenario: Close buffer keeps split layout
- **WHEN** two listed unmodified buffers `a` and `b` exist, `b` is current, `:vsplit` shows `b` in both windows, and `<C-q>` is pressed in normal mode
- **THEN** two windows still exist, neither shows `b`, and `b` is no longer listed

#### Scenario: Close modified buffer is refused
- **WHEN** two listed buffers exist, the current one is modified, and `<C-q>` is pressed in normal mode
- **THEN** the current buffer is unchanged, still listed, and still modified

#### Scenario: Close buffer in split matches reference screenshot
- **WHEN** an 80x12 screen shows `sample.lua` in two `:vsplit` windows, `init.lua` is the other listed buffer, and `<C-q>` is pressed in normal mode
- **THEN** the screen text equals the approved Proposed render of `design.md` (both windows show `init.lua`, the bufferline lists only `init.lua`)

## ADDED Requirements

### Requirement: Normal-mode command maps bypass the command line
The config SHALL run the Ex commands behind the normal-mode maps `<C-Up>`, `<C-Down>`, `<C-Left>`, `<C-Right>`, `<C-q>`, `<A-g>` and `<A-F>` without entering the command line, so no `CmdlineEnter` event fires and the command line is not redrawn with the command.

#### Scenario: Command maps do not enter the command line
- **WHEN** two windows exist stacked (`:split`), a `CmdlineEnter` autocmd counts its events, and `<C-Up>`, `<C-Down>`, `<C-Left>` and `<C-Right>` are pressed in normal mode
- **THEN** the `CmdlineEnter` count is 0
