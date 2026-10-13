## ADDED Requirements

### Requirement: Language server readiness
The config SHALL make lua_ls answer its first `textDocument/documentSymbol` request within 2500 ms in this checkout, and gopls, basedpyright, and vtsls answer within 1000 ms in their small fixture projects. Time is measured from `:edit` in a full-config Neovim after an earlier server start has warmed server and toolchain caches; the fixed bounds SHALL NOT scale with host load.

#### Scenario: lua_ls ready within 2.5 s in this config
- **WHEN** a full-config Neovim with cwd at this checkout runs `:edit lua/gleb/lsp/config/init.lua`
- **THEN** the `lua_ls` client attached to the buffer answers `textDocument/documentSymbol` without error within 2500 ms of the `:edit`

#### Scenario: gopls ready within 1 s in a small module
- **WHEN** a full-config Neovim with cwd at a fixture Go module (`go.mod`, `main.go` importing one local package) runs `:edit main.go`
- **THEN** the `gopls` client attached to the buffer answers `textDocument/documentSymbol` without error within 1000 ms of the `:edit`

#### Scenario: basedpyright ready within 1 s in a small project
- **WHEN** a full-config Neovim with cwd at a fixture Python project (`pyproject.toml`, one module) runs `:edit` on that module
- **THEN** the `basedpyright` client attached to the buffer answers `textDocument/documentSymbol` without error within 1000 ms of the `:edit`

#### Scenario: vtsls ready within 1 s in a small project
- **WHEN** a full-config Neovim with cwd at a fixture TypeScript project (`package.json`, `tsconfig.json`, one `.ts` file) runs `:edit` on that file
- **THEN** the `vtsls` client attached to the buffer answers `textDocument/documentSymbol` without error within 1000 ms of the `:edit`
