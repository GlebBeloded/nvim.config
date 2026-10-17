## Context

See proposal.md (Why, Evidence). The catalogue, the `usages` query convention, the classification order and the target-kind rules come from `fix-references-usage-types` (its design.md, Decisions 1–3 and Catalogue). `languages-registry` adds the `references` facet this change flips. Research (2026-10-17):

- **JetBrains' Rust taxonomy.** intellij-rust's `RsUsageTypeProvider` first maps a reference inside a macro call to its expansion. It then walks up the nested `RsPath` and decides by the parent PSI class:
  - `RsPathType` → "impl" under an `RsImplItem`, otherwise "type reference".
  - `RsPathExpr`, after walking up nested path expressions → "dot expr", "function call", "argument", "macro argument" or "expr".
  - `RsUseSpeck` → "use", `RsStructLiteral` → "init struct", `RsStructLiteralField` → "init field", `RsTraitRef` → "trait reference", `RsMethodCall` → "method call", `RsMetaItem` → "meta item", `RsFieldLookup` → "field", `RsMacroCall` → "macro call", `RsPatBinding` → "variable binding", and a path under `RsModDeclItem` → "mod".
  - The labels are lowercase literals, not bundle strings, so they show up as written.
- **Why richer.** "type reference" covers every type position: a field type, a parameter, a return type, a `let` annotation, a generic argument, an alias or a cast. GoLand splits these, and the user asked for GoLand's observability. So the Rust query uses the position-specific catalogue ids. Bounds get Type constraint, patterns get Pattern, and generic arguments get Type instantiation.
- **rust-analyzer facts** (0.3.2819, checked with `drafts/lsp_check/rs.lua` and `drafts/lsp_check/rustproj.lua`):
  - A reference range starts on the last path segment: `crate::money::Money` starts at `Money`. `Money::from_cents` has one reference to `Money` (at `Money`) and one to `from_cents`.
  - `textDocument/references` carries no kind. `textDocument/documentHighlight` returns kind 3 (write) for `c.hits += 1` and `c.hits = 2`, kind 2 (read) for `c.hits` and for the shorthand field in `Money { cents }`, and no kind for type usages.
  - `Self` inside an `impl` is listed as a usage of the struct.
  - The quirk in Risks: references omit the non-macro usages of a symbol that a macro call in the same file also uses.
- **Parser:** `rust` is installed (listed in `lua/gleb/treesitter.lua`, and in the rust language's `treesitter` facet once `languages-registry` lands). nvim-treesitter injects `rust` into macro token trees. The query runs on the top-level tree, where a token tree is a flat run of identifiers (template Decision 1).

## Goals / Non-Goals

**Goals:**
- Every Rust usage position rust-analyzer returns gets a GoLand-worded catalogue type where the syntax decides it.
- Only a query file, a facet flag, cases and fixture files. The classifier stays language-agnostic.

**Non-Goals:**
- Classifying inside macro expansions.
- New catalogue ids (proposal.md, Out of scope).
- Changing what rust-analyzer returns.

## Decisions

1. **Query file.** `queries/rust/usages.scm` is `drafts/queries/rust/usages.scm` as it stands: its captures already use catalogue ids, and the verifier passes 187/187 cases. The implementation may restructure it, but every case must still pass.

   | Draft id (before rename) | Catalogue id | Label | Rust positions | intellij-rust |
   |---|---|---|---|---|
   | `import` | `import` | Import | every segment of a `use` tree, `as` aliases | use |
   | `macro` | `macro` | Macro call | `m!()`, `a::m!()` (every path segment) | macro call |
   | `macro_argument` | `macro_argument` | Macro argument | any identifier in a macro call's token tree | macro argument (or the expansion's type) |
   | `trait_bound` | `type_constraint` | Type constraint | `T: Tr`, `where`, `impl Tr`, `dyn Tr`, `?Sized`, supertraits, `Fn(A) -> B` sugar, `for<'a>` bounds | trait reference |
   | `struct_initialization` | `struct_initialization` | Struct initialization | `T { .. }`, `a::T { .. }`, `E::V { .. }`, `T::<U> { .. }` | init struct |
   | `field_initialization` | `field_initialization` | Field initialization | `T { a: 1 }`, shorthand `T { a }` | init field |
   | `pattern` | `pattern` | Pattern | `T::V(x)`, `a::T { f, .. }`, `a::E::Unit`, field names in struct patterns, `let`/`if let` patterns | variable binding |
   | `method_call` | `call` | Call | `x.m()`, `x.m::<T>()` | method call |
   | `call` | `call` | Call | `f()`, `a::f()`, `T::new()` and its qualifiers, `Vec::<T>::new()`, `f::<T>()`, tuple-struct and variant constructors | function call |
   | (new) | `write` | Value write | the field of `x.f = v` and `x.f += v` | (platform read/write) |
   | `dot` | `field_access` | Field access | every other `x.f` | field |
   | `field_declaration` | `field_declaration` | Field declaration | anything in a struct or variant field type | type reference |
   | `parameter_declaration` | `parameter_declaration` | Parameter declaration | anything in a fn, closure or trait fn parameter type | type reference |
   | `return_type` | `return_type` | Return type | `-> T` of fns, trait fn signatures and closures | type reference |
   | `variable_declaration` | `variable_declaration` | Variable declaration | the type of `let x: T`, `const C: T`, `static S: T` | type reference |
   | `type_alias` | `type_alias` | Type alias | the right side of `type A = T;` | type reference |
   | `cast` | `cast` | Type cast | `x as T` | type reference |
   | `impl` | `impl` | Impl | the self type head of `impl T` and `impl Tr for T` | impl |
   | `trait_impl` | `extends` | Supertype | the trait of `impl Tr for T` | trait reference |
   | `type_argument` | `type_instantiation` | Type instantiation | generic arguments, `Fn` sugar arguments, associated type bindings not matched above | type reference |

   - Pattern order decides overlaps (the lowest index wins; `drafts/overlaps.lua` lists every shadowed capture):
     - Bounds come before the declaration types, so `Box<dyn Shape>` in a field is Type constraint at `Shape` but Field declaration at `Box`.
     - Method calls come before `write` and `field_access`, so `x.m()` is Call.
     - The declaration types come before `type_instantiation`, so `Vec<Thing>` in a parameter is Parameter declaration at both names.
   - The `write` capture is the one change from the verified draft. The draft gave `local.size = 3` Field access, so a field write never reached Value write. Now the classifier's step 1 skips the `write` capture, step 2 takes rust-analyzer's documentHighlight write, and step 3 falls back to the capture.
2. **Grammar gotchas** (tree-sitter-rust as installed):
   - Path qualifiers are `identifier` nodes inside `scoped_identifier` or `scoped_type_identifier` paths. Each pattern spells out up to four segments, because predicates can't walk an arbitrary path.
   - A type name is a `type_identifier`, but a qualifier inside a type path is an `identifier`. The field and parameter patterns accept an `identifier` only under a `scoped_type_identifier`, so a local of the same name in a default or a pattern never matches. The return, variable, alias and cast patterns only look inside the type node.
   - `Self` in a type position is a `type_identifier` and is classified like the struct's name: `-> Self` is Return type, `Self { .. }` is Struct initialization, `Self::new()` is Call.
   - Lifetimes are excluded with `#not-has-parent? lifetime`, so `&'a str` gives `str` its type and `a` none.
   - Token trees are flat, so `local.name` inside `println!` is two Macro arguments. `format!("{x}")` puts `x` inside `string_content`, where no identifier node starts, so it gets no syntactic type.
   - `field_pattern` uses `shorthand_field_identifier` for `T { a, .. }` and `field_identifier` for `T { a: p }`. Both are Pattern.
3. **Server ranges and the query.** A candidate must start exactly at the reference start (template Decision 1). rust-analyzer starts at the identifier itself, never at a qualifier or a sigil, so every capture is on a single identifier node. Patterns capture qualifiers too, because a qualifier is itself a reference to its module, type or enum. For example, `Money` in `Money::from_cents` is a usage of `Money`.
4. **Target kind** (template Decision 3) with Rust targets:
   - A struct, enum, union or trait is a `type` target, so it never gets write/read. `Money::from_cents(..)` stays Call: the `type_conversion` rewrite is the Go rule only, and a Rust path call is never a conversion.
   - A field is a `field` target. Its Field initialization, Pattern, Field access and Macro argument usages are not type-position ids, so they are kept. Assignment targets get Value write from documentHighlight.
   - A function or method is a `function` target. Calls and Macro arguments are kept.
   - A module is SymbolKind Module, an `unknown` target, so its qualifier positions keep the whole path's type. For example, `model` in `model::Thing` inside a field type is Field declaration.
   - A `let` binding or a `const` is a `variable` target. A constant used as a pattern stays Pattern; its other positions match no type pattern and get documentHighlight's write/read.
5. **Registry.** `lua/gleb/languages/rust/init.lua` sets `references.usage_types = true`; the query parser language is the `rust` filetype's own (`languages-registry` Decision 6). The contract then requires `queries/rust/usages.scm` and `tests/unit/references/usage_cases/rust.lua`, and both exist. The facet's fixture symbol stays `total`, because the registry's language suite runs `gr` on it.
6. **Case table.** `tests/unit/references/usage_cases/rust.lua` is `drafts/expected.lua`: the same `{ line, needle, id | false, nth = …, kind = … }` entries in catalogue ids. Its source `tests/unit/references/usage_cases/rust/usages.rs` is `drafts/fixtures/usages.rs` verbatim (71 lines). `Thing::default()` carries `kind = "type"` and stays `call`, which pins the Go-only conversion rule. The draft fixture's last function, `writes`, pins the field write (`hits` in `c.hits += 1` is `write`, `c.hits` is `field_access`).
7. **Fixture** (`tests/fixtures/build.sh`, `rustproj`).
   - `src/lib.rs` gains `pub mod money;` and `pub mod ledger;` after `pub mod price;`, as lines 2 and 3. A module must be declared in the crate root for `src/ledger.rs` and the integration test to reach `Money`. No test or manifest entry reads `src/lib.rs`, and `price.rs`, `main.rs` and `tests/price.rs` are unchanged, so every `total` location holds.
   - New files, written before `cargo check --all-targets`:

     `src/money.rs`:
     ```rust
     /// An amount in cents.
     pub struct Money {
         pub cents: i64,
     }

     impl Money {
         pub fn from_cents(cents: i64) -> Money {
             Money { cents }
         }
     }
     ```

     `src/ledger.rs`:
     ```rust
     use crate::money::Money;

     /// Adds up the entries of one account.
     pub fn balance(entries: &[i64]) -> Money {
         Money::from_cents(entries.iter().sum())
     }

     /// Returns true when the amount is zero.
     pub fn is_free(amount: &Money) -> bool {
         match amount {
             Money { cents: 0 } => true,
             _ => false,
         }
     }
     ```

     `tests/money.rs`:
     ```rust
     use rustproj::money::Money;

     #[test]
     fn starts_from_cents() {
         let amount = Money::from_cents(250);
         assert_eq!(amount.cents, 250);
     }
     ```

   - The manifest gains `"Money"` from `identifier_locations Money src/money.rs src/ledger.rs tests/money.rs`. It lists 11 locations: the declaration `src/money.rs:2:12`, then `6`, `7`, `8`, `src/ledger.rs:1`, `4`, `5`, `9`, `11` and `tests/money.rs:1`, `5`. The doc comment avoids the word `Money`, so the grep lists only code.
   - No usage of `Money` is inside a macro call, and `cents` appears in a macro only in `tests/money.rs`, where it has no other usage. So the fixture doesn't depend on the macro quirk.
   - Verified with rust-analyzer 0.3.2819 and the `rust` parser (`drafts/lsp_check/rustproj.lua` on a copy built by the patched `build.sh`), twice with identical results:

     | Symbol | Usage | Query capture |
     |---|---|---|
     | `Money` | `src/ledger.rs:1:19`, `tests/money.rs:1:22` | `import` |
     | `Money` | `src/ledger.rs:4:36`, `src/money.rs:7:38` | `return_type` |
     | `Money` | `src/ledger.rs:5:5`, `tests/money.rs:5:18` | `call` |
     | `Money` | `src/ledger.rs:9:25` | `parameter_declaration` |
     | `Money` | `src/ledger.rs:11:9` | `pattern` |
     | `Money` | `src/money.rs:6:6` | `impl` |
     | `Money` | `src/money.rs:8:9` | `struct_initialization` |
     | `cents` | `src/ledger.rs:11:17` | `pattern` |
     | `cents` | `src/money.rs:8:17` | `field_initialization` |
     | `cents` | `tests/money.rs:6:23` | `macro_argument` |

8. **Existing language suite.** With the query, the three `total` calls inside `println!`/`assert_eq!` are Macro arguments. So the Rust case of `tests/integration/references/test_languages.lua` (parser installed) expects these rows:
   - `scope:Production`, `type:Macro argument`, `folder:src` and the `main.rs` usage;
   - `scope:Test`, `type:Macro argument`, `folder:src` with the inline usage, then `folder:tests` with the integration usage.

   The rows without a parser are unchanged.

## Risks / Trade-offs

- **rust-analyzer's macro quirk.** When a file uses a symbol inside a macro call, references sometimes list only the declaration plus the macro usages. In `drafts/lsp_check/rs/fixture`, `Thing` had 2 references with `vec![Thing::new()]` and 12 without it. documentHighlight has the opposite gap. This change doesn't fix it; a follow-up for the references request could merge documentHighlight results per file. The fixture avoids it (Decision 7).
- **Macro arguments hide the real role.** `price::total(10, 2)` inside `println!` is a Call in intellij-rust, through the expansion, but a Macro argument here. Classifying the injected tree would fix it, but the template ignores injections on purpose.
- **Path depth.** Paths with more than four segments, and type wrappers nested deeper than 8 levels (4 for casts), fall back to the next matching pattern or to none. The case table pins the depths the query supports.
- **Grammar updates can rename nodes.** The query then fails to compile and Rust falls back to server kinds (template Risks). The contract test and the case table fail loudly.

## Renders

Stand-ins: `λ` call, `⊤` impl, `⇣` import, `∷` parameter declaration, `◌` pattern, `↵` return type, `⊞` struct initialization, and `◆` for the Rust devicon. The other stand-ins are as in `fix-references-usage-types`. The real-glyph, real-colour versions are in `renders/current_rust_struct.ansi` and `renders/type_r1_rust_struct.ansi` (`command cat` in a Nerd Font terminal). Icons and colours follow the template catalogue: Impl `cod-type_hierarchy` U+EBB9 orange, Import `cod-package` U+EB29 green, Pattern `md-shape_outline` U+F0832 orange. The Rust file icon is devicons' U+E68B `#dea584` ([DevIconRs]).

**Current — Rust struct usages**: `70x36`, Normal, `src/money.rs` (extended rustproj fixture), rust-analyzer attached, `gr` on `Money` (line 2); default grouping; classification finished. No preview below 80 columns. Every usage is a plain row: no usage type level, no hint entry.

```text
▎ money.rs                                                            
   1 /// An amount in cents.                                          
   2 pub struct Money {                                               
   3     pub cents: i64,                                              
   4 }                                                                
   5                                                                  
   6 impl Money {                                                     
   7     pub fn from_cents(cents: i64) -> Money {                     
   8         Money { cents }                                          
   9     }        ╭ Usages of Money · 10 ──────────╮                  
  10 }            │ ▾ ▣ Production  8              │                  
  11              │   ▾ □ src  8                   │                  
  12              │       ◆ ledger.rs:1            │                  
  13              │       ◆ ledger.rs:4            │                  
  14              │       ◆ ledger.rs:5            │                  
  15              │       ◆ ledger.rs:9            │                  
  16              │       ◆ ledger.rs:11           │                  
  17              │       ◆ money.rs:6             │                  
  18              │       ◆ money.rs:7             │                  
  19              │       ◆ money.rs:8             │                  
  20              │ ▾ ▲ Test  2                    │                  
  21              │   ▾ □ tests  2                 │                  
  22              │       ◆ money.rs:1             │                  
  23              │       ◆ money.rs:5             │                  
  24              ├────────────────────────────────┤                  
  25              │ Tests: grouped t · ● Folders f │                  
  26              ╰────────────────────────────────╯                  
  27                                                                  
  28                                                                  
  29                                                                  
  30                                                                  
  31                                                                  
  32                                                                  
  33                                                                  
  34                                                                  
 NORMAL  ⎇ main                                                  rust 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
..................bttttttttttttttttttttttbbbbbbbbbbb..................
..................bfffPfppppppppppffsffffffffffffffb..................
..................bfffffDfdddffsfffffffffffffffffffb..................
..................bcccccccGcgggggggggccccccccccccccb..................
..................bfffffffGfgggggggggssffffffffffffb..................
..................bfffffffGfgggggggggssffffffffffffb..................
..................bfffffffGfgggggggggssffffffffffffb..................
..................bfffffffGfgggggggggsssfffffffffffb..................
..................bfffffffGfggggggggssfffffffffffffb..................
..................bfffffffGfggggggggssfffffffffffffb..................
..................bfffffffGfggggggggssfffffffffffffb..................
..................bfffEfeeeeffsffffffffffffffffffffb..................
..................bfffffDfdddddffsfffffffffffffffffb..................
..................bfffffffGfggggggggssfffffffffffffb..................
..................bfffffffGfggggggggssfffffffffffffb..................
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
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconRs] · `g` [ReferencesFileLabelDevIconRs]

**Proposed R1 — usage types of a Rust struct**: `70x36`, Normal, `src/money.rs` (extended rustproj fixture), rust-analyzer attached, `gr` on `Money` (line 2); default grouping; classification finished; first usage selected. No preview below 80 columns: the window shrinks to its content and stays centred.

```text
▎ money.rs                                                            
   1 /// ╭ Usages of Money · 10 ───────────────────────────╮          
   2 pub │ ▾ ▣ Production  8                               │          
   3     │   ▾ λ Call  1                                   │          
   4 }   │     ▾ □ src  1                                  │          
   5     │         ◆ ledger.rs:5                           │          
   6 impl│   ▾ ⊤ Impl  1                                   │          
   7     │     ▾ □ src  1                                  │          
   8     │         ◆ money.rs:6                            │          
   9     │   ▾ ⇣ Import  1                                 │          
  10 }   │     ▾ □ src  1                                  │          
  11     │         ◆ ledger.rs:1                           │          
  12     │   ▾ ∷ Parameter declaration  1                  │          
  13     │     ▾ □ src  1                                  │          
  14     │         ◆ ledger.rs:9                           │          
  15     │   ▾ ◌ Pattern  1                                │          
  16     │     ▾ □ src  1                                  │          
  17     │         ◆ ledger.rs:11                          │          
  18     │   ▾ ↵ Return type  2                            │          
  19     │     ▾ □ src  2                                  │          
  20     │         ◆ ledger.rs:4                           │          
  21     │         ◆ money.rs:7                            │          
  22     │   ▾ ⊞ Struct initialization  1                  │          
  23     │     ▾ □ src  1                                  │          
  24     │         ◆ money.rs:8                            │          
  25     │ ▾ ▲ Test  2                                     │          
  26     │   ▾ λ Call  1                                   │          
  27     │     ▾ □ tests  1                                │          
  28     │         ◆ money.rs:5                            │          
  29     │   ▾ ⇣ Import  1                                 │          
  30     │     ▾ □ tests  1                                │          
  31     │         ◆ money.rs:1                            │          
  32     ├─────────────────────────────────────────────────┤          
  33     │ Tests: grouped t · ● Folders f · ● Usage type u │          
  34     ╰─────────────────────────────────────────────────╯          
 NORMAL  ⎇ main                                                  rust 
```

```text
......................................................................
.........bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffLfllllffsfffffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bcccccccccGcgggggggggcccccccccccccccccccccccccccccb..........
.........bfffffAfaaaaffsfffffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggssffffffffffffffffffffffffffffb..........
.........bfffffIfiiiiiiffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........
.........bfffffJfjjjjjjjjjjjjjjjjjjjjjffsffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........
.........bfffffVfvvvvvvvffsffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........
.........bfffffUfuuuuuuuuuuuffsffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggssffffffffffffffffffffffffffffb..........
.........bfffffZfzzzzzzzzzzzzzzzzzzzzzffsffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggssffffffffffffffffffffffffffffb..........
.........bfffEfeeeeffsfffffffffffffffffffffffffffffffffffffb..........
.........bfffffLfllllffsfffffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddddffsffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggssffffffffffffffffffffffffffffb..........
.........bfffffIfiiiiiiffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddddffsffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggssffffffffffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconRs] · `g` [ReferencesFileLabelDevIconRs] · `L` [ReferencesUsageTypeCall] · `l` [ReferencesUsageTypeCallLabel] · `A` [ReferencesUsageTypeImpl] · `a` [ReferencesUsageTypeImplLabel] · `I` [ReferencesUsageTypeImport] · `i` [ReferencesUsageTypeImportLabel] · `J` [ReferencesUsageTypeParameterDeclaration] · `j` [ReferencesUsageTypeParameterDeclarationLabel] · `V` [ReferencesUsageTypePattern] · `v` [ReferencesUsageTypePatternLabel] · `U` [ReferencesUsageTypeReturnType] · `u` [ReferencesUsageTypeReturnTypeLabel] · `Z` [ReferencesUsageTypeStructInitialization] · `z` [ReferencesUsageTypeStructInitializationLabel]

Below 80 columns there is no preview, so neither render needs preview highlighting. R1 is picked because it shows the full tree and every Rust-specific group the fixture yields at once. The rows are the verified classification in Decision 7.
