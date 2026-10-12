# keymaps Specification

## Purpose
Global editor keymaps defined in `lua/gleb/keymaps.lua`: window navigation and resizing, jump list, buffer close, editing helpers in insert/visual modes, file-tree/git/search entry points, LSP and diagnostics navigation, and leader keys. All mappings in this file are non-recursive and silent.

## Requirements
### Requirement: Mapping options
The config SHALL define every keymap in `lua/gleb/keymaps.lua` as non-recursive (`noremap`) and silent.

#### Scenario: Core mappings are noremap and silent
- **WHEN** the full config is loaded and `vim.fn.maparg("gb", "n", false, true)` is called
- **THEN** the returned dict has `noremap == 1` and `silent == 1`

### Requirement: Leader keys
The config SHALL set `g:mapleader` to the literal string `<D->` and `g:maplocalleader` to `\`, at the end of `lua/gleb/keymaps.lua`.

#### Scenario: Leader values after startup
- **WHEN** the full config is loaded and `vim.g.mapleader` and `vim.g.maplocalleader` are read
- **THEN** `vim.g.mapleader == "<D->"` and `vim.g.maplocalleader == "\\"`

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
The config SHALL map, in normal mode, `<C-Up>`/`<C-Down>` to `:resize +2`/`:resize -2`, `<C-Left>`/`<C-Right>` to `:vertical resize -2`/`:vertical resize +2`, and `<A-H>`, `<A-J>`, `<A-K>`, `<A-L>` to smart-splits resize left, down, up and right.

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

### Requirement: Jump list navigation
The config SHALL map `gb` in normal mode to jump to the older jump-list position (`<C-O>`) and `gB` to the newer position (`<C-I>`).

#### Scenario: gb jumps back
- **WHEN** a buffer has 100 lines, the cursor is on line 1, `G` is pressed, then `gb` is pressed in normal mode
- **THEN** the cursor is on line 1

#### Scenario: gB jumps forward
- **WHEN** after the "gb jumps back" sequence, `gB` is pressed in normal mode
- **THEN** the cursor is on line 100

### Requirement: Buffer close
The config SHALL map `<C-q>` in normal mode to `:bdelete`.

#### Scenario: Close current buffer
- **WHEN** two listed buffers exist, the current one is unmodified, and `<C-q>` is pressed in normal mode
- **THEN** the previously current buffer is no longer listed

### Requirement: Insert mode escape
The config SHALL map `jk` in insert mode to `<Esc>`.

#### Scenario: jk leaves insert mode
- **WHEN** in insert mode in an empty buffer and `jk` is typed
- **THEN** the mode is normal and the buffer line is empty

### Requirement: Visual mode editing helpers
The config SHALL keep the selection after `<` and `>` in visual mode, SHALL make `p` in visual mode replace the selection without overwriting the unnamed register, and SHALL map `J`/`<A-j>` and `K`/`<A-k>` in visual mode (`x`) to move the selected lines down/up by one line while keeping visual mode. In select mode, `<A-j>`/`<A-k>` SHALL move the line(s) and reindent (`:m .+1<CR>==` / `:m .-2<CR>==`).

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
The config SHALL map `<C-CR>` in normal and visual modes to `vim.lsp.buf.code_action`, and in normal mode `gD` to `vim.lsp.buf.declaration`, `gd` to `vim.lsp.buf.definition`, `K` to `vim.lsp.buf.hover`, `gi` to `vim.lsp.buf.implementation`, `gr` to Telescope `lsp_references`, and `<A-r>` to `vim.lsp.buf.rename`.

#### Scenario: LSP mappings bound to vim.lsp.buf
- **WHEN** the full config is loaded and `vim.fn.maparg(lhs, "n", false, true).callback` is read for `gD`, `gd`, `K`, `gi`, `<A-r>`, `<C-CR>`
- **THEN** the callbacks equal `vim.lsp.buf.declaration`, `vim.lsp.buf.definition`, `vim.lsp.buf.hover`, `vim.lsp.buf.implementation`, `vim.lsp.buf.rename`, `vim.lsp.buf.code_action` respectively

#### Scenario: Code action in visual mode
- **WHEN** the full config is loaded and `vim.fn.maparg("<C-CR>", "x", false, true).callback` is read
- **THEN** it equals `vim.lsp.buf.code_action`

#### Scenario: gr bound to Telescope references
- **WHEN** the full config is loaded and `vim.fn.maparg("gr", "n", false, true).callback` is read
- **THEN** it equals `require("telescope.builtin").lsp_references`

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
