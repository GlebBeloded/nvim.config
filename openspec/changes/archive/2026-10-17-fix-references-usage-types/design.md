## Context

See proposal.md (Why, Evidence). Research (2026-10-17):

- **JetBrains has no treesitter.** Each IDE parses to PSI. A language's `UsageTypeProvider` gets the reference element and checks its parents' PSI classes: for Go, `GoCompositeLit` → Struct initialization, `GoReceiver` → Receiver, `GoResult` → Return type, and so on (read from `GoUsageTypeProvider.class` in the local GoLand). A few rules also use resolve: `isConversionExpression`, `isTrulyBuiltin`, generics. A treesitter parent match is the closest Neovim equivalent; the LSP supplies the one semantic fact needed, the target's symbol kind.
- **Platform order** (`UsageTypeGroupingRule`):
  1. A usage in a comment is "Usage in comments".
  2. Otherwise the providers run in extension-point order and the first non-null result wins.
  3. Otherwise a `ReadWriteAccessUsage` gives Value write (ReadWrite counts as write) or Value read.
  4. Otherwise the usage is "Unclassified".
  Groups compare their display text with `String.compareTo`. Default nesting: scope (test/production), then usage type, then module, directory and file.
- **Richness by language.** Go: 16 types. JS/TS (`JSUsageTypeProvider`): about 12. Python: 5. intellij-rust: about 14, lowercase. EmmyLua: only "Function call". HCL: read/write only. The JetBrains Shell plugin: none. We go past JetBrains outside Go and JS, with GoLand wording.
- **No LSP reference kinds.** LSP PR #2202 (`ReferenceKind`) is still open. Servers only give Read/Write through documentHighlight (tsserver: `isWriteAccess`). No Neovim plugin classifies usage types.
- **Where servers start a reference range** (checked against the real servers):
  - gopls, basedpyright, rust-analyzer, lua_ls and bashls: the last identifier segment (`m.Thing`, `crate::a::Thing`, `obj.method()`, `$x` → `x`).
  - terraform-ls: the root of the whole traversal (`var.region` starts at `var`).
  - lua_ls also returns `M.f = function` with a range starting at `function`.
- **Parsers:** go, typescript, tsx, javascript, python, rust, lua, bash, hcl and terraform are all installed (`lua/gleb/treesitter.lua`).

## Goals / Non-Goals

**Goals:**
- GoLand's usage types for Go now. Catalogue ids for every configured language, so the follow-up changes only add queries.
- One generic, data-driven classifier: per-language query files, with nothing language-specific in Lua.
- The JetBrains order and grouping.

**Non-Goals:**
- Queries for the other languages (follow-up changes).
- Comment and string usages.
- Filters.

## Decisions

1. **Query files.**
   - Each filetype's parser language has `queries/<lang>/usages.scm` on the runtimepath, loaded with `vim.treesitter.query.get(lang, "usages")`. `; inherits:` works, so `terraform` inherits `hcl`.
   - Captures are named `@usage.<id>`, with an id from the catalogue. `@_x` captures are helpers and are ignored.
   - A usage's candidates are the `@usage.*` captures whose node starts exactly at the usage's start (row and byte column, after the UTF-16 conversion). They come from `query:iter_matches(root, source, row, row + 1)` on the top-level tree, with injections ignored, because Rust macro injections re-parse token trees.
   - The candidate with the lowest pattern index wins, and inherited files come first.
   - The verified Go draft is `drafts/queries/go/usages.scm`. Its generator is `drafts/gen_go.py`, which expands wrapper nesting with `#has-parent?` chains to depth 3. Its case table is `drafts/cases.lua` and its verifier is `drafts/verify.lua`, with 231 cases passing on Neovim 0.12.5 for Go, TS, TSX and JS.
   - The draft's `value_write` capture is renamed `write`. The implementation owns the final file and may restructure it, but every draft case must still pass.
2. **Classification order.** For each usage (`kind.lua`):
   1. A query type that is not `write`/`read`, kept by the target-kind rules (Decision 3).
   2. Otherwise the server's write/read, as today: documentHighlight per file, or tsserver `isWriteAccess`.
   3. Otherwise the query's `write`/`read` capture.
   4. Otherwise `unclassified`.
   - Step 1 needs only the source text, so a file whose server times out still gets its syntactic types.
   - Current-file write highlights that references omitted are still appended, unchanged.
3. **Target kind.**
   - `request_callable` becomes `request_target_kind`: the same definition and documentSymbol lookup, mapping SymbolKind to a kind.

     | SymbolKind | Target kind |
     |---|---|
     | Function, Method, Constructor | `function` |
     | Class, Struct, Interface, Enum, TypeParameter | `type` |
     | Field, Property, EnumMember | `field` |
     | Variable, Constant | `variable` |
     | anything else, or a failed lookup | `unknown` |

     Per-filetype overrides of this mapping live beside it in `kind.lua`. `terraform`, `tf` and `hcl` map Class to `unknown`, because terraform-ls 0.38.5 reports every block (`variable`, `module`, …) as Class; without the override every Terraform read would be dropped. `languages-registry` moves the overrides into the `references` facet as `target_kinds`.

     A Variable or Constant whose definition name node is a treesitter `type_identifier` counts as `type`. vtsls reports `type Amount = …` as Variable; Go, Rust and TypeScript all name their type declarations with `type_identifier`. This costs one parse of the definition file, and only for those two kinds.

   - Rules:
     - `function` and `type` targets never get `write`/`read`, so steps 2 and 3 are skipped. Today's callable rule becomes part of this.
     - `function_argument` needs a `function` target. `static_member` needs a `type` target.
     - A Go `call` with a `type` target becomes `type_conversion`.
     - For a known target that is not a `type`, type-position ids are dropped: `field_declaration`, `parameter_declaration`, `return_type`, `receiver`, `variable_declaration`, `const_declaration`, `type_alias`, `type_assertion`, `type_conversion`, `type_instantiation`, `type_constraint`, `type_parameter_declaration`, `cast`, `instanceof`, `extends`, `impl` and `catch`.
     - An `unknown` target keeps every syntactic type except `function_argument` and `static_member`.
4. **The fallback moves into query files.** `kind_ts.lua` becomes the query runner for steps 1 and 3. Its inline Lua, Bash and HCL queries move to `queries/{lua,bash,hcl}/usages.scm` with the same captures, and `queries/terraform/usages.scm` is `; inherits: hcl`. A position no capture covers is `read` when the language's query loaded, as `kind_ts` did before. With no parser, the usage is `unclassified`.
5. **Tree** (`tree.lua`):
   - The `Usage type` level sits between test scope and folder.
   - Groups are ordered by label in byte order (JetBrains `String.compareTo`): `Call` < `Field declaration` < … < `Unclassified` < `Value read` < `Value write`.
   - The level is built when at least one listed usage is not `unclassified`. Its node ids are `type:<scope>:<id>`, so folds and the selection carry over.
6. **Toggle and state.**
   - The action `references.toggle_usage_type` is bound to `u` in `settings/keymap.json`, replacing `references.toggle_read_write` on `w`.
   - `state.lua` stores `usage_type` (default true). When only a legacy `read_write` is stored, its value is used and saved under the new key.
   - With the level off, typed rows carry a right-aligned `<icon> <tag>`. When a row and its tag don't fit, the path is shortened from the left with `…`, as in V3.
7. **Icons and colours** (`icons.lua`):
   - One icon group and one label group per catalogue entry: `ReferencesUsageType<CamelId>` and `ReferencesUsageType<CamelId>Label`. The label colour is `mix(icon, fg1, 0.7)`, recomputed on `ColorScheme`.
   - The old `ReferencesWrite`/`ReferencesRead[Label]` become `ReferencesUsageTypeWrite`/`ReferencesUsageTypeRead[Label]`.
8. **Fixture** (`tests/fixtures/build.sh`, `gomod`). New files only, so every existing line number holds:
   - `billing/batch.go`, with the content of the T1 preview: `Batch` with two `Invoice` fields, `NewInvoice` returning `&Invoice{Lines: …}`, and `Merge(inv Invoice, extra []int) Invoice`.
   - `billing/invoice_test.go`: `TestDue` builds `Invoice{Lines: []int{100, 250}}` on line 6 and checks `inv.Due()` equals `"$3.50"`.
   - The manifest gains `"Invoice"`, listing its 9 locations.

## Catalogue

Ids in **bold** are used by the Go query in this change. The rest are reserved for the follow-up changes. Colours are gruvbox-material, grouped by family:
- **purple:** calls and creation
- **aqua:** declarations that use the symbol
- **orange:** type relations
- **green:** module edges
- **yellow / blue:** read / write
- **grey:** structural or unknown

| Label | id | Icon (Nerd Font) | Colour | Tag |
|---|---|---|---|---|
| Call | **call** | cod-symbol_method U+EA8C | purple | call |
| Catch clause | catch | md-shield_outline U+F0499 | aqua | catch |
| Const declaration | **const_declaration** | cod-symbol_constant U+EB5D | aqua | const |
| Data source reference | data_reference | md-database_outline U+F1632 | aqua | data |
| Decorator | decorator | md-at U+F0065 | purple | decorator |
| Dependency | depends_on | md-link_variant U+F0339 | orange | depends |
| Export | export | md-export U+F0207 | green | export |
| Field access | field_access | cod-symbol_property U+EB65 | grey | field |
| Field declaration | **field_declaration** | cod-symbol_field U+EB5F | aqua | field |
| Field initialization | field_initialization | cod-symbol_field U+EB5F | purple | init |
| Function argument | **function_argument** | md-function_variant U+F0871 | purple | arg |
| Function declaration | function_declaration | md-function U+F0295 | aqua | func |
| Impl | impl | cod-type_hierarchy U+EBB9 | orange | impl |
| Import | **import** | cod-package U+EB29 | green | import |
| Keyword argument | keyword_argument | cod-symbol_key U+EA93 | purple | kwarg |
| Local value reference | local_reference | cod-symbol_variable U+EA88 | aqua | local |
| Macro argument | macro_argument | md-pound U+F0423 | purple | macro arg |
| Macro call | macro | md-pound U+F0423 | purple | macro |
| Module input | attribute_assignment | md-import U+F02FA | purple | input |
| Module reference | module_reference | md-cube_outline U+F01A7 | aqua | module |
| New instance creation | new | cod-symbol_structure U+EA91 | purple | new |
| Output value | output | md-export U+F0207 | green | output |
| Parameter declaration | **parameter_declaration** | cod-symbol_parameter U+EA92 | aqua | param |
| Pattern | pattern | md-shape_outline U+F0832 | orange | pattern |
| Receiver | **receiver** | cod-symbol_class U+EB5B | aqua | receiver |
| Resource reference | resource_reference | md-cloud_outline U+F0163 | aqua | resource |
| Return type | **return_type** | md-keyboard_return U+F0311 | aqua | return |
| Static member access | static_member | cod-symbol_namespace U+EA8B | orange | static |
| Struct initialization | **struct_initialization** | cod-symbol_structure U+EA91 | purple | init |
| Supertype | extends | cod-type_hierarchy_sub U+EBBA | orange | supertype |
| Type alias | **type_alias** | cod-symbol_class U+EB5B | orange | alias |
| Type assertion | **type_assertion** | cod-symbol_operator U+EB64 | orange | assert |
| Type cast | cast | md-swap_horizontal U+F04E1 | orange | cast |
| Type check | instanceof | cod-symbol_operator U+EB64 | orange | check |
| Type constraint | **type_constraint** | cod-filter U+EAF1 | orange | constraint |
| Type conversion | **type_conversion** | md-swap_horizontal U+F04E1 | orange | convert |
| Type instantiation | **type_instantiation** | md-code_tags U+F0174 | orange | type arg |
| Type parameter declaration | **type_parameter_declaration** | cod-symbol_parameter U+EA92 | orange | type param |
| Unclassified | **unclassified** | cod-question U+EB32 | grey | (none) |
| Value read | **read** | md-eye U+F0208 | yellow | read |
| Value write | **write** | md-pencil U+F03EB | blue | write |
| Variable declaration | **variable_declaration** | cod-symbol_variable U+EA88 | aqua | var |

Grey is the palette's `grey2`. Each codepoint was checked against Nerd Fonts `glyphnames.json`.

## Risks / Trade-offs

- **Grammar updates can rename nodes.** The query then fails to compile: it is loaded with `pcall`, that language falls back to step 2, and the unit case tables fail loudly.
- **Syntax alone is ambiguous** for Go `T(x)`, function values and static members. Target-kind refinement covers these. With an `unknown` kind the result can be wrong, for example a conversion shown as a call. That is acceptable: GoLand needs resolve for the same cases.
- **Overlapping patterns:** the lowest pattern index wins. The draft verifiers print every shadowed capture, so a reorder is visible.

## Renders

Stand-ins: `λ` call, `≡` field declaration, `∷` parameter declaration, `⊙` receiver, `↵` return type, `⊞` struct initialization, `✎` write, `◎` read. Other stand-ins are as in `references-view`. The real-glyph, real-colour renders are in `renders/*.ansi`; view them with `command cat`. Each new type group is `ReferencesUsageType<CamelId>`. `make colorize` shows them as plain text until this change creates them.

**Current — struct usages**: `100x30`, Normal, `billing/invoice.go` (gomod fixture), gopls attached, `gr` on `Invoice` (line 6); default grouping; classification finished. Both receivers are plain rows: no usage type level, no hint entry.

```text
▎ invoice.go                                                                                        
  ╭ Usages of Invoice · 2 ───────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  2                        │ billing/invoice.go:11                             │  
  │   ▾ □ billing  2                         │   1  package billing                              │  
  │       ◆ invoice.go:11                    │   2                                               │  
  │       ◆ invoice.go:20                    │   3  import "example.com/fixture/internal/money"  │  
  │                                          │   4                                               │  
  │                                          │   5  // Invoice is a list of line amounts in cent…│  
  │                                          │   6  type Invoice struct {                        │  
  │                                          │   7      Lines []int                              │  
  │                                          │   8  }                                            │  
  │                                          │   9                                               │  
  │                                          │  10  // Due renders the sum of the lines.         │  
  │                                          │  11  func (i Invoice) Due() string {              │  
  │                                          │  12      total := 0                               │  
  │                                          │  13      for _, cents := range i.Lines {          │  
  │                                          │  14          total += cents                       │  
  │                                          │  15      }                                        │  
  │                                          │  16      return money.Format(total)               │  
  │                                          │  17  }                                            │  
  │                                          │  18                                               │  
  │                                          │  19  // Rendered renders every line.              │  
  │                                          │  20  func (i Invoice) Rendered() []string {       │  
  │                                          │  21      lines := []string{}                      │  
  │                                          │  22      for _, cents := range i.Lines {          │  
  │                                          │  23          lines = append(lines, money.Format(c…│  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                                          Tests: grouped t · ● Folders f · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..btttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..
..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffkkkkkkkffffffffffffffffffffffffffffffffffffffb..
..bcccccccGcggggggggggcccccccccccccccccccccccbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfggggggggggsssffffffffffffffffffffbfsssffkkkkkkfqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffkkkkffffhhhhhhhffFFFfffTTTTTTffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffFFFFFFffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkffffhhhhhhhffFFFFFFFFfffffTTTTTTfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffFFFFFFfffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bffffffffffffffffffffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo]

**Proposed V1 — default grouping**: `100x30`, Normal, `billing/invoice.go`, gopls attached, `gr` on `Format` (line 16); tests grouped, folders on, usage type on; classification finished; first usage selected; preview with the file's own treesitter highlighting, usage line number [CursorLineNr], usages of `Format` [Search].

```text
▎ invoice.go                                                                                        
  ╭ Usages of Format · 4 ────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  3                        │ billing/invoice.go:16                             │  
  │   ▾ λ Call  3                            │   5  // Invoice is a list of line amounts in cent…│  
  │     ▾ □ billing  2                       │   6  type Invoice struct {                        │  
  │         ◆ invoice.go:16                  │   7      Lines []int                              │  
  │         ◆ invoice.go:23                  │   8  }                                            │  
  │     ▾ □ report  1                        │   9                                               │  
  │         ◆ summary.go:7                   │  10  // Due renders the sum of the lines.         │  
  │ ▾ ▲ Test  1                              │  11  func (i Invoice) Due() string {              │  
  │   ▾ λ Call  1                            │  12      total := 0                               │  
  │     ▾ □ internal/money  1                │  13      for _, cents := range i.Lines {          │  
  │         ◆ money_test.go:6                │  14          total += cents                       │  
  │                                          │  15      }                                        │  
  │                                          │  16      return money.Format(total)               │  
  │                                          │  17  }                                            │  
  │                                          │  18                                               │  
  │                                          │  19  // Rendered renders every line.              │  
  │                                          │  20  func (i Invoice) Rendered() []string {       │  
  │                                          │  21      lines := []string{}                      │  
  │                                          │  22      for _, cents := range i.Lines {          │  
  │                                          │  23          lines = append(lines, money.Format(c…│  
  │                                          │  24      }                                        │  
  │                                          │  25      return lines                             │  
  │                                          │  26  }                                            │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                         Tests: grouped t · ● Folders f · ● Usage type u · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..
..bfffffLfllllffsffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..
..bcccccccccGcggggggggggcccccccccccccccccccccbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..
..bfffffffffGfggggggggggsssffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffffGfggggggggggssfffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFfffTTTTTTffffffffffffffffb..
..bfffffLfllllffsffffffffffffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..
..bfffffffDfddddddddddddddffsffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bfffffffffGfgggggggggggggssffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkfffffffhhhhhhffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFFFFFFfffffTTTTTTfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffhhhhhhfffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `L` [ReferencesUsageTypeCall] · `l` [ReferencesUsageTypeCallLabel]

**Proposed V2 — tests hidden**: `100x30`, as V1 after `t` (grouped → hidden).

```text
▎ invoice.go                                                                                        
  ╭ Usages of Format · 3 ────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  3                        │ billing/invoice.go:16                             │  
  │   ▾ λ Call  3                            │   5  // Invoice is a list of line amounts in cent…│  
  │     ▾ □ billing  2                       │   6  type Invoice struct {                        │  
  │         ◆ invoice.go:16                  │   7      Lines []int                              │  
  │         ◆ invoice.go:23                  │   8  }                                            │  
  │     ▾ □ report  1                        │   9                                               │  
  │         ◆ summary.go:7                   │  10  // Due renders the sum of the lines.         │  
  │                                          │  11  func (i Invoice) Due() string {              │  
  │                                          │  12      total := 0                               │  
  │                                          │  13      for _, cents := range i.Lines {          │  
  │                                          │  14          total += cents                       │  
  │                                          │  15      }                                        │  
  │                                          │  16      return money.Format(total)               │  
  │                                          │  17  }                                            │  
  │                                          │  18                                               │  
  │                                          │  19  // Rendered renders every line.              │  
  │                                          │  20  func (i Invoice) Rendered() []string {       │  
  │                                          │  21      lines := []string{}                      │  
  │                                          │  22      for _, cents := range i.Lines {          │  
  │                                          │  23          lines = append(lines, money.Format(c…│  
  │                                          │  24      }                                        │  
  │                                          │  25      return lines                             │  
  │                                          │  26  }                                            │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                          Tests: hidden t · ● Folders f · ● Usage type u · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..
..bfffffLfllllffsffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..
..bcccccccccGcggggggggggcccccccccccccccccccccbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..
..bfffffffffGfggggggggggsssffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffffGfggggggggggssfffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFfffTTTTTTffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkfffffffhhhhhhffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFFFFFFfffffTTTTTTfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffhhhhhhfffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bffffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `L` [ReferencesUsageTypeCall] · `l` [ReferencesUsageTypeCallLabel]

**Proposed V3 — tests mixed, folders off**: `100x30`, as V1 after `t` `t` and `f`; rows are paths relative to the working directory under their usage type, test usages carry a Test tag.

```text
▎ invoice.go                                                                                        
  ╭ Usages of Format · 4 ────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ λ Call  4                              │ billing/invoice.go:16                             │  
  │   ◆ billing/invoice.go:16                │   5  // Invoice is a list of line amounts in cent…│  
  │   ◆ billing/invoice.go:23                │   6  type Invoice struct {                        │  
  │   ◆ …ternal/money/money_test.go:6 ▲ test │   7      Lines []int                              │  
  │   ◆ report/summary.go:7                  │   8  }                                            │  
  │                                          │   9                                               │  
  │                                          │  10  // Due renders the sum of the lines.         │  
  │                                          │  11  func (i Invoice) Due() string {              │  
  │                                          │  12      total := 0                               │  
  │                                          │  13      for _, cents := range i.Lines {          │  
  │                                          │  14          total += cents                       │  
  │                                          │  15      }                                        │  
  │                                          │  16      return money.Format(total)               │  
  │                                          │  17  }                                            │  
  │                                          │  18                                               │  
  │                                          │  19  // Rendered renders every line.              │  
  │                                          │  20  func (i Invoice) Rendered() []string {       │  
  │                                          │  21      lines := []string{}                      │  
  │                                          │  22      for _, cents := range i.Lines {          │  
  │                                          │  23          lines = append(lines, money.Format(c…│  
  │                                          │  24      }                                        │  
  │                                          │  25      return lines                             │  
  │                                          │  26  }                                            │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                           Tests: mixed t · ○ Folders f · ● Usage type u · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffLfllllffsffffffffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..
..bcccGcggggggggggggggggggcccccccccccccccccccbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfffGfggggggggggggggggggsssffffffffffffffffbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..
..bfffGfgggggggggggggggggggggggggggssfEfeeeefbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..
..bfffGfgggggggggggggggggssffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFfffTTTTTTffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkfffffffhhhhhhffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFFFFFFfffffTTTTTTfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffhhhhhhfffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `L` [ReferencesUsageTypeCall] · `l` [ReferencesUsageTypeCallLabel]

**Proposed V4 — no preview**: `70x24`, as V1 in a 70-column editor; the preview is hidden, the window shrinks to its content and stays centred, the hint row drops Preview and Open.

```text
▎ invoice.go                                                          
   1 package billing                                                  
   2                                                                  
   3 import "example.com/fixture/internal/money"                      
   4     ╭ Usages of Format · 4 ───────────────────────────╮          
   5 // I│ ▾ ▣ Production  3                               │          
   6 type│   ▾ λ Call  3                                   │          
   7     │     ▾ □ billing  2                              │          
   8 }   │         ◆ invoice.go:16                         │          
   9     │         ◆ invoice.go:23                         │          
  10 // D│     ▾ □ report  1                               │          
  11 func│         ◆ summary.go:7                          │          
  12     │ ▾ ▲ Test  1                                     │          
  13     │   ▾ λ Call  1                                   │          
  14     │     ▾ □ internal/money  1                       │          
  15     │         ◆ money_test.go:6                       │          
  16     ├─────────────────────────────────────────────────┤          
  17 }   │ Tests: grouped t · ● Folders f · ● Usage type u │          
  18     ╰─────────────────────────────────────────────────╯          
  19 // Rendered renders every line.                                  
  20 func (i Invoice) Rendered() []string {                           
  21     lines := []string{}                                          
  22     for _, cents := range i.Lines {                              
 NORMAL  ⎇ main                                                    go 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
.........bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffLfllllffsfffffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddddddffsffffffffffffffffffffffffffffffb..........
.........bcccccccccGcggggggggggccccccccccccccccccccccccccccb..........
.........bfffffffffGfggggggggggsssfffffffffffffffffffffffffb..........
.........bfffffffDfddddddffsfffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggssffffffffffffffffffffffffffb..........
.........bfffEfeeeeffsfffffffffffffffffffffffffffffffffffffb..........
.........bfffffLfllllffsfffffffffffffffffffffffffffffffffffb..........
.........bfffffffDfddddddddddddddffsfffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggggggssfffffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `L` [ReferencesUsageTypeCall] · `l` [ReferencesUsageTypeCallLabel]

**Proposed K1 — value usages**: `100x30`, Normal, `report/calls.go` (extended gomod fixture), gopls attached, `gr` on `Calls` (line 4); default grouping; classification finished; type groups in alphabetical order.

```text
▎ calls.go                                                                                          
  ╭ Usages of Calls · 4 ─────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  1                        │ report/calls.go:8                                 │  
  │   ▾ ✎ Value write  1                     │   1  package report                               │  
  │     ▾ □ report  1                        │   2                                               │  
  │         ◆ calls.go:8                     │   3  // Calls counts rendered summaries.          │  
  │ ▾ ▲ Test  3                              │   4  var Calls int                                │  
  │   ▾ ◎ Value read  2                      │   5                                               │  
  │     ▾ □ report  2                        │   6  // Count records one rendered summary.       │  
  │         ◆ calls_test.go:8                │   7  func Count() {                               │  
  │         ◆ calls_test.go:9                │   8      Calls++                                  │  
  │   ▾ ✎ Value write  1                     │   9  }                                            │  
  │     ▾ □ report  1                        │                                                   │  
  │         ◆ calls_test.go:6                │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                         Tests: grouped t · ● Folders f · ● Usage type u · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssfffffffffffffffffffffffffffffffffb..
..bfffffWfwwwwwwwwwwwffsfffffffffffffffffffffbfsssffkkkkkkkffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bcccccccccGcggggggggcccccccccccccccccccccccbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffkkkfffffffTTTffffffffffffffffffffffffffffffffb..
..bfffffYfyyyyyyyyyyffsffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffb..
..bfffffffffGfgggggggggggggssffffffffffffffffbfsssffkkkkfFFFFFfffffffffffffffffffffffffffffffffffb..
..bfffffffffGfgggggggggggggssffffffffffffffffbfrrrffffffhhhhhffffffffffffffffffffffffffffffffffffb..
..bfffffWfwwwwwwwwwwwffsfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffffGfgggggggggggggssffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `Y` [ReferencesUsageTypeRead] · `y` [ReferencesUsageTypeReadLabel] · `W` [ReferencesUsageTypeWrite] · `w` [ReferencesUsageTypeWriteLabel]

**Proposed K2 — usage type off**: `100x30`, as K1 after `u`; each usage row keeps a right-aligned tag with its type's icon and short name.

```text
▎ calls.go                                                                                          
  ╭ Usages of Calls · 4 ─────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  1                        │ report/calls.go:8                                 │  
  │   ▾ □ report  1                          │   1  package report                               │  
  │       ◆ calls.go:8               ✎ write │   2                                               │  
  │ ▾ ▲ Test  3                              │   3  // Calls counts rendered summaries.          │  
  │   ▾ □ report  3                          │   4  var Calls int                                │  
  │       ◆ calls_test.go:6          ✎ write │   5                                               │  
  │       ◆ calls_test.go:8           ◎ read │   6  // Count records one rendered summary.       │  
  │       ◆ calls_test.go:9           ◎ read │   7  func Count() {                               │  
  │                                          │   8      Calls++                                  │  
  │                                          │   9  }                                            │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                         Tests: grouped t · ● Folders f · ○ Usage type u · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssfffffffffffffffffffffffffffffffffb..
..bfffffDfddddddffsffffffffffffffffffffffffffbfsssffkkkkkkkffffffffffffffffffffffffffffffffffffffb..
..bcccccccGcggggggggcccccccccccccccccWfwwwwwcbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffb..
..bfffffDfddddddffsffffffffffffffffffffffffffbfsssffkkkfffffffTTTffffffffffffffffffffffffffffffffb..
..bfffffffGfgggggggggggggssffffffffffWfwwwwwfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfgggggggggggggssfffffffffffYfyyyyfbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffb..
..bfffffffGfgggggggggggggssfffffffffffYfyyyyfbfsssffkkkkfFFFFFfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffhhhhhffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `Y` [ReferencesUsageTypeRead] · `y` [ReferencesUsageTypeReadLabel] · `W` [ReferencesUsageTypeWrite] · `w` [ReferencesUsageTypeWriteLabel]

**Proposed T1 — usage types of a struct**: `100x30`, Normal, `billing/invoice.go` (extended gomod fixture), gopls attached, `gr` on `Invoice` (line 6); default grouping; classification finished; first usage selected.

```text
▎ batch.go                                                                                          
  ╭ Usages of Invoice · 9 ───────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  8                        │ billing/batch.go:5                                │  
  │   ▾ ≡ Field declaration  2               │   1  package billing                              │  
  │     ▾ □ billing  2                       │   2                                               │  
  │         ◆ batch.go:5                     │   3  // Batch groups the invoices of one customer.│  
  │         ◆ batch.go:6                     │   4  type Batch struct {                          │  
  │   ▾ ∷ Parameter declaration  1           │   5      Current Invoice                          │  
  │     ▾ □ billing  1                       │   6      Past    []*Invoice                       │  
  │         ◆ batch.go:15                    │   7  }                                            │  
  │   ▾ ⊙ Receiver  2                        │   8                                               │  
  │     ▾ □ billing  2                       │   9  // NewInvoice starts an invoice with one lin…│  
  │         ◆ invoice.go:11                  │  10  func NewInvoice(cents int) *Invoice {        │  
  │         ◆ invoice.go:20                  │  11      return &Invoice{Lines: []int{cents}}     │  
  │   ▾ ↵ Return type  2                     │  12  }                                            │  
  │     ▾ □ billing  2                       │  13                                               │  
  │         ◆ batch.go:10                    │  14  // Merge appends extra lines to inv.         │  
  │         ◆ batch.go:15                    │  15  func Merge(inv Invoice, extra []int) Invoice…│  
  │   ▾ ⊞ Struct initialization  1           │  16      inv.Lines = append(inv.Lines, extra...)  │  
  │     ▾ □ billing  1                       │  17      return inv                               │  
  │         ◆ batch.go:11                    │  18  }                                            │  
  │ ▾ ▲ Test  1                              │                                                   │  
  │   ▾ ⊞ Struct initialization  1           │                                                   │  
  │     ▾ □ billing  1                       │                                                   │  
  │         ◆ invoice_test.go:6              │                                                   │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                         Tests: grouped t · ● Folders f · ● Usage type u · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..btttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfssssssssssssssssssffffffffffffffffffffffffffffffffb..
..bfffffIfiiiiiiiiiiiiiiiiiffsfffffffffffffffbfsssffkkkkkkkffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bcccccccccGcggggggggcccccccccccccccccccccccbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfffffffffGfggggggggssfffffffffffffffffffffbfsssffkkkkfffffffkkkkkkffffffffffffffffffffffffffffb..
..bfffffJfjjjjjjjjjjjjjjjjjjjjjffsfffffffffffbfrrrffffffffffffffhhhhhhhffffffffffffffffffffffffffb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfsssfffffffffffffffffhhhhhhhfffffffffffffffffffffffb..
..bfffffffffGfggggggggsssffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffVfvvvvvvvvffsffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfffffffffGfggggggggggsssffffffffffffffffffbfsssffkkkkfFFFhhhhhhhfffffffTTTfffhhhhhhhffffffffffb..
..bfffffffffGfggggggggggsssffffffffffffffffffbfsssffffffkkkkkkffhhhhhhhffffffffffTTTfffffffffffffb..
..bfffffUfuuuuuuuuuuuffsfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffffGfggggggggsssffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bfffffffffGfggggggggsssffffffffffffffffffffbfsssffkkkkfFFFFFfffffhhhhhhhffffffffffTTTffhhhhhhhfb..
..bfffffZfzzzzzzzzzzzzzzzzzzzzzffsfffffffffffbfsssffffffffffffffffffFFFFFFfffffffffffffffffffffffb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bfffffffffGfggggggggsssffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffZfzzzzzzzzzzzzzzzzzzzzzffsfffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfdddddddffsfffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffffGfgggggggggggggggssffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `I` [ReferencesUsageTypeFieldDeclaration] · `i` [ReferencesUsageTypeFieldDeclarationLabel] · `J` [ReferencesUsageTypeParameterDeclaration] · `j` [ReferencesUsageTypeParameterDeclarationLabel] · `V` [ReferencesUsageTypeReceiver] · `v` [ReferencesUsageTypeReceiverLabel] · `U` [ReferencesUsageTypeReturnType] · `u` [ReferencesUsageTypeReturnTypeLabel] · `Z` [ReferencesUsageTypeStructInitialization] · `z` [ReferencesUsageTypeStructInitializationLabel]

**Proposed T2 — struct, usage type off**: `100x30`, as T1 after `u`; rows sorted by path and line, each with its type tag.

```text
▎ batch.go                                                                                          
  ╭ Usages of Invoice · 9 ───────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  8                        │ billing/batch.go:5                                │  
  │   ▾ □ billing  8                         │   1  package billing                              │  
  │       ◆ batch.go:5               ≡ field │   2                                               │  
  │       ◆ batch.go:6               ≡ field │   3  // Batch groups the invoices of one customer.│  
  │       ◆ batch.go:10             ↵ return │   4  type Batch struct {                          │  
  │       ◆ batch.go:11               ⊞ init │   5      Current Invoice                          │  
  │       ◆ batch.go:15              ∷ param │   6      Past    []*Invoice                       │  
  │       ◆ batch.go:15             ↵ return │   7  }                                            │  
  │       ◆ invoice.go:11         ⊙ receiver │   8                                               │  
  │       ◆ invoice.go:20         ⊙ receiver │   9  // NewInvoice starts an invoice with one lin…│  
  │ ▾ ▲ Test  1                              │  10  func NewInvoice(cents int) *Invoice {        │  
  │   ▾ □ billing  1                         │  11      return &Invoice{Lines: []int{cents}}     │  
  │       ◆ invoice_test.go:6         ⊞ init │  12  }                                            │  
  │                                          │  13                                               │  
  │                                          │  14  // Merge appends extra lines to inv.         │  
  │                                          │  15  func Merge(inv Invoice, extra []int) Invoice…│  
  │                                          │  16      inv.Lines = append(inv.Lines, extra...)  │  
  │                                          │  17      return inv                               │  
  │                                          │  18  }                                            │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                         Tests: grouped t · ● Folders f · ○ Usage type u · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..btttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfssssssssssssssssssffffffffffffffffffffffffffffffffb..
..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffkkkkkkkffffffffffffffffffffffffffffffffffffffb..
..bcccccccGcggggggggcccccccccccccccccIfiiiiicbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfggggggggssfffffffffffffffIfiiiiifbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfffffffGfggggggggsssfffffffffffffUfuuuuuufbfsssffkkkkfffffffkkkkkkffffffffffffffffffffffffffffb..
..bfffffffGfggggggggsssfffffffffffffffZfzzzzfbfrrrffffffffffffffhhhhhhhffffffffffffffffffffffffffb..
..bfffffffGfggggggggsssffffffffffffffJfjjjjjfbfsssfffffffffffffffffhhhhhhhfffffffffffffffffffffffb..
..bfffffffGfggggggggsssfffffffffffffUfuuuuuufbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfggggggggggsssfffffffffVfvvvvvvvvfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfggggggggggsssfffffffffVfvvvvvvvvfbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffkkkkfFFFhhhhhhhfffffffTTTfffhhhhhhhffffffffffb..
..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffffffkkkkkkffhhhhhhhffffffffffTTTfffffffffffffb..
..bfffffffGfgggggggggggggggssfffffffffZfzzzzfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfFFFFFfffffhhhhhhhffffffffffTTTffhhhhhhhfb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFfffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `I` [ReferencesUsageTypeFieldDeclaration] · `i` [ReferencesUsageTypeFieldDeclarationLabel] · `J` [ReferencesUsageTypeParameterDeclaration] · `j` [ReferencesUsageTypeParameterDeclarationLabel] · `V` [ReferencesUsageTypeReceiver] · `v` [ReferencesUsageTypeReceiverLabel] · `U` [ReferencesUsageTypeReturnType] · `u` [ReferencesUsageTypeReturnTypeLabel] · `Z` [ReferencesUsageTypeStructInitialization] · `z` [ReferencesUsageTypeStructInitializationLabel]
