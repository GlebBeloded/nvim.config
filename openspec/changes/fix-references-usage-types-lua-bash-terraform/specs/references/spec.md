## ADDED Requirements

### Requirement: Lua usage types
The Lua `usages` query SHALL classify calls as `call`, names and `function` values of `function`, `local function`, `f = function`, `M.f = function` and `{ f = function }` as `function_declaration`, parameters as `parameter_declaration`, `{ name = … }` keys as `field_initialization`, assignment, `local` and loop targets as `write`, and other identifiers as `read`. Current-file write highlights that `gr` appends SHALL be classified like listed usages.

#### Scenario: Lua query classifies every usage type
- **WHEN** the Lua case table `tests/unit/references/usage_cases/lua.lua` (ported from `drafts/verify.lua`, ids renamed per design.md Decision 1) runs with the installed `lua` parser
- **THEN** every position gets its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: gr classifies Lua function calls and redefinitions
- **WHEN** Neovim runs in a fresh copy of the extended `luaproj` fixture with `lua/shop/discount.lua` open, the cursor on `apply` in `function M.apply` (line 4), lua_ls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `lua/shop/checkout.lua:3` as `call`, `lua/shop/discount.lua:9` (the `M.apply = function` redefinition, a current-file write highlight) as `function_declaration`, and `spec/discount_spec.lua:3` as `call`

#### Scenario: Lua usage types match the approved render
- **WHEN** `gr` is pressed on `apply` in `lua/shop/discount.lua` of the extended `luaproj` fixture with the editor at 70x24, default grouping and lua_ls attached, and classification has finished
- **THEN** the screen matches the approved render "Proposed L1 — Lua function usages"

### Requirement: Bash usage types
The Bash `usages` query SHALL classify command names as `call`, function definition names as `function_declaration`, a bare `export x` as `export`, targets of assignments, `declare`/`local`/`typeset`, `for`, `read` and `(( x++ ))` as `write`, and other variable names as `read`.

#### Scenario: Bash query classifies every usage type
- **WHEN** the Bash case table `tests/unit/references/usage_cases/shell.lua` (ported from `drafts/verify.lua`) runs with the installed `bash` parser
- **THEN** every position gets its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: gr classifies Bash exports, writes and reads
- **WHEN** Neovim runs in a fresh copy of the extended `bashproj` fixture with `lib/tax.sh` open, the cursor on `rate` in `rate=20` (line 2), bashls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `lib/tax.sh:3` as `export`, `lib/tax.sh:6` as `read` and `bin/invoice.sh:4` as `write`

#### Scenario: gr classifies Bash function usages as calls
- **WHEN** Neovim runs in a fresh copy of the `bashproj` fixture with `lib/price.sh` open, the cursor on the `total` function, bashls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `bin/run.sh:4` and `test/price_test.sh:4` as `call`

#### Scenario: Bash usage types match the approved render
- **WHEN** `gr` is pressed on `rate` in `lib/tax.sh` of the extended `bashproj` fixture with the editor at 70x24, default grouping and bashls attached, and classification has finished
- **THEN** the screen matches the approved render "Proposed B1 — Bash variable usages"

### Requirement: Terraform usage types
The `hcl` `usages` query, inherited by `terraform`, SHALL classify `depends_on` traversals as `depends_on`, module, resource, data and local traversals in an `output` value (up to one level deep) as `output`, `module` block arguments as `attribute_assignment`, `module.`, `data.`, `local.` and resource traversals as their `*_reference` type, `locals` keys as `variable_declaration`, `variable` labels as `write` and `var.` traversals, in outputs too, as `read`.

#### Scenario: Terraform query classifies every usage type
- **WHEN** the Terraform case table `tests/unit/references/usage_cases/terraform.lua` (ported from `drafts/verify.lua`, ids renamed per design.md Decision 1) runs once with the installed `hcl` parser and once with `terraform`
- **THEN** both runs give every position its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: gr classifies Terraform module variable usages
- **WHEN** Neovim runs in a fresh copy of the extended `tfproj` fixture, opens `network.tf` and then `net/main.tf`, places the cursor on `variable "cidr"` (line 1), terraform-ls is attached, and `gr` is pressed in normal mode
- **THEN** the view lists `network.tf:7` as `attribute_assignment`, and `net/main.tf:6` and `net/main.tf:10` (an input variable in an output value) as `read`

#### Scenario: gr classifies Terraform module usages
- **WHEN** Neovim runs in a fresh copy of the extended `tfproj` fixture with `network.tf` open, the cursor on `module "vpc"` (line 5), terraform-ls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `network.tf:11` as `module_reference`, `network.tf:12` as `depends_on` and `network.tf:16` as `output`

#### Scenario: Terraform usage types match the approved render
- **WHEN** `gr` is pressed on `module "vpc"` in `network.tf` of the extended `tfproj` fixture with the editor at 70x24, default grouping and terraform-ls attached, and classification has finished
- **THEN** the screen matches the approved render "Proposed H1 — Terraform module usages"
