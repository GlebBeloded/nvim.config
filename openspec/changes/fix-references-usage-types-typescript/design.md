## Context

See proposal.md (Why, Evidence). The template change `fix-references-usage-types` defines:
- the usage type catalogue;
- the `queries/<lang>/usages.scm` conventions;
- the classification order, where tsserver's `isWriteAccess` is step 2;
- the target-kind rules.

`languages-registry` adds the `js` language, whose `references` facet this change enables.

Research (2026-10-17):

- **JetBrains' taxonomy** (`JSUsageTypeProvider`, decompiled from the local GoLand install). It is shared by WebStorm and every IDE with the JavaScript plugin. It checks the reference's PSI parents:

  | JetBrains type | Context |
  |---|---|
  | Usage in import | ES6 import specifier, default import, namespace import |
  | Usage in function call | callee of a call |
  | New instance creation | `new T()` |
  | Usage in extends/implements clause | class and interface heritage |
  | Usage in cast target type | `x as T` |
  | Usage in instanceof | `x instanceof T`, type guard `x is T` |
  | Class static member access | qualifier of `T.member` when `T` resolves to a class |
  | Method parameter declaration / Catch clause parameter declaration | parameter type annotation |
  | Method return type | return type annotation |
  | Field declaration / Local variable declaration | field or variable type annotation |
  | Usage in string constants | a string literal reference |

  Read and write come from `JSReadWriteAccessDetector`. Everything else is "Unclassified".
- **Why we go richer:**
  - JetBrains has no type for a generic argument (`Array<Money>`), a type alias (`type A = T`), `satisfies` or the angle cast `<T>x`. The catalogue already has GoLand's "Type instantiation" and "Type alias", and the cast and check ideas.
  - Field and Variable declaration stay separate, as in GoLand.
  - "Usage in string constants" is out of reach: servers don't return string locations.
- **Parsers:** `javascript`, `typescript` and `tsx` are installed and share most node names. They differ in the following:
  - JavaScript has no type nodes, and its `class_heritage` holds the superclass directly.
  - tsx has no `type_assertion` (`<T>x`), because `<` starts JSX.

## Goals / Non-Goals

**Goals:**
- Every JetBrains JS/TS type that a server's reference can land on, plus Type instantiation and Type alias.
- One query set for the three parsers, without duplicated patterns.
- The `js` language passes the registry contract with `usage_types = true`.

**Non-Goals:**
- String, comment and JSX tag usages.
- Decorators.
- Changes to the catalogue, tree, toggle or icons.

## Decisions

1. **Capture ids.** The draft's ids are renamed to catalogue ids when they are ported. Each draft id maps to exactly one catalogue id:

   | Draft id | Catalogue id | Label | Where it is captured (query file) |
   |---|---|---|---|
   | `import` | `import` | Import | import specifier name and alias, default import, namespace import, `export { T } from "m"` (ecma) |
   | `call` | `call` | Call | callee identifier, `obj.f()`, `obj?.f()`, `obj.#f()` (ecma) |
   | `new` | `new` | New instance creation | `new T()`, `new ns.T()` (ecma) |
   | `extends` | `extends` | Supertype | JS `class_heritage` (javascript); TS `extends_clause`, interface `extends_type_clause`, `implements_clause` (typescript) |
   | `cast` | `cast` | Type cast | `as_expression`, `satisfies_expression` (typescript); `type_assertion` `<T>x` (ts_angle_cast) |
   | `instanceof` | `instanceof` | Type check | `instanceof` right side (ecma); `type_predicate` `x is T` (typescript) |
   | `static_member` | `static_member` | Static member access | PascalCase object of a `member_expression` (ecma), kept only for a `type` target |
   | `field_declaration` | `field_declaration` | Field declaration | `public_field_definition` and `property_signature` annotations (typescript) |
   | `local_declaration` | `variable_declaration` | Variable declaration | `variable_declarator` annotation (typescript) |
   | `parameter_declaration` | `parameter_declaration` | Parameter declaration | `required_parameter` and `optional_parameter` annotations, including parameters of function types (typescript) |
   | `catch_declaration` | `catch` | Catch clause | `catch_clause` annotation (typescript) |
   | `return_type` | `return_type` | Return type | any `return_type:` annotation, and the bare `function_type` return (typescript) |
   | `type_argument` | `type_instantiation` | Type instantiation | `type_arguments` and generic `constraint` (typescript) |
   | `type_alias` (new) | `type_alias` | Type alias | `type_alias_declaration value:` (typescript) |

   - `type_alias` was added to the draft in this change: a section in `drafts/gen_ts.py`, plus line 47 of `drafts/fixtures/usages.ts` turned from a negative into a case.
   - Type positions match a `type_identifier` directly at the context, or nested in up to 4 pure wrappers: `array_type`, `generic_type`, `union_type`, `intersection_type`, `parenthesized_type`, `nested_type_identifier`, `readonly_type`, `tuple_type`, `optional_type` and `rest_type`.
   - Matching never crosses a function or object type, whose own parameters and properties have their own patterns.
   - `drafts/gen_ts.py` generates `queries/typescript/usages.scm`. The implementation may keep the generator or hand-maintain the file, but every case must pass.
   - No catalogue id is missing: every JetBrains type above maps to an existing id.
2. **Query files and grammar gotchas.**
   - Files and their inheritance:
     - `queries/ecma/usages.scm`: shared patterns only.
     - `queries/javascript/usages.scm`: `; inherits: ecma`.
     - `queries/typescript/usages.scm`: `; inherits: ecma,(ts_angle_cast)`.
     - `queries/tsx/usages.scm`: `; inherits: typescript`.
     - `queries/ts_angle_cast/usages.scm`: the `<T>x` pattern.
   - The parentheses make `ts_angle_cast` an optional base. Neovim skips optional bases of a file that is itself inherited, so tsx never loads `type_assertion`, which its grammar lacks.
   - `ecma` and `ts_angle_cast` are pseudo-languages with no parser of their own, as `ecma` is in nvim-treesitter's queries. The catalogue test ("Every query capture is in the catalogue") checks them through the files that inherit them: javascript, typescript and tsx.
   - Gotchas (all verified by the drafts):
     - `ecma` may only use nodes that all three grammars have.
     - JS-only `(class_heritage (identifier))` lives in `javascript/usages.scm`. In TS, `class_heritage` wraps `extends_clause`.
     - `as_expression` and `satisfies_expression` have no field names, so their type is matched as a positional child.
     - The `function_type` return type is a bare child after `=>`, not a `type_annotation`.
     - JSX tag names (`<Price />`) are left unclassified.
     - Catch clause annotations are rare, because tsc only allows `any` and `unknown`. The pattern exists for completeness.
   - Precedence: the lowest pattern index wins, and inherited files come first (template Decision 1). Two consequences:
     - `Array<Money>` in any annotation is Type instantiation, because `type_arguments` precede the annotation sections.
     - `Money.parse(…)`'s `parse` is a Call, and its `Money` is Static member access.
3. **One language, three parsers.** The `js` language spans `javascript`, `javascriptreact`, `typescript` and `typescriptreact` files. The query runner parses each usage's file with its filetype's own parser language (`vim.treesitter.language.get_lang`; `languages-registry` Decision 6): javascript, javascript, typescript and tsx. The contract checks each of them: it is installed, and its `usages` query compiles and captures only catalogue ids. No registry type changes.
4. **Target kind for TypeScript.** vtsls's documentSymbol kinds for the target (checked 2026-10-17):

   | Declaration | SymbolKind | Target kind |
   |---|---|---|
   | `class Money` | Class (5) | `type` |
   | `interface Priced` | Interface (11) | `type` |
   | `enum Currency` | Enum (10) | `type` |
   | `static parse()`, method | Method (6) | `function` |
   | `function convert()` | Function (12) | `function` |
   | `const arrow = () => …` | Variable (13) | `variable` (calls stay `call`) |
   | `type Amount = number` | **Variable (13)** | `type`, by the rule below |
   | `namespace Ns` | Module (2) | `unknown` |

   - A type alias reported as Variable would lose every type-position type and fall back to tsserver's `read`.
   - The template's rule (`fix-references-usage-types` Decision 3, scenario `references: A variable named by a type identifier is a type target`) makes it a `type`: a Variable or Constant whose definition name node is a `type_identifier`. This change pins that rule with vtsls.
   - Target-kind interplay:
     - `static_member` needs a `type` target, so a PascalCase variable (`Currency.EUR` with a `variable` target) gets no syntactic type.
     - `new`, `call` and `import` are kept for every target kind.
     - A known non-type target drops the type-position ids (template Decision 3).
5. **Server facts (vtsls 0.3.0, TypeScript 5.9.3).**
   - Reference ranges start at the identifier itself:
     - `Money` in `import { Money }`, `Money.parse`, `as Money` and `Array<Money>`;
     - `parse` in `Money.parse(…)`.
   - tsserver marks import specifiers as `isWriteAccess`. Classification step 1 runs first, so they are Import, not Value write.
   - **The first references reply can be partial.** Before the project is loaded, vtsls answers with only the open file's usages: 4 of `Money`'s 15. The integration tests wait until the reply holds every manifest location before pressing `gr`.
   - Function and type targets skip steps 2 and 3. So for `Money`, `parse` and `Amount`, tsserver's write/read never decides a type.
6. **Fixture** (`tests/fixtures/build.sh`, `tsproj`).
   - New files only. `tsc --noEmit` (TypeScript 5.9.3) passes, and so does `node --check` with type stripping (Node ≥ 22.18), which the build uses when `tsc` is missing.
   - The files avoid syntax that type stripping can't erase: no `<T>x`, enums or parameter properties.

   `src/money.ts`:

   ```ts
   // An amount in cents.
   export class Money {
     cents: number;

     constructor(cents: number) {
       this.cents = cents;
     }

     // Reads a decimal amount such as "19.99".
     static parse(text: string): Money {
       return new Money(Math.round(Number(text) * 100));
     }
   }

   // Narrows an unknown value to an amount.
   export function isMoney(value: unknown): value is Money {
     return value instanceof Money;
   }
   ```

   `src/wallet.ts`:

   ```ts
   import { Money, isMoney } from "./money";

   export class Coin extends Money {}

   export class Wallet {
     items: Money[] = [];

     add(item: Money): Wallet {
       this.items.push(item);
       return this;
     }

     latest(): Money {
       return this.items.at(-1) as Money;
     }

     restore(json: string): Wallet {
       const value: unknown = JSON.parse(json);
       const item: Money = isMoney(value) ? value : Money.parse(json);
       return this.add(item);
     }
   }
   ```

   `src/money.test.ts`:

   ```ts
   import { Money } from "./money";

   export const amounts: Array<Money> = [Money.parse("19.99")];
   ```

   - The fallback syntax check gains a second loop, `node --check "$file"`, over the three new files.
   - The manifest gains `"Money"`: the declaration `src/money.ts:2:14` first, then the 15 usages in file order (1-based columns):
     - `src/money.ts` 10:31, 11:16, 16:51, 17:27;
     - `src/wallet.ts` 1:10, 3:27, 6:10, 8:13, 13:13, 14:33, 19:17, 19:50;
     - `src/money.test.ts` 1:10, 3:29, 3:39.
   - Expected types, checked by running the draft query at the vtsls reference starts:

     | Usage | Type |
     |---|---|
     | `src/money.ts:10` | `return_type` |
     | `src/money.ts:11` | `new` |
     | `src/money.ts:16`, `:17` | `instanceof` |
     | `src/wallet.ts:1` | `import` |
     | `src/wallet.ts:3` | `extends` |
     | `src/wallet.ts:6` | `field_declaration` |
     | `src/wallet.ts:8` | `parameter_declaration` |
     | `src/wallet.ts:13` | `return_type` |
     | `src/wallet.ts:14` | `cast` |
     | `src/wallet.ts:19` | `variable_declaration` and `static_member` |
     | `src/money.test.ts:1` | `import` |
     | `src/money.test.ts:3` | `type_instantiation` and `static_member` |

     `parse` has two usages, `src/wallet.ts:19` and `src/money.test.ts:3`, both `call`.
7. **Case table.** `tests/unit/references/usage_cases/js.lua` holds three suites in the shape of `drafts/cases.lua`, minus its Go suite:
   - `typescript`: 74 cases;
   - `tsx`: 26 cases;
   - `javascript`: 33 cases.

   - Expected ids are renamed as in Decision 1.
   - The sources move to `tests/unit/references/usage_cases/js/usages.{ts,tsx,js}`.
   - A case without `kind` runs with target kind `unknown`.
   - With the template's refinement rules, all 133 cases pass on Neovim 0.12.5 with the installed parsers.

## Risks / Trade-offs

- **The static member heuristic** (a PascalCase object) needs the target kind. With an `unknown` target, which needs a failed definition lookup, `Money.parse` loses its type and falls back to tsserver's `read`.
- **Grammar updates** can rename nodes. A failing query compile falls back to step 2 (template Risks), and the case table fails loudly.
- **The `type_identifier` rule** costs one extra parse of the definition file, and only for Variable and Constant targets.
- **Partial first replies** from vtsls could make a `gr` test flaky. The tests wait for the full location count (Decision 5).
- **Older Node** without type stripping can't run the fallback syntax check. The fixture then needs `tsc`.

## Renders

Stand-ins:

| Stand-in | Usage type | Stand-in | Usage type |
|---|---|---|---|
| `≡` | field declaration | `∴` | static member access |
| `↓` | import | `⊂` | supertype |
| `⊕` | new instance creation | `⇄` | type cast |
| `∷` | parameter declaration | `≟` | type check |
| `↵` | return type | `‹` | type instantiation |
| `≔` | variable declaration | `◆` | TypeScript devicon |

- Other stand-ins are as in `fix-references-usage-types`.
- The real-glyph, real-colour renders are `renders/ts_current.ansi` and `renders/ts_p1_class.ansi`; view them with `command cat`.
- The `ReferencesUsageType*` groups are created by `fix-references-usage-types`. Until it lands, `make colorize` shows them as plain text.
- The editor is 70 columns wide, so there is no preview. It is 50 rows tall, so that P1's 43 tree rows fit without scrolling.
- The background is `src/money.ts`. Rows below the file's end are blank (`fillchars` `eob: `).

**Current — class usages**: `70x50`, Normal, `src/money.ts` (extended tsproj fixture), vtsls attached, `gr` on `Money` (line 2); default grouping; classification finished; no preview below 80 columns. Every usage is `unclassified`: no usage type level, no hint entry.

```text
▎ money.ts                                                            
   1 // An amount in cents.                                           
   2 export class Money {                                             
   3   cents: number;                                                 
   4                                                                  
   5   constructor(cents: number) {                                   
   6     this.cents = cents;                                          
   7   }                                                              
   8                                                                  
   9   // Reads a decimal amount such as "19.99".                     
  10   static parse(text: string): Money {                            
  11     return new Money(Math.round(Number(text) * 100));            
  12   }                                                              
  13 }            ╭ Usages of Money · 15 ──────────╮                  
  14              │ ▾ ▣ Production  12             │                  
  15 // Narrows an│   ▾ □ src  12                  │                  
  16 export functi│       ◆ money.ts:10            │is Money {        
  17   return valu│       ◆ money.ts:11            │                  
  18 }            │       ◆ money.ts:16            │                  
                  │       ◆ money.ts:17            │                  
                  │       ◆ wallet.ts:1            │                  
                  │       ◆ wallet.ts:3            │                  
                  │       ◆ wallet.ts:6            │                  
                  │       ◆ wallet.ts:8            │                  
                  │       ◆ wallet.ts:13           │                  
                  │       ◆ wallet.ts:14           │                  
                  │       ◆ wallet.ts:19           │                  
                  │       ◆ wallet.ts:19           │                  
                  │ ▾ ▲ Test  3                    │                  
                  │   ▾ □ src  3                   │                  
                  │       ◆ money.test.ts:1        │                  
                  │       ◆ money.test.ts:3        │                  
                  │       ◆ money.test.ts:3        │                  
                  ├────────────────────────────────┤                  
                  │ Tests: grouped t · ● Folders f │                  
                  ╰────────────────────────────────╯                  
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
 NORMAL  ⎇ main                                            typescript 
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
......................................................................
......................................................................
......................................................................
......................................................................
..................bttttttttttttttttttttttbbbbbbbbbbb..................
..................bfffPfppppppppppffssfffffffffffffb..................
..................bfffffDfdddffssffffffffffffffffffb..................
..................bcccccccGcggggggggcccccccccccccccb..................
..................bfffffffGfggggggggsssffffffffffffb..................
..................bfffffffGfggggggggsssffffffffffffb..................
..................bfffffffGfggggggggsssffffffffffffb..................
..................bfffffffGfgggggggggssffffffffffffb..................
..................bfffffffGfgggggggggssffffffffffffb..................
..................bfffffffGfgggggggggssffffffffffffb..................
..................bfffffffGfgggggggggssffffffffffffb..................
..................bfffffffGfgggggggggsssfffffffffffb..................
..................bfffffffGfgggggggggsssfffffffffffb..................
..................bfffffffGfgggggggggsssfffffffffffb..................
..................bfffffffGfgggggggggsssfffffffffffb..................
..................bfffEfeeeeffsffffffffffffffffffffb..................
..................bfffffDfdddffsfffffffffffffffffffb..................
..................bfffffffGfgggggggggggggssffffffffb..................
..................bfffffffGfgggggggggggggssffffffffb..................
..................bfffffffGfgggggggggggggssffffffffb..................
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
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconTypeScript] · `g` [ReferencesFileLabelDevIconTypeScript]

**Proposed P1 — TypeScript usage types of a class**: `70x50`, Normal, `src/money.ts` (extended tsproj fixture), vtsls attached, `gr` on `Money` (line 2); tests grouped, folders on, usage type on; classification finished; first usage selected; no preview below 80 columns, the window shrinks to its content and stays centred.

```text
▎ money.ts                                                            
   1 // A╭ Usages of Money · 15 ───────────────────────────╮          
   2 expo│ ▾ ▣ Production  12                              │          
   3   ce│   ▾ ≡ Field declaration  1                      │          
   4     │     ▾ □ src  1                                  │          
   5   co│         ◆ wallet.ts:6                           │          
   6     │   ▾ ↓ Import  1                                 │          
   7   } │     ▾ □ src  1                                  │          
   8     │         ◆ wallet.ts:1                           │          
   9   //│   ▾ ⊕ New instance creation  1                  │          
  10   st│     ▾ □ src  1                                  │          
  11     │         ◆ money.ts:11                           │          
  12   } │   ▾ ∷ Parameter declaration  1                  │          
  13 }   │     ▾ □ src  1                                  │          
  14     │         ◆ wallet.ts:8                           │          
  15 // N│   ▾ ↵ Return type  2                            │          
  16 expo│     ▾ □ src  2                                  │ {        
  17   re│         ◆ money.ts:10                           │          
  18 }   │         ◆ wallet.ts:13                          │          
         │   ▾ ∴ Static member access  1                   │          
         │     ▾ □ src  1                                  │          
         │         ◆ wallet.ts:19                          │          
         │   ▾ ⊂ Supertype  1                              │          
         │     ▾ □ src  1                                  │          
         │         ◆ wallet.ts:3                           │          
         │   ▾ ⇄ Type cast  1                              │          
         │     ▾ □ src  1                                  │          
         │         ◆ wallet.ts:14                          │          
         │   ▾ ≟ Type check  2                             │          
         │     ▾ □ src  2                                  │          
         │         ◆ money.ts:16                           │          
         │         ◆ money.ts:17                           │          
         │   ▾ ≔ Variable declaration  1                   │          
         │     ▾ □ src  1                                  │          
         │         ◆ wallet.ts:19                          │          
         │ ▾ ▲ Test  3                                     │          
         │   ▾ ↓ Import  1                                 │          
         │     ▾ □ src  1                                  │          
         │         ◆ money.test.ts:1                       │          
         │   ▾ ∴ Static member access  1                   │          
         │     ▾ □ src  1                                  │          
         │         ◆ money.test.ts:3                       │          
         │   ▾ ‹ Type instantiation  1                     │          
         │     ▾ □ src  1                                  │          
         │         ◆ money.test.ts:3                       │          
         ├─────────────────────────────────────────────────┤          
         │ Tests: grouped t · ● Folders f · ● Usage type u │          
         ╰─────────────────────────────────────────────────╯          
                                                                      
 NORMAL  ⎇ main                                            typescript 
```

```text
......................................................................
.........bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffssffffffffffffffffffffffffffffffb..........
.........bfffffIfiiiiiiiiiiiiiiiiiffsffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bcccccccccGcgggggggggcccccccccccccccccccccccccccccb..........
.........bfffffAfaaaaaaffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........
.........bfffffWfwwwwwwwwwwwwwwwwwwwwwffsffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........
.........bfffffJfjjjjjjjjjjjjjjjjjjjjjffsffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........
.........bfffffUfuuuuuuuuuuuffsffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........
.........bfffffYfyyyyyyyyyyyyyyyyyyyyffsfffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........
.........bfffffVfvvvvvvvvvffsffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........
.........bfffffLflllllllllffsffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........
.........bfffffKf1111111111ffsfffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........
.........bfffffRf33333333333333333333ffsfffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........
.........bfffEfeeeeffsfffffffffffffffffffffffffffffffffffffb..........
.........bfffffAfaaaaaaffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggggggssfffffffffffffffffffffffb..........
.........bfffffYfyyyyyyyyyyyyyyyyyyyyffsfffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggggggssfffffffffffffffffffffffb..........
.........bfffffHf222222222222222222ffsfffffffffffffffffffffb..........
.........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggggggssfffffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconTypeScript] · `g` [ReferencesFileLabelDevIconTypeScript] · `I` [ReferencesUsageTypeFieldDeclaration] · `i` [ReferencesUsageTypeFieldDeclarationLabel] · `A` [ReferencesUsageTypeImport] · `a` [ReferencesUsageTypeImportLabel] · `W` [ReferencesUsageTypeNew] · `w` [ReferencesUsageTypeNewLabel] · `J` [ReferencesUsageTypeParameterDeclaration] · `j` [ReferencesUsageTypeParameterDeclarationLabel] · `U` [ReferencesUsageTypeReturnType] · `u` [ReferencesUsageTypeReturnTypeLabel] · `Y` [ReferencesUsageTypeStaticMember] · `y` [ReferencesUsageTypeStaticMemberLabel] · `V` [ReferencesUsageTypeExtends] · `v` [ReferencesUsageTypeExtendsLabel] · `L` [ReferencesUsageTypeCast] · `l` [ReferencesUsageTypeCastLabel] · `K` [ReferencesUsageTypeInstanceof] · `1` [ReferencesUsageTypeInstanceofLabel] · `H` [ReferencesUsageTypeTypeInstantiation] · `2` [ReferencesUsageTypeTypeInstantiationLabel] · `R` [ReferencesUsageTypeVariableDeclaration] · `3` [ReferencesUsageTypeVariableDeclarationLabel]
