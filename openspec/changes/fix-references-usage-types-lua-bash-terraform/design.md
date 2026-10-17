## Context

See proposal.md (Why, Evidence). The template `fix-references-usage-types` defines the catalogue, the `queries/<lang>/usages.scm` convention (`@usage.<id>` captures, start-exact match, lowest pattern index wins, top-level tree), the classification order and target-kind refinement. `languages-registry` gives each language a `references` facet. This change only adds queries, cases, fixtures and one facet field.

Research (2026-10-17):
- **JetBrains for these languages:**
  - EmmyLua: only "Function call" from its `UsageTypeProvider`, then the platform's read/write.
  - The JetBrains Shell plugin registers no `UsageTypeProvider` and no read/write detector, so every usage is "Unclassified".
  - The HCL plugin (Terraform) has a read/write detector (Value read / Value write) and "Usage in string constants" for references inside HIL strings.
  - We go richer, with the template's GoLand-worded catalogue: calls, declarations and module edges are what a reader of these languages asks about ("who calls this", "who exports it", "which module input feeds it").
- **What each server returns for `gr`** (`includeDeclaration = false`), checked against the extended fixtures with lua-language-server 3.17.1, bash-language-server 5.6.0 and terraform-ls 0.38.5:
  - **lua_ls:**
    - Ranges start at the bare identifier (`discount.apply` → `apply`).
    - Definitions are left out: `function M.f`, `M.f = function` redefinitions, `M.x = 1` field assignments, table-constructor keys and `local function f` redefinitions.
    - The view's current-file write highlights (documentHighlight kind Write) bring back the ones in the current file.
    - With `includeDeclaration = true`, `M.f = function` also yields a range starting at `function`.
  - **bashls:**
    - Bare names, never `$` or `${`.
    - It does not return the declaration at the cursor, and returns nothing for `(( x++ ))`.
    - Its documentHighlight has no kinds, so step 3 (query write/read) decides Bash value usages.
  - **terraform-ls:**
    - Every range starts at the traversal root (`var.cidr` → `var`, `module.vpc.id` → `module`).
    - It never returns declarations (labels, `locals` keys).
    - For a child-module variable it returns the parent's module argument name (`cidr = …`), but only once the parent module is indexed. terraform-ls indexes a module when one of its files is opened, so with only `net/main.tf` open the argument is missing (seen in a probe).
    - No documentHighlight (method not found).
- **Target kinds from documentSymbol:**
  - lua_ls: `function M.apply` is Function (12), and a table field `rate` is Number (16), so `unknown`.
  - bashls: functions are Function (12) and variables Variable (13).
  - terraform-ls: every block (`variable "cidr"`, `module "vpc"`, `resource …`) is Class (5). The template maps Class to `unknown` for Terraform (`fix-references-usage-types` Decision 3, scenario `references: Terraform blocks are not type targets`), and `languages-registry` moves that override into the facet as `target_kinds = { Class = "unknown" }`.

## Goals / Non-Goals

**Goals:**
- Usage types for Lua, Bash and Terraform from the verified drafts, with catalogue ids and nothing language-specific in Lua code.
- Every existing scenario of these languages keeps its meaning (proposal.md, Impact).

**Non-Goals:**
- Comment and string usages.
- Lua definitions in other files: lua_ls hides them with `includeDeclaration = false`, and asking for declarations would list the origin too.
- New catalogue ids. Every type maps to an existing one.

## Decisions

1. **Draft id → catalogue id.** The implementation owns the final files, but every case of the ported tables must pass.

   | Draft capture | Catalogue id | Label | Lang | Notes |
   |---|---|---|---|---|
   | `call` | `call` | Call | Lua, Bash | Lua `f()`, `f "s"`, `f {}`, `M.f()`, `obj:m()`; Bash command name (`source`, `.`, functions) |
   | `function_declaration` | `function_declaration` | Function declaration | Lua, Bash | Lua names of `function`/`local function`/`f = function`/`M.f = function`/`{ f = function }`, plus the `function` value; Bash `f()` and `function f` |
   | `parameter_declaration` | `parameter_declaration` | Parameter declaration | Lua | names in `parameters` |
   | `field_initialization` | `field_initialization` | Field initialization | Lua | `{ total = 1 }`; not `[k] = v`, not positional items |
   | `export` | `export` | Export | Bash | `export x` without a value |
   | `depends_on` | `depends_on` | Dependency | HCL | every segment in `depends_on = [...]` |
   | `output` | `output` | Output value | HCL | module, resource, data or local traversal in an `output` block's `value`, directly or one level deep (template interpolation, tuple, object value, function argument); never a `var.` traversal |
   | `module_reference` | `module_reference` | Module reference | HCL | `module.<name>.<output>` |
   | `resource_reference` | `resource_reference` | Resource reference | HCL | `<type>.<name>` for a non-reserved root |
   | `data_reference` | `data_reference` | Data source reference | HCL | `data.<type>.<name>` |
   | `local_reference` | `local_reference` | Local value reference | HCL | `local.<name>` |
   | `attribute_assignment` | `attribute_assignment` | Module input | HCL | argument names of a `module` block, except `source`, `version`, `count`, `for_each`, `providers` and `depends_on` |
   | `local_declaration` | `variable_declaration` | Variable declaration | HCL | `locals { name = … }` key |
   | `variable_declaration` | dropped | — | HCL | `variable` label: keeps the `write` pattern (HCL fallback scenario) |
   | `module_`, `output_`, `resource_`, `data_declaration` | dropped | — | HCL | labels; terraform-ls never returns them |
   | `write` | `write` | Value write | all | Lua `x = 1`, `local x`, `M.x = 1`, loop variables; Bash `x=1`, `arr[0]=v`, `declare/local/typeset x`, `for x in`, `read x`, `(( x++ ))`; HCL `variable` label |
   | `read` | `read` | Value read | all | catch-alls `(identifier)` / `(variable_name)`; HCL `var.<name>` |

   - Files: `queries/lua/usages.scm`, `queries/bash/usages.scm` and `queries/hcl/usages.scm` replace the write/read-only files from the template. `queries/terraform/usages.scm` stays `; inherits: hcl`. The query runner takes each buffer's parser language from its filetype (`vim.treesitter.language.get_lang`, `languages-registry` Decision 6), so a `terraform` buffer runs the `terraform` parser, whose query inherits the `hcl` file. Both parsers run the same cases.
   - Order inside each file, as in the drafts: specific patterns first, `@usage.write` / `@usage.read` last, a catch-all read at the end. Lua: `[k] = v` is captured as `read` before the field patterns. HCL: `depends_on`, then `output`, then declarations, module inputs and references, then write/read.
2. **Grammar facts the queries rely on** (from the drafts' comments and `drafts/tree.lua` dumps):
   - Lua:
     - A LuaCATS `---@param` comment is one leaf, so it is never classified.
     - A `require("…")` string has no identifier.
     - `M.f = function` puts the function in `expression_list`, so the `function` value is matched for the lua_ls range that starts there.
   - Bash:
     - `$x`, `${x:-d}` and `${a[@]}` hold a `variable_name` starting after `$`/`${`, which is where bashls ranges start.
     - `read -r x`: the `-r` flag is skipped with `#not-lua-match? "^-"`.
     - `export x=1` is an assignment, so it is `write`. Only a bare `export x` is `export`.
   - HCL:
     - A traversal `a.b.c` is `(expression (variable_expr (identifier)) (get_attr (identifier))…)`. Every segment is captured, so ranges starting at the root (terraform-ls) or at a segment both classify.
     - Output matching stops one level deep: `join(",", [aws_s3_bucket.logs.id])` falls back to `resource_reference`.
     - An output's `description` is not its value, so `var.x` there is `read`.
     - The output pattern captures the traversal root as `@_root` and ends with `(#not-eq? @_root "var")`. An input variable in an output value stays `read`, so `value = var.region` in the existing `outputs.tf` keeps its scenario. The segments use a quantified `(get_attr (identifier) @usage.output)*`.
     - Object keys are reads, and the resource type label is unclassified.
3. **Case tables.** `drafts/verify.lua` becomes `tests/unit/references/usage_cases/lua.lua`, `shell.lua` and `terraform.lua`, with the draft fixtures copied to `usage_cases/lua/shop/{cart,price}.lua`, `usage_cases/shell/{deploy,lib}.sh` and `usage_cases/terraform/{main.tf,net/main.tf}`. Entries keep the draft form `{ row, col, type|false, text }` (0-based, `text` asserts the position, `false` means no syntactic type) in the shared driver's format.
   - The terraform table runs once with `hcl` and once with `terraform`.
   - The draft's `parity()` checks against the old `kind_ts.lua` are dropped, because the template replaces `kind_ts`. Their write/read expectations stay as entries.
   - Renamed HCL expectations:
     - `tf/main.tf` 0:9 `"region"` → `false`, 0:10 `region` → `write`, 4:10 `tags` → `write`;
     - 9:2 `name` and 10:2 `common` → `variable_declaration`;
     - 13:8 `net`, 18:26 `logs`, 25:16 `base`, 35:8 `bucket_arn` → `false`;
     - `tf/net/main.tf` 0:10 `cidr` → `write`, 4:8 `vpc_id` → `false`, and 5:17 `var` and 5:21 `cidr` (an input variable in an output value) → `read`. The last two are also changed in `drafts/verify.lua`, whose query excludes `var.` traversals from `output`.
   - Totals: 67 Lua, 44 Bash and 64 Terraform cases (×2 parsers, 239 runs). All pass on Neovim 0.12.5 with the installed parsers.
4. **Terraform targets come from upstream.** terraform-ls block targets are `unknown` through `fix-references-usage-types` (Decision 3) and the registry's `target_kinds`. This change adds no facet field and no target-kind code. With `unknown`, every Terraform syntactic type is kept. Of the type-position ids, `variable_declaration` is the only one HCL has, and terraform-ls never returns it. The `cidr` gr scenario covers this at the `gr` level: `net/main.tf:6` and `:10` are reads of a Class target.
5. **Appended current-file writes are classified like listed usages.** The view appends documentHighlight Write ranges of the current file that references omitted, except at the origin. They go through the same order: query type first, then their server `write`, then the fallback.
   - So `M.apply = function` on `discount.lua:9` is `function_declaration`, although lua_ls only reports it as a highlight.
   - Lua `parameter_declaration` survives only for an `unknown` target. For a `variable` target it is a type-position id and is dropped to the server's `write`, as the template rules say.
6. **Registry.** In `lua/gleb/languages/{lua,shell,terraform}/init.lua`, `references.usage_types` changes from `{ disabled = "queued: fix-references-usage-types-lua-bash-terraform" }` to `true`. The contract then requires each language's query and case table.
7. **Fixtures** (`tests/fixtures/build.sh`). New files only. Every existing file, line and manifest entry is unchanged, and no new file mentions `total` (Lua, Bash) or `var.region` (Terraform). Tabs as in the existing Lua and Bash heredocs.
   - `luaproj`:
     - `lua/shop/discount.lua`:
       ```lua
       local M = { rate = 0.1 }

       ---@param amount number
       function M.apply(amount)
       	return amount * (1 - M.rate)
       end

       -- Flat-rate shops override the percentage.
       M.apply = function(amount)
       	return amount - M.rate
       end

       return M
       ```
     - `lua/shop/checkout.lua`:
       ```lua
       local discount = require("shop.discount")

       return discount.apply(100)
       ```
     - `spec/discount_spec.lua`:
       ```lua
       local discount = require("shop.discount")

       assert(discount.apply(100) == 99.9)
       ```
     - Manifest: `"apply"` = `identifier_locations apply lua/shop/discount.lua lua/shop/checkout.lua spec/discount_spec.lua`, which gives `discount.lua:4:12`, `:9:3`, `checkout.lua:3:17` and `discount_spec.lua:3:17`.
   - `bashproj`:
     - `lib/tax.sh`:
       ```bash
       #!/usr/bin/env bash
       rate=20
       export rate

       tax() {
       	printf '%s\n' "$(($1 * rate / 100))"
       }
       ```
     - `bin/invoice.sh`:
       ```bash
       #!/usr/bin/env bash
       source "$(dirname "$0")/../lib/tax.sh"

       rate=25
       tax 100
       ```
     - `bash -n` also checks both. Manifest: `"rate"` = `identifier_locations rate lib/tax.sh bin/invoice.sh`, which gives `tax.sh:2:1`, `:3:8`, `:6:25` and `invoice.sh:4:1`.
   - `tfproj`:
     - `network.tf`:
       ```hcl
       variable "vpc_cidr" {
         type = string
       }

       module "vpc" {
         source = "./net"
         cidr   = var.vpc_cidr
       }

       resource "aws_s3_bucket" "logs" {
         bucket     = module.vpc.id
         depends_on = [module.vpc]
       }

       output "vpc_id" {
         value = module.vpc.id
       }
       ```
     - `net/main.tf`:
       ```hcl
       variable "cidr" {
         type = string
       }

       locals {
         name = "subnet-${var.cidr}"
       }

       output "id" {
         value = var.cidr
       }
       ```
     - Manifest:
       - `"cidr"` = `identifier_locations cidr net/main.tf network.tf`, which gives `net/main.tf:1:11`, `:6:24`, `:10:15` and `network.tf:7:3`;
       - `"vpc"` = `identifier_locations vpc network.tf net/main.tf`, which gives `network.tf:5:9`, `:11:23`, `:12:24` and `:16:18`.
       - Names avoid substrings the word grep would also hit: `vpc_cidr`, `vpc_id`, `subnet-` and the `./net` source. `vpc` is grepped over two files because `grep -n` drops the file name for a single file.
   - **Verified `gr` results** (the spec scenarios), each a server range start:

     | Origin | Listed usage | Server source | Type |
     |---|---|---|---|
     | `apply`, `discount.lua:4` (function) | `lua/shop/checkout.lua:3:17` | references | `call` |
     | | `lua/shop/discount.lua:9:3` | current-file write highlight | `function_declaration` |
     | | `spec/discount_spec.lua:3:17` | references | `call` |
     | `rate`, `tax.sh:2` (variable) | `lib/tax.sh:3:8` | references | `export` |
     | | `lib/tax.sh:6:25` | references | `read` |
     | | `bin/invoice.sh:4:1` | references | `write` |
     | `total`, `price.sh:2` (function) | `bin/run.sh:4:1`, `test/price_test.sh:4:9` | references | `call` |
     | `cidr`, `net/main.tf:1` (block → unknown) | `network.tf:7:3` | references | `attribute_assignment` |
     | | `net/main.tf:6:20` | references | `read` |
     | | `net/main.tf:10:11` | references | `read` (input variable in an output value) |
     | `vpc`, `network.tf:5` (block → unknown) | `network.tf:11:16` | references | `module_reference` |
     | | `network.tf:12:17` | references | `depends_on` |
     | | `network.tf:16:11` | references | `output` |
     | `region`, `variables.tf:1` (block → unknown) | `main.tf:2:21` | references | `read` |
     | | `outputs.tf:2:11` | references | `read` (input variable in an output value) |

## Risks / Trade-offs

- **Grammar updates can rename nodes.** The query then fails to compile, the language falls back to server kinds, and the case tables fail loudly.
- **lua_ls hides definitions.** Function declarations and field initialisations in other files never reach the view. Only the current file's write highlights bring them in (Decision 5). A user who wants them must run `gr` from that file.
- **bashls matches by name across the workspace.** Any `rate` in any script is a reference. The types are still correct per position, but the list can include unrelated variables of the same name.
- **terraform-ls symbol kinds may change.** If a later version reports `variable` blocks as Variable, the override is redundant but harmless. The Terraform `gr` scenarios catch any other change.
- **Output value is narrower than "anything an output exports".** Input variables in an output value are reads, so `gr` on a variable never shows Output value. Only module, resource, data and local traversals do.
- **The `hcl` queries on the runtimepath are fragile.** `~/.local/share/nvim/site/queries/hcl` is a symlink into a `/var/folders/…/T/nvim.hlebbeladzed/…` temp directory, left by a sandboxed install. It disappears when macOS cleans temp files. Our `queries/hcl/usages.scm` lives in the config and is unaffected, but `highlights.scm` and the other nvim-treesitter hcl queries would vanish. Not fixed here: re-running the parser install (`:TSUpdate` or the sandbox's resync) relinks it to `~/.local/share/nvim/lazy/nvim-treesitter/runtime/queries/hcl`.

## Renders

Stand-ins: `λ` call, `ƒ` function declaration, `↗` export and output value (the same md-export glyph), `↔` dependency, `◇` module reference, `◎` read, `✎` write. Other stand-ins are as in `fix-references-usage-types`. The real-glyph, real-colour renders are in `renders/*.ansi`; view them with `command cat`. Each type group is `ReferencesUsageType<CamelId>[Label]`, created by `fix-references-usage-types`, so `make colorize` reports them until that change lands. File icons: `DevIconLua` `#51a0cf` (U+E620), `DevIconSh` `#4d5a5e` (U+E795) and `DevIconTerraform` `#5f43e9` (U+E69A). Each is drawn as `◆` with label group `ReferencesFileLabel<DevIconGroup>`. The editor behind the float is the fixture file the cursor is in.

**Current — Lua function usages**: `70x24`, Normal, `lua/shop/discount.lua` (extended luaproj fixture), lua_ls attached, `gr` on `apply` (line 4); default grouping; classification finished; query from `fix-references-usage-types` (write/read only). Every usage is unclassified: no usage type level, no hint entry.

```text
▎ discount.lua                                                        
   1 local M = { rate = 0.1 }                                         
   2                                                                  
   3 ---@param amount number                                          
   4 function M.apply(amount)                                         
   5     return amount * (1 - M.rate)                                 
   6 end          ╭ Usages of apply · 3 ───────────╮                  
   7              │ ▾ ▣ Production  2              │                  
   8 -- Flat-rate │   ▾ □ lua/shop  2              │                  
   9 M.apply = fun│       ◆ checkout.lua:3         │                  
  10     return am│       ◆ discount.lua:9         │                  
  11 end          │ ▾ ▲ Test  1                    │                  
  12              │   ▾ □ spec  1                  │                  
  13 return M     │       ◆ discount_spec.lua:3    │                  
  14              ├────────────────────────────────┤                  
  15              │ Tests: grouped t · ● Folders f │                  
  16              ╰────────────────────────────────╯                  
  17                                                                  
  18                                                                  
  19                                                                  
  20                                                                  
  21                                                                  
  22                                                                  
 NORMAL  ⎇ main                                                   lua 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
..................btttttttttttttttttttttbbbbbbbbbbbb..................
..................bfffPfppppppppppffsffffffffffffffb..................
..................bfffffDfddddddddffsffffffffffffffb..................
..................bcccccccGcggggggggggggcccccccccccb..................
..................bfffffffGfggggggggggggssfffffffffb..................
..................bfffEfeeeeffsffffffffffffffffffffb..................
..................bfffffDfddddffsffffffffffffffffffb..................
..................bfffffffGfgggggggggggggggggssffffb..................
..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................
..................bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxb..................
..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `x` [PickerHint] · `o` [PickerToggleOn] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconLua] · `g` [ReferencesFileLabelDevIconLua]

**Proposed L1 — Lua function usages**: `70x24`, as Current with this change; calls and the redefinition by assignment get their types.

```text
▎ discount.lua                                                        
   1 local M = { rate = 0.1 }                                         
   2                                                                  
   3 ---@param amount number                                          
   4 func╭ Usages of apply · 3 ────────────────────────────╮          
   5     │ ▾ ▣ Production  2                               │          
   6 end │   ▾ λ Call  1                                   │          
   7     │     ▾ □ lua/shop  1                             │          
   8 -- F│         ◆ checkout.lua:3                        │          
   9 M.ap│   ▾ ƒ Function declaration  1                   │          
  10     │     ▾ □ lua/shop  1                             │          
  11 end │         ◆ discount.lua:9                        │          
  12     │ ▾ ▲ Test  1                                     │          
  13 retu│   ▾ λ Call  1                                   │          
  14     │     ▾ □ spec  1                                 │          
  15     │         ◆ discount_spec.lua:3                   │          
  16     ├─────────────────────────────────────────────────┤          
  17     │ Tests: grouped t · ● Folders f · ● Usage type u │          
  18     ╰─────────────────────────────────────────────────╯          
  19                                                                  
  20                                                                  
  21                                                                  
  22                                                                  
 NORMAL  ⎇ main                                                   lua 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
.........btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffLfllllffsfffffffffffffffffffffffffffffffffffb..........
.........bfffffffDfddddddddffsfffffffffffffffffffffffffffffb..........
.........bcccccccccGcggggggggggggccccccccccccccccccccccccccb..........
.........bfffffKfkkkkkkkkkkkkkkkkkkkkffsfffffffffffffffffffb..........
.........bfffffffDfddddddddffsfffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggggssffffffffffffffffffffffffb..........
.........bfffEfeeeeffsfffffffffffffffffffffffffffffffffffffb..........
.........bfffffLfllllffsfffffffffffffffffffffffffffffffffffb..........
.........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggggggggggssfffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `x` [PickerHint] · `o` [PickerToggleOn] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconLua] · `g` [ReferencesFileLabelDevIconLua] · `L` [ReferencesUsageTypeCall] · `l` [ReferencesUsageTypeCallLabel] · `K` [ReferencesUsageTypeFunctionDeclaration] · `k` [ReferencesUsageTypeFunctionDeclarationLabel]

**Current — Bash variable usages**: `70x24`, Normal, `lib/tax.sh` (extended bashproj fixture), bashls attached, `gr` on `rate` (line 2); default grouping; classification finished; query from `fix-references-usage-types` (write/read only). The export is a plain read.

```text
▎ tax.sh                                                              
   1 #!/usr/bin/env bash                                              
   2 rate=20                                                          
   3 export rate                                                      
   4                                                                  
   5 tax() {                                                          
   6     ╭ Usages of rate · 3 ─────────────────────────────╮          
   7 }   │ ▾ ▣ Production  3                               │          
   8     │   ▾ ◎ Value read  2                             │          
   9     │     ▾ □ lib  2                                  │          
  10     │         ◆ tax.sh:3                              │          
  11     │         ◆ tax.sh:6                              │          
  12     │   ▾ ✎ Value write  1                            │          
  13     │     ▾ □ bin  1                                  │          
  14     │         ◆ invoice.sh:4                          │          
  15     ├─────────────────────────────────────────────────┤          
  16     │ Tests: grouped t · ● Folders f · ● Usage type u │          
  17     ╰─────────────────────────────────────────────────╯          
  18                                                                  
  19                                                                  
  20                                                                  
  21                                                                  
  22                                                                  
 NORMAL  ⎇ main                                                    sh 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
.........bttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffYfyyyyyyyyyyffsfffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bcccccccccGcggggggccccccccccccccccccccccccccccccccb..........
.........bfffffffffGfggggggssffffffffffffffffffffffffffffffb..........
.........bfffffWfwwwwwwwwwwwffsffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggssffffffffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `x` [PickerHint] · `o` [PickerToggleOn] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconSh] · `g` [ReferencesFileLabelDevIconSh] · `Y` [ReferencesUsageTypeRead] · `y` [ReferencesUsageTypeReadLabel] · `W` [ReferencesUsageTypeWrite] · `w` [ReferencesUsageTypeWriteLabel]

**Proposed B1 — Bash variable usages**: `70x24`, as Current with this change; the bare `export rate` is an Export.

```text
▎ tax.sh                                                              
   1 #!/usr/bin/env bash                                              
   2 rate=20                                                          
   3 export rate                                                      
   4                                                                  
   5 tax(╭ Usages of rate · 3 ─────────────────────────────╮          
   6     │ ▾ ▣ Production  3                               │          
   7 }   │   ▾ ↗ Export  1                                 │          
   8     │     ▾ □ lib  1                                  │          
   9     │         ◆ tax.sh:3                              │          
  10     │   ▾ ◎ Value read  1                             │          
  11     │     ▾ □ lib  1                                  │          
  12     │         ◆ tax.sh:6                              │          
  13     │   ▾ ✎ Value write  1                            │          
  14     │     ▾ □ bin  1                                  │          
  15     │         ◆ invoice.sh:4                          │          
  16     ├─────────────────────────────────────────────────┤          
  17     │ Tests: grouped t · ● Folders f · ● Usage type u │          
  18     ╰─────────────────────────────────────────────────╯          
  19                                                                  
  20                                                                  
  21                                                                  
  22                                                                  
 NORMAL  ⎇ main                                                    sh 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
.........bttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffXfxxxxxxffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bcccccccccGcggggggccccccccccccccccccccccccccccccccb..........
.........bfffffYfyyyyyyyyyyffsfffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggssffffffffffffffffffffffffffffffb..........
.........bfffffWfwwwwwwwwwwwffsffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggssffffffffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `x` [PickerHint] · `o` [PickerToggleOn] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconSh] · `g` [ReferencesFileLabelDevIconSh] · `X` [ReferencesUsageTypeExport] · `x` [ReferencesUsageTypeExportLabel] · `Y` [ReferencesUsageTypeRead] · `y` [ReferencesUsageTypeReadLabel] · `W` [ReferencesUsageTypeWrite] · `w` [ReferencesUsageTypeWriteLabel]

**Current — Terraform module usages**: `70x24`, Normal, `network.tf` (extended tfproj fixture), terraform-ls attached, `gr` on `module "vpc"` (line 5); default grouping; classification finished; query from `fix-references-usage-types` (write/read only), block targets `unknown`. Every usage is a read.

```text
▎ network.tf                                                          
   1 variable "vpc_cidr" {                                            
   2   type = string                                                  
   3 }                                                                
   4                                                                  
   5 module "vpc" {                                                   
   6   source = "./net"                                               
   7   ci╭ Usages of vpc · 3 ──────────────────────────────╮          
   8 }   │ ▾ ▣ Production  3                               │          
   9     │   ▾ ◎ Value read  3                             │          
  10 reso│     ▾ □ .  3                                    │          
  11   bu│         ◆ network.tf:11                         │          
  12   de│         ◆ network.tf:12                         │          
  13 }   │         ◆ network.tf:16                         │          
  14     ├─────────────────────────────────────────────────┤          
  15 outp│ Tests: grouped t · ● Folders f · ● Usage type u │          
  16   va╰─────────────────────────────────────────────────╯          
  17 }                                                                
  18                                                                  
  19                                                                  
  20                                                                  
  21                                                                  
  22                                                                  
 NORMAL  ⎇ main                                             terraform 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
.........btttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffYfyyyyyyyyyyffsfffffffffffffffffffffffffffffb..........
.........bfffffffDfdffsffffffffffffffffffffffffffffffffffffb..........
.........bcccccccccGcggggggggggccccccccccccccccccccccccccccb..........
.........bfffffffffGfggggggggggsssfffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggsssfffffffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `x` [PickerHint] · `o` [PickerToggleOn] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconTerraform] · `g` [ReferencesFileLabelDevIconTerraform] · `Y` [ReferencesUsageTypeRead] · `y` [ReferencesUsageTypeReadLabel]

**Proposed H1 — Terraform module usages**: `70x24`, as Current with this change; the `depends_on` entry is a Dependency, the traversal a Module reference and the output's value an Output value.

```text
▎ network.tf                                                          
   1 variable "vpc_cidr" {                                            
   2   type = string                                                  
   3 }                                                                
   4                                                                  
   5 modu╭ Usages of vpc · 3 ──────────────────────────────╮          
   6   so│ ▾ ▣ Production  3                               │          
   7   ci│   ▾ ↔ Dependency  1                             │          
   8 }   │     ▾ □ .  1                                    │          
   9     │         ◆ network.tf:12                         │          
  10 reso│   ▾ ◇ Module reference  1                       │          
  11   bu│     ▾ □ .  1                                    │          
  12   de│         ◆ network.tf:11                         │          
  13 }   │   ▾ ↗ Output value  1                           │          
  14     │     ▾ □ .  1                                    │          
  15 outp│         ◆ network.tf:16                         │          
  16   va├─────────────────────────────────────────────────┤          
  17 }   │ Tests: grouped t · ● Folders f · ● Usage type u │          
  18     ╰─────────────────────────────────────────────────╯          
  19                                                                  
  20                                                                  
  21                                                                  
  22                                                                  
 NORMAL  ⎇ main                                             terraform 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
.........btttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffNfnnnnnnnnnnffsfffffffffffffffffffffffffffffb..........
.........bfffffffDfdffsffffffffffffffffffffffffffffffffffffb..........
.........bcccccccccGcggggggggggccccccccccccccccccccccccccccb..........
.........bfffffMfmmmmmmmmmmmmmmmmffsfffffffffffffffffffffffb..........
.........bfffffffDfdffsffffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggsssfffffffffffffffffffffffffb..........
.........bfffffOfooooooooooooffsfffffffffffffffffffffffffffb..........
.........bfffffffDfdffsffffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggsssfffffffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `x` [PickerHint] · `o` [PickerToggleOn] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconTerraform] · `g` [ReferencesFileLabelDevIconTerraform] · `N` [ReferencesUsageTypeDependsOn] · `n` [ReferencesUsageTypeDependsOnLabel] · `M` [ReferencesUsageTypeModuleReference] · `m` [ReferencesUsageTypeModuleReferenceLabel] · `O` [ReferencesUsageTypeOutput] · `o` [ReferencesUsageTypeOutputLabel]
