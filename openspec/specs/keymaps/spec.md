# keymaps Specification

## Purpose
Global editor keymaps defined in `lua/gleb/keymaps.lua`: window navigation and resizing, jump list, buffer close, editing helpers in insert/visual modes, file-tree/git/search entry points, LSP and diagnostics navigation, and leader keys. All mappings in this file are non-recursive and silent.

## Requirements

### Requirement: Mapping options
Every core action mapping SHALL be silent, have a `<Category>: <Title>` description, and be non-recursive unless its rhs is a registered `<Plug>` target.

#### Scenario: Core mappings are noremap and silent
- **WHEN** the full config has fired `VeryLazy` and the mapping for `gb` is queried
- **THEN** it has `noremap == 1` and `silent == 1`

#### Scenario: Every core mapping has an area-action desc
- **WHEN** each configured core action mapping is queried after `VeryLazy`
- **THEN** every description matches the Lua pattern `^%u[%w ]*: %S.*$`

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

### Requirement: File tree and git panel toggles
The config SHALL map `<A-e>` in normal mode to a smart neo-tree toggle for the `filesystem` source and `<A-G>` to the same toggle for the `git_status` source. When the current window is neo-tree, the toggle SHALL close it if it shows the requested source and otherwise switch it to that source. When the current window is not neo-tree, the toggle SHALL focus neo-tree on the requested source, revealing the current file for `filesystem` only when the buffer names an existing file on disk.

#### Scenario: Alt-e reveals current file
- **WHEN** a file `foo.lua` is being edited and `<A-e>` is pressed in normal mode
- **THEN** the current window has `filetype` `neo-tree`, its buffer name contains `neo-tree filesystem`, and the cursor line refers to `foo.lua`

#### Scenario: Alt-e on URI buffer focuses filesystem
- **WHEN** the current buffer is named `vscodediff://x` and `<A-e>` is pressed in normal mode
- **THEN** the current window is a neo-tree `filesystem` window and no error is reported

#### Scenario: Alt-e tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised and the focused tree uses the `filesystem` source without trying to reveal the deleted path

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
The config SHALL map `<A-F>` in normal mode to the shared picker's live-grep source.

#### Scenario: Alt-F opens live grep
- **WHEN** `<A-F>` is pressed in normal mode
- **THEN** a shared picker is focused with the live-grep source and title `Live Grep`

#### Scenario: Live grep renders matching rows
- **WHEN** `<A-F>` is pressed in normal mode and a query matching a repository file is typed
- **THEN** the shared picker remains open and renders the matching file, line and text without an error

### Requirement: LSP actions and navigation
The config SHALL map `<C-CR>` in normal and visual (`x`) modes to code action; map `gD`, `gd`, `K`, `gi`, and `<A-r>` in normal mode to their corresponding `vim.lsp.buf` actions; map normal-mode `gr` to the Find Usages view; and leave no other normal-mode mapping whose lhs starts with `gr`.

#### Scenario: LSP mappings bound to vim.lsp.buf
- **WHEN** the full config is loaded and the normal-mode callbacks for `gD`, `gd`, `K`, `gi`, `<A-r>`, and `<C-CR>` are read
- **THEN** they equal `vim.lsp.buf.declaration`, `vim.lsp.buf.definition`, `vim.lsp.buf.hover`, `vim.lsp.buf.implementation`, `vim.lsp.buf.rename`, and `vim.lsp.buf.code_action` respectively

#### Scenario: Code action in visual mode
- **WHEN** the full config is loaded and the callback for visual-mode `<C-CR>` is read
- **THEN** it equals `vim.lsp.buf.code_action`

#### Scenario: gr bound to Telescope references
- **WHEN** the full config is loaded, normal-mode `gr` is invoked and mappings whose lhs starts with `gr` are listed
- **THEN** the Find Usages view request starts for the symbol under the cursor, and `gr` is the only listed mapping

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

### Requirement: Pending file tree work does not override a toggle
The smart neo-tree toggle SHALL preserve the requested close or source switch when work from an earlier filesystem open or refresh completes afterward.

#### Scenario: Toggle wins over pending filesystem render
- **WHEN** the focused neo-tree `filesystem` window still has a pending render and `<A-e>` or `<A-G>` is pressed in normal mode
- **THEN** after the pending render completes, `<A-e>` leaves no neo-tree window and `<A-G>` leaves the focused neo-tree source as `git_status`

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
