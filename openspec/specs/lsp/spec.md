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

### Requirement: Go references workflow
In a Go module, `gr` in Normal mode SHALL open the Telescope references picker for the symbol under the cursor, listing the declaration and every reference reported by gopls across all packages of the module, including reported locations on the cursor's current line, and selecting an entry SHALL open its file with the cursor on the reference.

#### Scenario: References of a Go function list call sites across packages
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration and gopls attached, and `g` `r` is pressed as a real key press
- **THEN** the Telescope references picker is open and its entries are exactly the fixture manifest's locations of `Format`: the declaration under the cursor plus the call sites in `internal/money/money_test.go`, `billing/invoice.go` (two) and `report/summary.go`

#### Scenario: Selecting a reference opens its file at the call site
- **WHEN** in that picker `summary` is typed into the prompt and Return is pressed as real key presses
- **THEN** the picker is closed, the current buffer is `report/summary.go` of the fixture copy, and the cursor is at the manifest's line and column of the `Format` call in that file

### Requirement: Terraform language server registration
The config SHALL register and enable the nvim-lspconfig server named `terraformls` for Terraform buffers, using the installed `terraform-ls` executable definition.

#### Scenario: Terraform files use terraformls
- **WHEN** a full-config Neovim opens a `.tf` file whose detected filetype is `terraform`
- **THEN** the buffer's enabled language-server config is named `terraformls`

### Requirement: JavaScript and refactoring tooling
The config SHALL enable both TypeScript/JavaScript and ESLint language services for JavaScript buffers. It SHALL NOT register the none-ls refactoring code-action source when its runtime dependency is absent.

#### Scenario: JavaScript config enables vtsls and eslint
- **WHEN** a full-config Neovim loads the LSP configuration
- **THEN** the enabled language-server configurations for JavaScript include both `vtsls` and `eslint`

#### Scenario: Ranged Lua code action does not log generator failure
- **WHEN** a full-config Neovim requests code actions for a non-empty range in a Lua buffer
- **THEN** the none-ls log does not contain a `failed to run generator` warning from the refactoring source

### Requirement: Python type-check mode toggle
The Python type-check commands SHALL change the configured type-check mode without reloading buffers and SHALL restore Python language-server service to every loaded Python buffer.

#### Scenario: Type-check toggle reattaches every Python buffer without reloading
- **WHEN** `:PyTypeCheckOn` or `:PyTypeCheckOff` is executed with two loaded Python buffers and the current buffer has unsaved changes
- **THEN** the command raises no error and basedpyright attaches to both Python buffers with the selected type-check mode

### Requirement: Unavailable Terraform formatter is omitted
When the `terraform` executable is unavailable, the config SHALL omit the `terraform_fmt` source from null-ls so its health check does not report a missing command.

#### Scenario: Terraform formatter is omitted when Terraform is unavailable
- **WHEN** a full-config Neovim starts with a `PATH` where `terraform` is not executable
- **THEN** the registered null-ls sources do not include `terraform_fmt`
