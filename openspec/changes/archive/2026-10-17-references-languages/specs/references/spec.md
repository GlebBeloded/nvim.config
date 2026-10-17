## ADDED Requirements

### Requirement: Find Usages in every configured language
`gr` SHALL open the Find Usages view with every usage the attached server reports, grouped by test scope and folder, for Lua (lua_ls), Python (basedpyright), TypeScript (vtsls), Rust (rust-analyzer), Bash (bashls) and Terraform (terraform-ls), as for Go. When a buffer has several attached clients, only those advertising `referencesProvider` SHALL be asked and each usage SHALL be listed once.

#### Scenario: Lua usages in production and spec files
- **WHEN** Neovim runs in a fresh copy of the `luaproj` fixture with `lua/shop/price.lua` open, the cursor on the `M.total` definition, lua_ls attached, and `gr` is pressed
- **THEN** the view lists `Production` → `lua/shop` → `cart.lua:<line>` and `Test` → `spec` → `price_spec.lua:<line>`, at the fixture manifest's lines

#### Scenario: Python usages in production and test files
- **WHEN** Neovim runs in a fresh copy of the `pyproj` fixture with `shop/price.py` open, the cursor on the `total` definition, basedpyright and ruff attached, and `gr` is pressed
- **THEN** the view lists `Production` → `shop` → `cart.py:<line>` and `Test` → `tests` → `test_price.py:<line>`, at the manifest's lines, each once

#### Scenario: TypeScript usages in production and test files
- **WHEN** Neovim runs in a fresh copy of the `tsproj` fixture with `src/price.ts` open, the cursor on the exported `total` function, vtsls and eslint attached, and `gr` is pressed
- **THEN** the view lists `Production` → `src` → `cart.ts:<line>` and `Test` → `src` → `price.test.ts:<line>`, at the manifest's lines, each once

#### Scenario: Rust usages in production and test code
- **WHEN** Neovim runs in a fresh copy of the `rustproj` fixture with `src/price.rs` open, the cursor on the `pub fn total` definition, rust-analyzer attached, and `gr` is pressed
- **THEN** the view lists the `src/main.rs` usage under `Production` and the `tests/price.rs` usage under `Test`; the usage inside `#[cfg(test)] mod tests` of `src/price.rs` is under `Test` when the `rust` parser is installed and under `Production` otherwise

#### Scenario: Bash usages in production and test scripts
- **WHEN** Neovim runs in a fresh copy of the `bashproj` fixture with `lib/price.sh` open, the cursor on the `total` function, bashls attached, and `gr` is pressed
- **THEN** the view lists `Production` → `bin` → `run.sh:<line>` and `Test` → `test` → `price_test.sh:<line>`, at the manifest's lines

#### Scenario: Terraform variable usages
- **WHEN** Neovim runs in a fresh copy of the `tfproj` fixture with `variables.tf` open, the cursor on `variable "region"`, terraform-ls attached, and `gr` is pressed
- **THEN** the view lists `Production` with the `main.tf` and `outputs.tf` usages at the manifest's lines and no `Test` group

#### Scenario: Two attached clients list each usage once
- **WHEN** usages are requested for a buffer with two attached clients that both advertise `referencesProvider` and both return the same locations
- **THEN** each location appears as exactly one usage row
