# keymaps Specification

## Purpose
Global editor keymaps defined in `lua/gleb/keymaps.lua`: window navigation and resizing, jump list, buffer close, editing helpers in insert/visual modes, file-tree/git/search entry points, LSP and diagnostics navigation, and leader keys. All mappings in this file are non-recursive and silent.

## Requirements

### Requirement: Mapping options
The config SHALL define every keymap in `lua/gleb/keymaps.lua` as non-recursive (`noremap`) and silent, with a `desc` of the form `<Area>: <Action>` (a capitalised area, a colon, a space, then a non-empty action, e.g. `Window: Move left`, `LSP: Rename`).

#### Scenario: Core mappings are noremap and silent
- **WHEN** the full config is loaded and `vim.fn.maparg("gb", "n", false, true)` is called
- **THEN** the returned dict has `noremap == 1` and `silent == 1`

#### Scenario: Every core mapping has an area-action desc
- **WHEN** the full config is loaded and `vim.fn.maparg(lhs, mode, false, true).desc` is read for each of: normal `<C-h>`, `<A-j>`, `<A-k>`, `<C-l>`, `gb`, `gB`, `<C-Up>`, `<C-Down>`, `<C-Left>`, `<C-Right>`, `<A-H>`, `<A-J>`, `<A-K>`, `<A-L>`, `<C-q>`, `<A-e>`, `<A-g>`, `<A-G>`, `<A-F>`, `<C-CR>`, `gD`, `gd`, `K`, `gi`, `gr`, `<A-r>`, `<A-w>`, `[d`, `ge`; insert `jk`; visual (`x`) `<`, `>`, `p`, `J`, `K`, `<A-j>`, `<A-k>`, `<C-CR>`
- **THEN** every `desc` matches the Lua pattern `^%u[%w ]*: %S.*$`

### Requirement: Leader keys
The config SHALL set `g:mapleader` to Space (`" "`) and `g:maplocalleader` to `\` in `init.lua` before lazy.nvim is set up, so every `<leader>` map a plugin defines while loading binds to Space.

#### Scenario: Leader values after startup
- **WHEN** the full config is loaded and `vim.g.mapleader` and `vim.g.maplocalleader` are read
- **THEN** `vim.g.mapleader == " "` and `vim.g.maplocalleader == "\\"`

#### Scenario: Leader is set before lazy.nvim loads plugins
- **WHEN** the full config is started with a `--cmd` hook that wraps `require("lazy").setup` to record `vim.g.mapleader` at call time
- **THEN** the recorded value is `" "`

#### Scenario: Leader is set before the debug log starts
- **WHEN** the full config is started with a `--cmd` hook that wraps `require("gleb.nvim_debug_log").setup` to record `vim.g.mapleader` at call time
- **THEN** the setup wrapper ran exactly once and the recorded value is `" "`

### Requirement: Window navigation
The config SHALL map, in normal mode, `<C-h>`, `<A-j>`, `<A-k>` and `<C-l>` to move the cursor to the window left, below, above and right respectively (via smart-splits, stopping at the edge rather than wrapping).

#### Scenario: Move to left window
- **WHEN** two windows exist side by side (`:vsplit`), the cursor is in the right window, and `<C-h>` is pressed in normal mode
- **THEN** the current window is the left window

#### Scenario: Move to window below
- **WHEN** two windows exist stacked (`:split`), the cursor is in the top window, and `<A-j>` is pressed in normal mode
- **THEN** the current window is the bottom window

#### Scenario: Move to window above
- **WHEN** two windows exist stacked (`:split`), the cursor is in the bottom window, and `<A-k>` is pressed in normal mode
- **THEN** the current window is the top window

#### Scenario: Move to right window
- **WHEN** two windows exist side by side (`:vsplit`), the cursor is in the left window, and `<C-l>` is pressed in normal mode
- **THEN** the current window is the right window

#### Scenario: Navigation stops at edge
- **WHEN** only one window exists and `<C-l>` is pressed in normal mode
- **THEN** the current window is unchanged

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

### Requirement: Jump list navigation
The config SHALL map `gb` in normal mode to jump to the older jump-list position (`<C-O>`) and `gB` to the newer position (`<C-I>`).

#### Scenario: gb jumps back
- **WHEN** a buffer has 100 lines, the cursor is on line 1, `G` is pressed, then `gb` is pressed in normal mode
- **THEN** the cursor is on line 1

#### Scenario: gB jumps forward
- **WHEN** after the "gb jumps back" sequence, `gB` is pressed in normal mode
- **THEN** the cursor is on line 100

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

### Requirement: Insert mode escape
The config SHALL map `jk` in insert mode to `<Esc>`.

#### Scenario: jk leaves insert mode
- **WHEN** in insert mode in an empty buffer and `jk` is typed
- **THEN** the mode is normal and the buffer line is empty

### Requirement: Visual mode editing helpers
The config SHALL keep the selection after `<` and `>` in visual mode, SHALL make `p` in visual mode replace the selection without overwriting the unnamed register, and SHALL map `J`/`<A-j>` and `K`/`<A-k>` in visual mode (`x`) to move the selected lines down/up by one line while keeping visual mode. Each of these SHALL be mapped once, in `x` mode only, so that select mode has no mapping from `lua/gleb/keymaps.lua` and typed characters replace the selection.

#### Scenario: Indent keeps selection
- **WHEN** lines 1-2 are selected with `Vj` and `>` is pressed
- **THEN** lines 1-2 are indented by one `shiftwidth` and the mode is still linewise visual

#### Scenario: Outdent keeps selection
- **WHEN** lines 1-2 are indented, selected with `Vj`, and `<` is pressed
- **THEN** lines 1-2 are outdented by one `shiftwidth` and the mode is still linewise visual

#### Scenario: Paste over selection keeps register
- **WHEN** the unnamed register contains `foo`, the word `bar` is selected with `viw`, and `p` is pressed
- **THEN** the buffer contains `foo` in place of `bar` and `getreg('"')` is still `foo`

#### Scenario: Move selected lines down
- **WHEN** a buffer contains lines `a`, `b`, `c`, line 1 is selected with `V`, and `J` is pressed
- **THEN** the buffer lines are `b`, `a`, `c` and the mode is visual

#### Scenario: Move selected lines up
- **WHEN** a buffer contains lines `a`, `b`, `c`, line 3 is selected with `V`, and `K` is pressed
- **THEN** the buffer lines are `a`, `c`, `b` and the mode is visual

#### Scenario: Alt-j moves selected lines down
- **WHEN** a buffer contains lines `a`, `b`, `c`, line 1 is selected with `V`, and `<A-j>` is pressed
- **THEN** the buffer lines are `b`, `a`, `c` and the mode is visual

#### Scenario: Alt-k moves selected lines up
- **WHEN** a buffer contains lines `a`, `b`, `c`, line 3 is selected with `V`, and `<A-k>` is pressed
- **THEN** the buffer lines are `a`, `c`, `b` and the mode is visual

#### Scenario: Visual helpers are not mapped in select mode
- **WHEN** the full config is loaded and `vim.fn.maparg(lhs, "s")` is read for `<`, `>`, `p`, `<A-j>`, `<A-k>`, `<C-CR>`
- **THEN** each returns `""`

#### Scenario: Typing p in select mode inserts p
- **WHEN** the full config is loaded, the unnamed register contains `foo`, the buffer line is `bar baz` with the cursor on column 1, and `v` then `<C-g>` (Select mode) then `p` is typed
- **THEN** the buffer line is `par baz` and the mode is Insert

### Requirement: File tree and git panel toggles
The config SHALL map `<A-e>` in normal mode to a smart neo-tree toggle for the `filesystem` source and `<A-G>` to the same toggle for the `git_status` source. When the current window is neo-tree, the toggle SHALL close it if it shows the requested source and otherwise switch it to that source. When the current window is not neo-tree, the toggle SHALL focus neo-tree on the requested source, revealing the current file for `filesystem` unless the buffer has no name or is a `scheme://` URI.

#### Scenario: Alt-e reveals current file
- **WHEN** a file `foo.lua` is being edited and `<A-e>` is pressed in normal mode
- **THEN** the current window has `filetype` `neo-tree`, its buffer name contains `neo-tree filesystem`, and the cursor line refers to `foo.lua`

#### Scenario: Alt-e on URI buffer focuses filesystem
- **WHEN** the current buffer is named `vscodediff://x` and `<A-e>` is pressed in normal mode
- **THEN** the current window is a neo-tree `filesystem` window and no error is reported

#### Scenario: Alt-e closes focused filesystem tree
- **WHEN** the current window is the neo-tree `filesystem` window and `<A-e>` is pressed in normal mode
- **THEN** no window with `filetype` `neo-tree` remains

#### Scenario: Alt-G switches tree to git status
- **WHEN** the current window is the neo-tree `filesystem` window and `<A-G>` is pressed in normal mode
- **THEN** the current window is a neo-tree window whose buffer name contains `neo-tree git_status`

#### Scenario: Alt-G closes focused git status tree
- **WHEN** the current window is the neo-tree `git_status` window and `<A-G>` is pressed in normal mode
- **THEN** no window with `filetype` `neo-tree` remains

### Requirement: Differ entry point
The config SHALL map `<A-g>` in normal mode to `:Differ`.

#### Scenario: Alt-g opens Differ
- **WHEN** `<A-g>` is pressed in normal mode
- **THEN** the Ex command `:Differ` is executed

### Requirement: Live grep
The config SHALL map `<A-F>` in normal mode to `:Telescope live_grep`.

#### Scenario: Alt-F opens live grep
- **WHEN** `<A-F>` is pressed in normal mode
- **THEN** a Telescope prompt buffer (`filetype` `TelescopePrompt`) is focused with the live grep picker

### Requirement: LSP actions and navigation
The config SHALL map `<C-CR>` in normal mode and visual mode (`x` only) to `vim.lsp.buf.code_action`; map `gD`, `gd`, `K`, `gi`, and `<A-r>` in normal mode to the corresponding `vim.lsp.buf` actions; and map normal-mode `gr` to a callback that invokes Telescope `lsp_references` with `include_current_line = true`.

#### Scenario: LSP mappings bound to vim.lsp.buf
- **WHEN** the full config is loaded and `vim.fn.maparg(lhs, "n", false, true).callback` is read for `gD`, `gd`, `K`, `gi`, `<A-r>`, `<C-CR>`
- **THEN** the callbacks equal `vim.lsp.buf.declaration`, `vim.lsp.buf.definition`, `vim.lsp.buf.hover`, `vim.lsp.buf.implementation`, `vim.lsp.buf.rename`, `vim.lsp.buf.code_action` respectively

#### Scenario: Code action in visual mode
- **WHEN** the full config is loaded and `vim.fn.maparg("<C-CR>", "x", false, true).callback` is read
- **THEN** it equals `vim.lsp.buf.code_action`

#### Scenario: gr bound to Telescope references
- **WHEN** the full config is loaded and the callback from `vim.fn.maparg("gr", "n", false, true)` is invoked
- **THEN** it calls `require("telescope.builtin").lsp_references` with `include_current_line = true`

### Requirement: Diagnostic navigation
The config SHALL map `<A-w>` and `ge` in normal mode to jump to the next diagnostic and `[d` to jump to the previous diagnostic, using `vim.diagnostic.jump` with `count` `1` / `-1` and an `on_jump` callback that opens the diagnostic float, so that each jump opens the float and calls no deprecated API.

#### Scenario: ge jumps to next diagnostic
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 1, and `ge` is pressed in normal mode
- **THEN** the cursor is on line 2

#### Scenario: Alt-w jumps to next diagnostic
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 2, and `<A-w>` is pressed in normal mode
- **THEN** the cursor is on line 4

#### Scenario: [d jumps to previous diagnostic
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 4, and `[d` is pressed in normal mode
- **THEN** the cursor is on line 2

#### Scenario: Diagnostic jump opens float
- **WHEN** the buffer has diagnostics on lines 2 and 4, the cursor is on line 1, and `ge` is pressed in normal mode
- **THEN** a floating window (`relative ~= ""` in `nvim_win_get_config`) exists whose buffer contains the line-2 diagnostic message

#### Scenario: Diagnostic jump is not deprecated
- **WHEN** `vim.deprecate` is replaced by a function that records its first argument, the buffer has diagnostics on lines 2 and 4, the cursor is on line 1, and `ge`, `<A-w>` and `[d` are pressed in normal mode
- **THEN** no call was recorded and the output of `:messages` does not contain `deprecated`

### Requirement: Normal-mode command maps bypass the command line
The config SHALL run the Ex commands behind the normal-mode maps `<C-Up>`, `<C-Down>`, `<C-Left>`, `<C-Right>`, `<C-q>`, `<A-g>` and `<A-F>` without entering the command line, so no `CmdlineEnter` event fires and the command line is not redrawn with the command.

#### Scenario: Command maps do not enter the command line
- **WHEN** two windows exist stacked (`:split`), a `CmdlineEnter` autocmd counts its events, and `<C-Up>`, `<C-Down>`, `<C-Left>` and `<C-Right>` are pressed in normal mode
- **THEN** the `CmdlineEnter` count is 0
