# lsp Specification

## Purpose
Shared LSP client setup in `lua/gleb/lsp/`: diagnostic display (signs, virtual text, floats) and handlers reused by every language server configuration.

## Requirements

### Requirement: Diagnostic sign glyphs
The config SHALL configure `vim.diagnostic` signs with the Nerd Font glyphs U+F057 (error), U+F071 (warn), U+F0335 (hint) and U+F05A (info), so every severity draws a visible glyph in the sign column.

#### Scenario: diagnostic signs use Nerd Font glyphs
- **WHEN** the config has loaded and `vim.diagnostic.config().signs.text` is read
- **THEN** it maps `ERROR` to U+F057, `WARN` to U+F071, `HINT` to U+F0335 and `INFO` to U+F05A

#### Scenario: error sign drawn in sign column
- **WHEN** a file buffer is shown and `vim.diagnostic.set` adds one error on line 1
- **THEN** the screen row of line 1 shows U+F057 in the sign column
