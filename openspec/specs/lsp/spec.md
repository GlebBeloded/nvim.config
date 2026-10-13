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


### Requirement: Language server readiness
Every language server the config enables SHALL answer the first `textDocument/documentSymbol` request for a buffer within 1000 ms of the `:edit` that opened it, measured in a full-config Neovim whose server binaries and toolchain caches are already warm from an earlier start.

#### Scenario: lua_ls ready within 1 s in this config
- **WHEN** a full-config Neovim with cwd at this checkout runs `:edit lua/gleb/lsp/config/init.lua`
- **THEN** the `lua_ls` client attached to the buffer answers `textDocument/documentSymbol` without error within 1000 ms of the `:edit`

#### Scenario: gopls ready within 1 s in a small module
- **WHEN** a full-config Neovim with cwd at a fixture Go module (`go.mod`, `main.go` importing one local package) runs `:edit main.go`
- **THEN** the `gopls` client attached to the buffer answers `textDocument/documentSymbol` without error within 1000 ms of the `:edit`

#### Scenario: basedpyright ready within 1 s in a small project
- **WHEN** a full-config Neovim with cwd at a fixture Python project (`pyproject.toml`, one module) runs `:edit` on that module
- **THEN** the `basedpyright` client attached to the buffer answers `textDocument/documentSymbol` without error within 1000 ms of the `:edit`

#### Scenario: vtsls ready within 1 s in a small project
- **WHEN** a full-config Neovim with cwd at a fixture TypeScript project (`package.json`, `tsconfig.json`, one `.ts` file) runs `:edit` on that file
- **THEN** the `vtsls` client attached to the buffer answers `textDocument/documentSymbol` without error within 1000 ms of the `:edit`
