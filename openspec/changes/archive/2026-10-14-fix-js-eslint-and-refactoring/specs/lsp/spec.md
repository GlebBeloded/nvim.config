## ADDED Requirements

### Requirement: JavaScript and refactoring tooling
The config SHALL enable both TypeScript/JavaScript and ESLint language services for JavaScript buffers. It SHALL NOT register the none-ls refactoring code-action source when its runtime dependency is absent.

#### Scenario: JavaScript config enables vtsls and eslint
- **WHEN** a full-config Neovim loads the LSP configuration
- **THEN** the enabled language-server configurations for JavaScript include both `vtsls` and `eslint`

#### Scenario: Ranged Lua code action does not log generator failure
- **WHEN** a full-config Neovim requests code actions for a non-empty range in a Lua buffer
- **THEN** the none-ls log does not contain a `failed to run generator` warning from the refactoring source
