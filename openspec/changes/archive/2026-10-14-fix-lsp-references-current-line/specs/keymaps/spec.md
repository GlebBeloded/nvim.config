# Spec Delta

## MODIFIED Requirements

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
