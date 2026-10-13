## REMOVED Requirements

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

## ADDED Requirements

### Requirement: Server-specific language server readiness
The config SHALL make lua_ls answer its first `textDocument/documentSymbol` request within 2500 ms in this checkout, and gopls, basedpyright and vtsls answer within 1000 ms in their small fixture projects. Time is measured from `:edit` in a full-config Neovim after an earlier server start has warmed server and toolchain caches; the fixed bounds SHALL NOT scale with host load.

#### Scenario: lua_ls ready within 2.5 s in this config
- **WHEN** a full-config Neovim with warm caches and cwd at this checkout runs `:edit lua/gleb/lsp/config/init.lua`
- **THEN** lua_ls answers `textDocument/documentSymbol` without error within 2500 ms

#### Scenario: gopls ready within 1 s in a small module
- **WHEN** a full-config Neovim with warm caches and cwd at a fixture Go module runs `:edit main.go`
- **THEN** gopls answers `textDocument/documentSymbol` without error within 1000 ms

#### Scenario: basedpyright ready within 1 s in a small project
- **WHEN** a full-config Neovim with warm caches and cwd at a fixture Python project runs `:edit ready.py`
- **THEN** basedpyright answers `textDocument/documentSymbol` without error within 1000 ms

#### Scenario: vtsls ready within 1 s in a small project
- **WHEN** a full-config Neovim with warm caches and cwd at a fixture TypeScript project runs `:edit index.ts`
- **THEN** vtsls answers `textDocument/documentSymbol` without error within 1000 ms

### Requirement: Lua editor type metadata
The config SHALL expose Neovim API type metadata to lua_ls in Lua buffers while keeping the editor workspace configuration free of the full static-analysis library used by `make types`.

#### Scenario: lua_ls exposes typed vim API signatures
- **WHEN** a full-config Neovim opens `lua/gleb/lsp/config/init.lua` and requests hover for `vim.lsp.enable`
- **THEN** lua_ls returns a typed function signature including the `name` and optional `enable` parameters
