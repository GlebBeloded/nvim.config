## Why

Kind: bug
Depends: fix-references-usage-types-typescript

Find Usages has GoLand's usage types for Go only. Python has no `usages` query, so a class's imports, instantiations, superclass lists, `isinstance` checks and annotations are all `Unclassified`, and the view shows them as one flat list. PyCharm classifies some of these with JetBrains' `PyUsageTypeProvider`, and GoLand classifies far more for Go. The user wants that observability for every configured language.

## Evidence

- `gr` on `Money` in the extended `pyproj` fixture (design.md, Decision 6), checked with basedpyright 1.37.4: the server returns 5 usages, in `shop/pricing.py` and `tests/test_pricing.py`. `money.Money` starts at `Money`.
  - Today, documentHighlight marks the `from shop.money import Money` specifier `Write` (3) and the other four `Read` (2).
  - Once `fix-references-usage-types` lands, `Money` is a `type` target (documentSymbol kind Class). A type target never gets write/read, and no Python query exists, so all 5 usages are `Unclassified`. The view has no usage type level (render "Current — class usages").
- JetBrains' Python classifier (`com.jetbrains.python.findUsages.PyUsageTypeProvider`, intellij-community) has five types:
  - Usage in an import statement
  - Untyped (probable) usage
  - Usage in isinstance()
  - Usage in a type hint
  - Usage in the superclass list
  - Read/write comes from `PyReadWriteAccessDetector`.
- `lua/gleb/languages/python/init.lua:11` leaves Python's `references.usage_types` disabled, while `lua/gleb/references/kind_ts.lua:19` looks up a runtime `usages` query and `lua/gleb/references/kind_ts.lua:59` returns unclassified results when none exists.
- `lua/gleb/references/kind_refine.lua:28` refines a type-target call only for Go, so Python class calls cannot become `new` after the query classifies them as `call`.
- A verified draft is in `drafts/`: `queries/python/usages.scm`, the case fixture `fixtures/usages.py`, the case table `expected.lua` and a verifier. It uses catalogue ids and the template's target-kind rules plus this change's call rule. Its 157 cases pass on Neovim 0.12.5 with the installed `python` parser.

## What Changes

- **Python query.** Add `queries/python/usages.scm`, ported from `drafts/queries/python/usages.scm` (design.md, Decision 1).
- **Types:**
  - Import, Decorator, Supertype (superclass list and `metaclass=`), Type check (`isinstance`/`issubclass`), Catch clause (`except`), Keyword argument, Call and Pattern (`case Point(x=0)`).
  - Parameter declaration, Field declaration (annotated class-body names), Variable declaration, Type alias (`type A = T`, `A: TypeAlias = T`) and Return type.
  - A `write` fallback for assignment targets.
- **Target kind.** A Python `call` of a `type` target becomes `new` (New instance creation). This rule is added next to the template's Go `call` → `type_conversion` rule.
- **Registry.** The `python` language's `references.usage_types` becomes `true`.
- **Case table:** `tests/unit/references/usage_cases/python.lua`, with its source in `tests/unit/references/usage_cases/python/usages.py`.
- **Fixture.** The `pyproj` fixture gains `shop/money.py`, `shop/pricing.py` and `tests/test_pricing.py`, and a `Money` manifest entry. Only new files are added, so every existing line and manifest entry holds.
- **Render:** "Proposed P1 — Python usage types of a class".

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `references`: added "Python usage types". No existing requirement or scenario changes.

## Impact

- Code:
  - New: `queries/python/usages.scm`.
  - Changed:
    - `lua/gleb/languages/python/init.lua`: `usage_types = true`;
    - the target-kind refinement in `lua/gleb/references/kind_refine.lua`: a `call` of a `type` target is `new` in Python.
- Tests:
  - unit: `tests/unit/references/usage_cases/python.lua` and its source, run by the shared case driver.
  - integration: basedpyright `gr` on `Money` in the extended `pyproj` fixture.
  - screen: P1.
- Fixture: `tests/fixtures/build.sh` `pyproj` (three new files and the `Money` manifest entry).
- Plugins: none. Core keymaps: none.
- Unchanged scenarios:
  - `languages: Requirement: References facet` still holds: enabling Python is paired with its Python parser query and query case table.
  - `languages: A missing usages query breaks the contract` still holds: the contract remains unchanged, and Python supplies the query it requires before enabling usage types.
  - `references: Python usages in production and test files` still holds: the new files don't reference `total`, and the scenario names no type rows.
  - `references: gr classifies every Python variable usage` still holds: `total += 1` and `print(total)` match no syntactic type, so basedpyright's write/read still decides.
  - `references: basedpyright kinds classify a Python variable` still holds: the same lines get no syntactic type.
  - `references: Python test paths` still holds: the test patterns are unchanged.
  - `file-tree: gr keeps its global meaning in git status tree` still holds: the global `gr` mapping is untouched; only the classification of Python usages changes.
- Out of scope:
  - "Untyped (probable) usage". It flags a qualified usage whose qualifier has no inferred type, which needs type inference that servers don't expose.
  - String annotations (`"Money"`) and PEP 695 bounds (`[T: Money]`). They stay unclassified.
  - Type aliases and `TypeVar`s as targets. basedpyright reports them as Variable or Constant, so their annotation usages fall back to `read` (design.md, Risks).
  - Comment and string usages: servers don't return them.

## Decision (user, 2026-10-17)

- "it is implemented, but lacking. Goland system is ALOT reacher. … I want goland-like observability over references, which is sueprior. … create a spec to fix it for all langauges."

## Agent decisions

- **Mapping:** JetBrains' Python wording maps onto the GoLand-worded catalogue:
  - "Usage in an import statement" → Import
  - "Usage in isinstance()" → Type check, which `issubclass` also gets
  - "Usage in the superclass list" → Supertype
  - "Usage in a type hint" → split by position into Parameter declaration, Return type, Field declaration, Variable declaration and Type alias, as GoLand does
- **Calls of a class are instance creation.** For a type target, `Money(0)` is "New instance creation", as JetBrains' Java and Kotlin classify `new Money()` and constructor calls. For a function or unknown target it stays "Call", as GoLand's `T(x)` rule decides by target kind.
- **Richer than JetBrains:** Decorator, Catch clause, Keyword argument and Pattern have no PyCharm type. They use the catalogue's existing ids.
- **Precedence:** the first pattern wins. So `@pkg.cached(ttl=10)` is Decorator, not Call, and `Meta(strict=True)` inside an annotation is Call, not Parameter declaration.
- **Write fallback:** the query captures assignment targets as `write`, as the Go, Lua and Bash queries do. A file whose server times out then shows writes as Value write, not Value read.
- **Fixture symbol:** the `python` facet keeps `total` as its smoke symbol. `Money` is a second manifest entry for the type scenarios.
- **Render size:** P1 fits the V4 size (`70x24`). Its 17 tree rows fit under the 18-row cap, so the fixture keeps five usage types.
