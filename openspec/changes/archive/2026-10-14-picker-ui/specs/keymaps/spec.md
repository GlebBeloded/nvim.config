## MODIFIED Requirements

### Requirement: Live grep
The config SHALL map `<A-F>` in normal mode to the shared picker's live-grep source.

#### Scenario: Alt-F opens live grep
- **WHEN** `<A-F>` is pressed in normal mode
- **THEN** a shared picker is focused with the live-grep source and title `Live Grep`

#### Scenario: Live grep renders matching rows
- **WHEN** `<A-F>` is pressed in normal mode and a query matching a repository file is typed
- **THEN** the shared picker remains open and renders the matching file, line and text without an error

### Requirement: LSP actions and navigation
The config SHALL map `<C-CR>` in normal and visual (`x`) modes to code action; map `gD`, `gd`, `K`, `gi`, and `<A-r>` in normal mode to their corresponding `vim.lsp.buf` actions; map normal-mode `gr` to the shared LSP-references source including the current line; and leave no other normal-mode mapping whose lhs starts with `gr`.

#### Scenario: LSP mappings bound to vim.lsp.buf
- **WHEN** the full config is loaded and the normal-mode callbacks for `gD`, `gd`, `K`, `gi`, `<A-r>`, and `<C-CR>` are read
- **THEN** they equal `vim.lsp.buf.declaration`, `vim.lsp.buf.definition`, `vim.lsp.buf.hover`, `vim.lsp.buf.implementation`, `vim.lsp.buf.rename`, and `vim.lsp.buf.code_action` respectively

#### Scenario: Code action in visual mode
- **WHEN** the full config is loaded and the callback for visual-mode `<C-CR>` is read
- **THEN** it equals `vim.lsp.buf.code_action`

#### Scenario: gr bound to Telescope references
- **WHEN** the full config is loaded, normal-mode `gr` is invoked and mappings whose lhs starts with `gr` are listed
- **THEN** a shared picker opens with the LSP-references source including the current line, and `gr` is the only listed mapping
