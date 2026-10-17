## Why

Kind: bug
Depends: fix-references-usage-types-rust

Find Usages has GoLand's usage types for Go, and the queued changes add them for TypeScript, Python and Rust. Lua, Bash and Terraform keep only the write/read queries that `fix-references-usage-types` moved out of `kind_ts.lua`. So a Lua function's calls are `Unclassified`, a Bash `export x` is a plain read, and a Terraform module referenced from a resource, a `depends_on` list or an output is just `Value read`. The user wants GoLand-like observability for every configured language.

## Evidence

Checked with lua-language-server 3.17.1, bash-language-server 5.6.0, terraform-ls 0.38.5 and Neovim 0.12.5, on the extended fixtures (design.md, Decision 7):
- **Lua.** `gr` on `M.apply` (`lua/shop/discount.lua:4`) gets the calls in `lua/shop/checkout.lua:3` and `spec/discount_spec.lua:3` from lua_ls, plus the redefinition `M.apply = function` on line 9 as a current-file write highlight. `M.apply` is a `function` target, which never gets write/read, and the Lua query has no other captures. So all three are `Unclassified` and the view has no usage type level (render "Current — Lua function usages").
- **Bash.** `gr` on `rate` (`lib/tax.sh:2`) gets `export rate` (line 3), `$((… rate …))` (line 6) and `rate=25` (`bin/invoice.sh:4`). bashls documentHighlight carries no kinds, so the query decides: the export is `read`, like a plain expansion (render "Current — Bash variable usages").
- **Terraform.** `gr` on `module "vpc"` (`network.tf:5`) gets `module.vpc.id` in a resource (`network.tf:11`), `module.vpc` in `depends_on` (`:12`) and `module.vpc.id` as an output's value (`:16`). All three are `read` (render "Current — Terraform module usages"). `gr` on the child-module `variable "cidr"` (`net/main.tf:1`) gets the parent's module argument `cidr = …` (`network.tf:7`), and it is `read` too.
  - terraform-ls reports every block as `SymbolKind.Class`. `fix-references-usage-types` maps that to an `unknown` target for Terraform (its Decision 3), and `languages-registry` keeps it as the facet's `target_kinds`.
- **JetBrains** has less here than for Go:
  - EmmyLua's `UsageTypeProvider` has only "Function call", next to read/write.
  - The JetBrains Shell plugin has no usage types, so every usage is "Unclassified".
  - The HCL plugin has only Value read/write, plus "Usage in string constants" for HIL strings.
- **Drafts.** Verified queries, fixtures and a verifier are in `drafts/`. With the ids renamed to catalogue ids (design.md, Decision 1), 239 cases pass on the installed parsers:
  - 67 Lua;
  - 44 Bash;
  - 64 Terraform, each run with both the `hcl` and the `terraform` parser.
- `languages-registry` leaves `references.usage_types` of the `lua`, `shell` and `terraform` languages as `{ disabled = "queued: fix-references-usage-types-lua-bash-terraform" }`.
- The disabled gates are at `lua/gleb/languages/lua/init.lua:18`, `lua/gleb/languages/shell/init.lua:20` and `lua/gleb/languages/terraform/init.lua:19`; the installed queries expose only generic captures at `queries/lua/usages.scm:1`, `queries/bash/usages.scm:1` and `queries/hcl/usages.scm:3`/`:7`.

## What Changes

- **Queries.** The write/read-only `queries/lua/usages.scm`, `queries/bash/usages.scm` and `queries/hcl/usages.scm` from `fix-references-usage-types` get the richer draft queries, with the ids renamed to catalogue ids. `queries/terraform/usages.scm` stays `; inherits: hcl`.
  - **Lua:** Call, Function declaration (`function f`, `local function f`, `f = function`, `M.f = function`, and table fields holding a function), Parameter declaration and Field initialization (`{ total = 1 }`). Write now also covers `M.x = 1` and for-loop variables.
  - **Bash:** Call (the command name), Function declaration and Export (`export x` without a value). Write now also covers `arr[0]=v`, `declare`/`local`/`typeset x`, `for x in`, `read x` and `(( x++ ))`.
  - **Terraform:** Dependency (`depends_on`), Output value (a module, resource, data or local traversal in an output's `value`; an input variable `var.x` there stays a read), Module input (a `module` block argument), Module reference, Resource reference, Data source reference, Local value reference, and Variable declaration (a `locals` key). A `variable` block label stays `write`.
- **Appended writes.** Current-file write highlights that the view appends take their syntactic type like any listed usage. So lua_ls definitions that `includeDeclaration = false` hides still show as Function declaration or Field initialization (design.md, Decision 5).
- **Registry.** `references.usage_types` becomes `true` for the `lua`, `shell` and `terraform` languages.
- **Case tables:** `tests/unit/references/usage_cases/{lua,shell,terraform}.lua`, ported from `drafts/verify.lua`, with their sources in `usage_cases/{lua,shell,terraform}/`.
- **Fixtures.** New files only:
  - `luaproj` gains `lua/shop/discount.lua`, `lua/shop/checkout.lua` and `spec/discount_spec.lua`, and an `apply` manifest entry;
  - `bashproj` gains `lib/tax.sh` and `bin/invoice.sh`, and a `rate` entry;
  - `tfproj` gains `network.tf` and `net/main.tf`, and `cidr` and `vpc` entries.
- **Renders:** "Proposed L1 — Lua function usages", "Proposed B1 — Bash variable usages" and "Proposed H1 — Terraform module usages".

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `references`: added "Lua usage types", "Bash usage types" and "Terraform usage types". No existing requirement or scenario changes.

## Impact

- Code:
  - Changed: `queries/lua/usages.scm`, `queries/bash/usages.scm`, `queries/hcl/usages.scm`.
  - Changed: `lua/gleb/languages/{lua,shell,terraform}/init.lua` (`usage_types = true`), and the classification of appended current-file writes in `lua/gleb/references/kind.lua` if the template doesn't already do it (design.md, Decision 5).
  - Unchanged: `queries/terraform/usages.scm` (`; inherits: hcl`).
- Tests:
  - unit: the three case tables, run by the shared case driver.
  - integration: lua_ls `gr` on `apply`, bashls `gr` on `rate` and `total`, terraform-ls `gr` on `cidr` and `vpc`.
  - screen: L1, B1 and H1.
- Fixture: `tests/fixtures/build.sh` (`luaproj`, `bashproj` and `tfproj` gain new files and manifest symbols).
- Plugins: none. Core keymaps: none.
- Unchanged scenarios:
  - `languages: Requirement: References facet` still holds: enabling the three facets supplies the required per-parser queries and case tables, and Terraform continues to inherit HCL through `queries/terraform/usages.scm`.
  - `languages: A missing usages query breaks the contract` still holds: the contract and its diagnostic are unchanged; this change supplies the queries required before the three gates become `true`.
  - `file-tree: gr keeps its global meaning in git status tree` still holds: the global `gr` mapping and its callback are untouched; only query files, the registry flag and classification change.
  - `references: Treesitter fallback classifies writes where a parser exists` still holds: `x = 1` (Lua) and `x=1` (Bash) still match only the write patterns, and `print(x)` / `echo "$x"` only the read catch-all.
  - `references: HCL fallback classifies variable labels and traversals` still holds: the `variable` label keeps its `write` pattern (no declaration capture precedes it), and `value = var.region` outside an output block only matches the `var.` read pattern.
  - `references: gr classifies every Lua local usage` still holds: `count = count + 1` and `print(count)` match no Lua type pattern, so lua_ls's write/read still decides.
  - `references: gr classifies every Bash variable usage` still holds: `count=…` is the write pattern, and `$((count + 1))` and `"$count"` only the read catch-all.
  - `references: Lua usages in production and spec files` still holds: the new files don't reference `total`, and the scenario names no type rows.
  - `references: Bash usages in production and test scripts` still holds: the new scripts don't reference `total`, and the scenario names no type rows.
  - `references: Terraform variable usages` still holds: the new files don't reference `var.region`, and the scenario names no type rows.
  - `references: Lua test paths`, `references: Bash test paths` and `references: Terraform test paths` still hold: the test patterns are unchanged.
  - `references: gr classifies every Terraform variable usage` still holds: `var.region` in `main.tf` and `outputs.tf` stay `read`, because the output pattern excludes `var.` traversals and only the `var.` read pattern matches.
  - `references: Terraform blocks are not type targets` still holds: this change adds no target-kind code, and its `cidr` scenario relies on the same `unknown` target.
- Out of scope:
  - "Usage in string constants" and comments: servers don't return those locations.
  - Lua definitions in other files that lua_ls hides behind `includeDeclaration = false`: field assignments, table keys and redefinitions.
  - `unset x` and `source` paths as their own types.
  - Terraform `moved`, `import` and `check` blocks.

## Decision (user, 2026-10-17)

- "it is implemented, but lacking. Goland system is ALOT reacher. … I want goland-like observability over references, which is sueprior. … create a spec to fix it for all langauges."

## Agent decisions

- **Mapping** of the draft ids (design.md, Decision 1):
  - `local_declaration` becomes Variable declaration.
  - The draft's `variable_`, `module_`, `output_`, `resource_` and `data_declaration` label captures are dropped: terraform-ls never returns declarations.
  - The `variable` label keeps `write`, so the HCL fallback scenario holds.
- **Richer than JetBrains:** Lua gets Function declaration, Parameter declaration and Field initialization next to EmmyLua's Call. Bash gets Call, Function declaration and Export where the Shell plugin has none. Terraform gets its module, resource, data, local, dependency and output edges where the HCL plugin has read/write only.
- **Input variables are never Output values.** The `output` type covers module, resource, data and local traversals in an output's `value`, the module's outward edges. An input variable there (`value = var.region`) is read like in any other expression. A module input reads a variable, and so does an output of it. This keeps `gr` on a variable about where it is read, and keeps the existing Terraform scenarios.
- **Terraform targets** are `unknown` through `fix-references-usage-types` and the registry's `target_kinds`. This change only relies on it.
- **Fixture symbols:** the facets keep `total` / `total` / `region` as their smoke symbols. `apply`, `rate`, `cidr` and `vpc` are extra manifest entries for the type scenarios. New code never mentions `total` or `var.region`, so the existing exact-row tests hold.
- **Renders** use V4's narrow fitted layout (`70x24`, no preview), one Current and one Proposed per language.
