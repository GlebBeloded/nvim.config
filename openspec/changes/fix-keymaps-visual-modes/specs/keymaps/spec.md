## MODIFIED Requirements

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
- **WHEN** the unnamed register contains `foo`, the buffer line is `bar baz`, the cursor is on column 1, and `gh` then `p` is typed
- **THEN** the buffer line is `par baz` and `getreg('"')` is still `foo`

### Requirement: LSP actions and navigation
The config SHALL map `<C-CR>` in normal mode and in visual mode (`x` only) to `vim.lsp.buf.code_action`, and in normal mode `gD` to `vim.lsp.buf.declaration`, `gd` to `vim.lsp.buf.definition`, `K` to `vim.lsp.buf.hover`, `gi` to `vim.lsp.buf.implementation`, `gr` to Telescope `lsp_references`, and `<A-r>` to `vim.lsp.buf.rename`.

#### Scenario: LSP mappings bound to vim.lsp.buf
- **WHEN** the full config is loaded and `vim.fn.maparg(lhs, "n", false, true).callback` is read for `gD`, `gd`, `K`, `gi`, `<A-r>`, `<C-CR>`
- **THEN** the callbacks equal `vim.lsp.buf.declaration`, `vim.lsp.buf.definition`, `vim.lsp.buf.hover`, `vim.lsp.buf.implementation`, `vim.lsp.buf.rename`, `vim.lsp.buf.code_action` respectively

#### Scenario: Code action in visual mode
- **WHEN** the full config is loaded and `vim.fn.maparg("<C-CR>", "x", false, true).callback` is read
- **THEN** it equals `vim.lsp.buf.code_action`

#### Scenario: gr bound to Telescope references
- **WHEN** the full config is loaded and `vim.fn.maparg("gr", "n", false, true).callback` is read
- **THEN** it equals `require("telescope.builtin").lsp_references`
