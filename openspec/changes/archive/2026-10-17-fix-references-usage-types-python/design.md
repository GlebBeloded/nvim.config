## Context

See proposal.md (Why, Evidence). This change plugs Python into the classifier from `fix-references-usage-types` (catalogue, `queries/<lang>/usages.scm`, classification order, target kind) through the `python` language's `references` facet from `languages-registry`. Research (2026-10-17):

- **JetBrains' Python taxonomy** is `PyUsageTypeProvider` (intellij-community, `python/src/com/jetbrains/python/findUsages/`). It walks the reference's PSI parents, and the first match wins:
  1. Usage in an import statement: inside any `PyImportStatementBase`.
  2. Untyped (probable) usage: a qualified reference whose qualifier has no inferred type, or a structural one.
  3. Usage in isinstance(): the second argument of a two-argument `isinstance` call, or an element of a tuple there. `issubclass` is not included.
  4. Usage in a type hint: anywhere `PyTypingTypeProvider.isInsideTypeHint` holds.
  5. Usage in the superclass list: inside the class's superclass expression list.
  - Read/write comes from `PyReadWriteAccessDetector`. Everything else is "Unclassified".
- **Why richer.**
  - PyCharm has one bucket for every annotation. GoLand splits annotations by position: parameter, return, field, variable, alias. The user asked for GoLand-level observability, so we split them the same way.
  - Calls, decorators, `except` clauses, keyword arguments and `match` class patterns have no PyCharm type. They get the catalogue's existing ids.
  - "Untyped (probable) usage" needs type inference that no server exposes, so it is left out.
- **Server facts** (basedpyright 1.37.4; `drafts/lsp_check/py.lua` and the `Money` fixture check):
  - Reference ranges start on the last segment (`m.Thing`, `pkg.mod.Thing`, `@m.dec`, `money.Money`).
  - References carry no access kind. documentHighlight does: Read is 2 and Write is 3, and an import specifier is Write.
  - documentSymbol reports a class as Class (5) → `type`, and a function as Function (12) → `function`. `T = TypeVar("T")` is Constant (14), and `A: TypeAlias = …` and `type A = …` are Variable (13). All three map to `variable`.
  - basedpyright answers nothing until it has received its settings. The probe passes `settings = { basedpyright = { analysis = { … } } }`, as the real config does.
- **Parser:** `python` is installed. The query parser language is the `python` filetype's own (`languages-registry` Decision 6).

## Goals / Non-Goals

**Goals:**
- Every position in the case table gets its catalogue type with the installed `python` parser.
- `gr` on a Python class shows GoLand-style groups in the real view.

**Non-Goals:**
- "Untyped (probable) usage", string annotations and PEP 695 bounds.
- Recognising aliases and `TypeVar`s as type targets (Risks).

## Decisions

1. **Query file.** `queries/python/usages.scm` is copied from `drafts/queries/python/usages.scm`. The draft already uses catalogue ids. The implementation may restructure it, but all 157 cases in `drafts/expected.lua` must still pass. Draft id → catalogue id, for every capture:

   | Draft id | Catalogue id | Label | Matches |
   |---|---|---|---|
   | import | `import` | Import | every identifier in `import`, `from … import` and `from __future__ import` |
   | decorator | `decorator` | Decorator | `@name`, `@m.name`, `@name(…)`, `@m.name(…)` |
   | superclass | `extends` | Supertype | superclass list: names, `m.Base`, `Generic[T]` and its argument, `metaclass=M` |
   | isinstance | `instanceof` | Type check | second argument of `isinstance`/`issubclass`: a name, an attribute, tuple elements, `A \| B` |
   | except | `catch` | Catch clause | `except T`, `except (A, m.B) as e`, `except* T` |
   | keyword_argument | `keyword_argument` | Keyword argument | `f(name=…)` as a usage of the parameter `name` |
   | call | `call` | Call | `f()`, `obj.m()`, `m.f()` (the last segment) |
   | pattern | `pattern` | Pattern | `case Point(x=0)`: the class and the keyword |
   | parameter_declaration | `parameter_declaration` | Parameter declaration | any name inside a parameter annotation |
   | field_declaration | `field_declaration` | Field declaration | annotated assignment directly in a class body, up to 9 levels of generics |
   | variable_declaration | `variable_declaration` | Variable declaration | any other annotated assignment, `TypeAlias` itself included |
   | type_alias | `type_alias` | Type alias | the right side of `type A = …` and `A: TypeAlias = …` |
   | return_type | `return_type` | Return type | anything in `-> …`, up to 9 levels |
   | write (new) | `write` | Value write | assignment, augmented assignment, unpacking, `for` and walrus targets, including `obj.attr = …` |

   - Precedence is the file order (lowest pattern index wins). `drafts/overlaps.lua` lists the overlaps:
     - field over variable declaration in class bodies;
     - decorator over call (`@m.cached(ttl=10)`);
     - call and keyword argument over parameter declaration (`Annotated[T, Meta(strict=True)]`);
     - every syntactic type over `write`.
   - `write` is the step 3 fallback of the template's order. basedpyright's documentHighlight still decides first, and a function or type target never gets it.
2. **Grammar gotchas** (tree-sitter-python as installed):
   - Annotations are always wrapped in a `type` node. `Optional[T]` is a `generic_type`, but `typing.Optional[T]` is a `subscript`, and both are covered by the depth-enumerated wildcards.
   - `x: T` without a value is still an `assignment` (with `type` and no `right`). So `slot: Thing` in a class body is a field declaration, and `slot` itself is `write`.
   - A string annotation `"Fwd"` is a `string` node and gets no type. A PEP 695 bound `[T: Money]` is not under `type` and gets none either.
   - Wildcard nesting is unbounded only through `#has-ancestor?`. Fixed-depth alternations cover up to 9 levels under `type`, which is three levels of generics such as `dict[str, list[Optional[T]]]`.
3. **Server ranges.** basedpyright starts a range on the last segment, so a capture on `(attribute attribute: (identifier))` matches qualified usages. The qualifier (`money` in `money.Money`) is never captured, because the server never returns a range there for the class.
4. **Target kind.**
   - The template's rules apply unchanged:
     - a function or type target gets no write/read;
     - a known non-type target drops the type-position ids (`parameter_declaration`, `return_type`, `field_declaration`, `variable_declaration`, `type_alias`, `instanceof`, `extends`, `catch`);
     - an unknown target keeps every syntactic type.
   - One rule is added: a Python `call` with a `type` target is `new` (New instance creation). It sits next to Go's `call` → `type_conversion` and is keyed by the usage's parser language in the same way. A function, variable or unknown target keeps `call`.
   - `import`, `decorator`, `keyword_argument` and `pattern` are not type positions, so they survive any target kind.
   - The case table adds `kind = …` cases for these rules: Thing at line 21 with `type` is `new` and with `unknown` is `call`, and an `instanceof`/`extends`/`catch` with a non-type kind is dropped.
5. **Case table.**
   - `drafts/expected.lua` is ported to `tests/unit/references/usage_cases/python.lua`, and `drafts/fixtures/usages.py` to `tests/unit/references/usage_cases/python/usages.py`, in the shared driver's format.
   - Entries are `{ line, needle, id | false, nth = …, kind = … }`, where `false` is a negative: no syntactic type.
   - There are 157 cases: 106 positives (17 of them `write`, 2 of them `new`), 46 negatives and 5 negatives dropped by target kind.
6. **Fixture** (`tests/fixtures/build.sh`, `pyproj`). Only new files are added, so `shop/price.py`, `shop/cart.py` and `tests/test_price.py` and the `total` entry keep their lines. The `py_compile` line adds the three files.
   - `shop/money.py`:

     ```python
     from dataclasses import dataclass


     @dataclass(frozen=True)
     class Money:
         cents: int
     ```

   - `shop/pricing.py`:

     ```python
     from shop.money import Money

     ZERO = Money(0)


     class Price(Money):
         """A unit price in cents."""


     def discount(price: Money, percent: int) -> int:
         return price.cents * percent // 100
     ```

   - `tests/test_pricing.py`:

     ```python
     from shop import money, pricing


     def test_zero_is_money() -> None:
         assert isinstance(pricing.ZERO, money.Money)
     ```

   - The manifest gains `"Money"` from `identifier_locations Money shop/money.py shop/pricing.py tests/test_pricing.py`: `shop/money.py:5:7`, `shop/pricing.py:1:24`, `:3:8`, `:6:13`, `:10:21` and `tests/test_pricing.py:5:43`. The first entry is the declaration.
   - The files pass `py_compile` and `ruff check`, and `test_zero_is_money` passes under Python 3.14.
   - basedpyright returns exactly the 5 non-declaration usages. With the query and refinement they classify as:

     | Usage | Raw capture | Type (`type` target) |
     |---|---|---|
     | `shop/pricing.py:1` (`import Money`) | import | `import` |
     | `shop/pricing.py:3` (`Money(0)`) | call | `new` |
     | `shop/pricing.py:6` (`class Price(Money)`) | extends | `extends` |
     | `shop/pricing.py:10` (`price: Money`) | parameter_declaration | `parameter_declaration` |
     | `tests/test_pricing.py:5` (`money.Money`, range at col 42) | instanceof | `instanceof` |

   - Five types keep the P1 tree at 17 rows. That fits the 18-row cap of a 24-line editor (`view.lua`: `lines - 6`), so the render needs no scrolling.

## Risks / Trade-offs

- **Aliases and TypeVars are not type targets.** basedpyright reports them as Variable or Constant, so `def f(a: Legacy)` is dropped as a type position for the `Legacy` target and falls back to `read`. The same applies to a superclass held in a variable (`Base = declarative_base()`). This is the template's rule and is not changed here. A later change could map these through semantic tokens.
- **Name-based checks.** `isinstance`/`issubclass` are matched by name, so a shadowed `isinstance` still counts. PyCharm resolves the call. This is acceptable for a classifier that only labels server-confirmed usages.
- **Depth cap.** Annotations nested deeper than 9 levels under `type` lose their type and fall back to server kinds. No such annotation exists in this repo's fixtures or real code.
- **Grammar updates** can rename nodes. The query then fails to compile, the language falls back to step 2, and the case table fails loudly.
- **basedpyright from mason** must be runnable. On this host the mason venv's interpreter is missing, and the probes ran with `~/.venvs/default/bin/basedpyright-langserver` 1.37.4. The integration tests reuse `require_server`, which reports a missing server as a skip.

## Current render

Stand-ins: `⇲` import, `⊕` new instance creation, `∷` parameter declaration, `⊤` supertype, `≟` type check. `◆` is the Python devicon. Other stand-ins are as in `fix-references-usage-types`.
- The real-glyph, real-colour renders are in `renders/py_current.ansi` and `renders/py_p1_class.ansi`; view them with `command cat`.
- Each type group is `ReferencesUsageType<CamelId>[Label]`, as created by `fix-references-usage-types`. `make colorize` shows them as plain text until that change lands.
- The layout is V4's: `70x24`, no preview, and the window shrunk to its content and centred. The background is `shop/money.py`, the file the cursor is in. Rows past its end are blank (`fillchars` `eob: `).

**Current — class usages**: `70x24`, Normal, `shop/money.py` (extended pyproj fixture), basedpyright and ruff attached, `gr` on `Money` (line 5); default grouping; classification finished; first usage selected. As after `fix-references-usage-types` and `languages-registry`: python has no `usages` query and a type target gets no write/read, so every usage is `unclassified`: plain rows, no usage type level, no hint entry.

```text
▎ money.py                                                            
   1 from dataclasses import dataclass                                
   2                                                                  
   3                                                                  
   4 @dataclass(frozen=True)                                          
   5 class Money: ╭ Usages of Money · 5 ───────────╮                  
   6     cents: in│ ▾ ▣ Production  4              │                  
                  │   ▾ □ shop  4                  │                  
                  │       ◆ pricing.py:1           │                  
                  │       ◆ pricing.py:3           │                  
                  │       ◆ pricing.py:6           │                  
                  │       ◆ pricing.py:10          │                  
                  │ ▾ ▲ Test  1                    │                  
                  │   ▾ □ tests  1                 │                  
                  │       ◆ test_pricing.py:5      │                  
                  ├────────────────────────────────┤                  
                  │ Tests: grouped t · ● Folders f │                  
                  ╰────────────────────────────────╯                  
                                                                      
                                                                      
                                                                      
                                                                      
                                                                      
 NORMAL  ⎇ main                                                python 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
..................btttttttttttttttttttttbbbbbbbbbbbb..................
..................bfffPfppppppppppffsffffffffffffffb..................
..................bfffffDfddddffsffffffffffffffffffb..................
..................bcccccccGcggggggggggcccccccccccccb..................
..................bfffffffGfggggggggggssfffffffffffb..................
..................bfffffffGfggggggggggssfffffffffffb..................
..................bfffffffGfggggggggggsssffffffffffb..................
..................bfffEfeeeeffsffffffffffffffffffffb..................
..................bfffffDfdddddffsfffffffffffffffffb..................
..................bfffffffGfgggggggggggggggssffffffb..................
..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................
..................bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxb..................
..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconPy] · `g` [ReferencesFileLabelDevIconPy]

## Proposed render

**Proposed P1 — Python usage types of a class**: `70x24`, Normal, `shop/money.py` (extended pyproj fixture), basedpyright and ruff attached, `gr` on `Money` (line 5); tests grouped, folders on, usage type on; classification finished; first usage selected; the preview is hidden below 80 columns, the window shrinks to its content and stays centred.

```text
▎ money.py                                                            
   1 from╭ Usages of Money · 5 ────────────────────────────╮          
   2     │ ▾ ▣ Production  4                               │          
   3     │   ▾ ⇲ Import  1                                 │          
   4 @dat│     ▾ □ shop  1                                 │          
   5 clas│         ◆ pricing.py:1                          │          
   6     │   ▾ ⊕ New instance creation  1                  │          
         │     ▾ □ shop  1                                 │          
         │         ◆ pricing.py:3                          │          
         │   ▾ ∷ Parameter declaration  1                  │          
         │     ▾ □ shop  1                                 │          
         │         ◆ pricing.py:10                         │          
         │   ▾ ⊤ Supertype  1                              │          
         │     ▾ □ shop  1                                 │          
         │         ◆ pricing.py:6                          │          
         │ ▾ ▲ Test  1                                     │          
         │   ▾ ≟ Type check  1                             │          
         │     ▾ □ tests  1                                │          
         │         ◆ test_pricing.py:5                     │          
         ├─────────────────────────────────────────────────┤          
         │ Tests: grouped t · ● Folders f · ● Usage type u │          
         ╰─────────────────────────────────────────────────╯          
                                                                      
 NORMAL  ⎇ main                                                python 
```

```text
......................................................................
.........btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........
.........bfffffIfiiiiiiffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........
.........bcccccccccGcggggggggggccccccccccccccccccccccccccccb..........
.........bfffffZfzzzzzzzzzzzzzzzzzzzzzffsffffffffffffffffffb..........
.........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggssffffffffffffffffffffffffffb..........
.........bfffffJfjjjjjjjjjjjjjjjjjjjjjffsffffffffffffffffffb..........
.........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggsssfffffffffffffffffffffffffb..........
.........bfffffUfuuuuuuuuuffsffffffffffffffffffffffffffffffb..........
.........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfggggggggggssffffffffffffffffffffffffffb..........
.........bfffEfeeeeffsfffffffffffffffffffffffffffffffffffffb..........
.........bfffffVfvvvvvvvvvvffsfffffffffffffffffffffffffffffb..........
.........bfffffffDfdddddffsffffffffffffffffffffffffffffffffb..........
.........bfffffffffGfgggggggggggggggssfffffffffffffffffffffb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
.........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........
.........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconPy] · `g` [ReferencesFileLabelDevIconPy] · `I` [ReferencesUsageTypeImport] · `i` [ReferencesUsageTypeImportLabel] · `Z` [ReferencesUsageTypeNew] · `z` [ReferencesUsageTypeNewLabel] · `J` [ReferencesUsageTypeParameterDeclaration] · `j` [ReferencesUsageTypeParameterDeclarationLabel] · `U` [ReferencesUsageTypeExtends] · `u` [ReferencesUsageTypeExtendsLabel] · `V` [ReferencesUsageTypeInstanceof] · `v` [ReferencesUsageTypeInstanceofLabel]
