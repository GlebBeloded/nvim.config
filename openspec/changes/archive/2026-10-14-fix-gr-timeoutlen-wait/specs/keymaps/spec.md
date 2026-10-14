## MODIFIED Requirements

### Requirement: LSP actions and navigation
The config SHALL map `<C-CR>` in normal and visual (`x`) modes to code action; map `gD`, `gd`, `K`, `gi`, and `<A-r>` in normal mode to their corresponding `vim.lsp.buf` actions; map normal-mode `gr` to Telescope `lsp_references` with `include_current_line = true`; and leave no other normal-mode mapping whose lhs starts with `gr`.

#### Scenario: LSP mappings bound to vim.lsp.buf
- **WHEN** the full config is loaded and the normal-mode callbacks for `gD`, `gd`, `K`, `gi`, `<A-r>`, and `<C-CR>` are read
- **THEN** they equal `vim.lsp.buf.declaration`, `vim.lsp.buf.definition`, `vim.lsp.buf.hover`, `vim.lsp.buf.implementation`, `vim.lsp.buf.rename`, and `vim.lsp.buf.code_action` respectively

#### Scenario: Code action in visual mode
- **WHEN** the full config is loaded and the callback for visual-mode `<C-CR>` is read
- **THEN** it equals `vim.lsp.buf.code_action`

#### Scenario: gr bound to Telescope references
- **WHEN** the full config is loaded, the callback for normal-mode `gr` is invoked, and normal-mode mappings whose lhs starts with `gr` are listed
- **THEN** the callback calls Telescope `lsp_references` with `include_current_line = true`, and `gr` is the only listed mapping
