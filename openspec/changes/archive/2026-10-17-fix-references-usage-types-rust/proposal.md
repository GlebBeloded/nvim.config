## Why

Kind: bug
Depends: fix-references-usage-types-python

Find Usages has GoLand's usage types for Go only. Rust has no `usages` query, so a struct's `use` items, `impl` heads, struct literals, patterns, constructor calls and type annotations are all `Unclassified`, and the view shows them as one flat list. JetBrains' Rust plugin classifies the same usages with `RsUsageTypeProvider`. The user wants that observability for every configured language.

## Evidence

- `gr` on `Money` in the extended `rustproj` fixture (design.md, Decision 7), checked with rust-analyzer 0.3.2819 (2026-03-08) and `drafts/lsp_check/rustproj.lua`:
  - The server returns 10 usages in `src/money.rs`, `src/ledger.rs` and `tests/money.rs`. Each range starts at the last path segment, so `Money::from_cents` starts at `Money` and `crate::money::Money` at the final `Money`.
  - References carry no read/write. documentHighlight marks the struct's usages with no kind.
  - Once `fix-references-usage-types` lands, `Money` is a `type` target, which never gets write/read, and no Rust query exists. So all 10 usages are `Unclassified`, and the view has no usage type level (render "Current — Rust struct usages").
- `gr` on `total` (`rustproj`, `src/price.rs:1`) lists `src/main.rs:4`, `src/price.rs:9` and `tests/price.rs:5` as plain rows. All three calls sit inside `println!`/`assert_eq!`.
- JetBrains' Rust classifier (`org.rust.ide.search.RsUsageTypeProvider` in the archived intellij-rust repository) checks the PSI parents of the reference's path. Its types are lowercase hardcoded strings:
  - impl, type reference, trait reference
  - expr, dot expr, function call, method call, argument
  - macro call, macro argument
  - init struct, init field
  - variable binding, field, meta item, use, mod
- `lua/gleb/languages/rust/init.lua:15` leaves the `rust` language's `references.usage_types` as `{ disabled = "queued: fix-references-usage-types-rust" }`.
- A verified draft is in `drafts/`: `queries/rust/usages.scm` (already in catalogue ids), the case fixture `fixtures/usages.rs`, the case table `expected.lua` and a verifier. Its 187 cases pass on Neovim 0.12.5 with the installed `rust` parser.

## What Changes

- **Rust query.** New `queries/rust/usages.scm` from `drafts/queries/rust/usages.scm` (design.md, Decision 1). Its types are:
  - Call (functions, methods, tuple-struct constructors and path qualifiers of a call), Macro call, Macro argument, Import
  - Impl (the self type of an `impl`), Supertype (the trait of `impl Trait for T`), Type constraint (bounds, `where`, `impl Trait`, `dyn Trait`, supertraits)
  - Struct initialization, Field initialization, Pattern, Field access
  - Field declaration, Parameter declaration, Return type, Variable declaration (`let`, `const`, `static`), Type alias, Type cast (`as`), Type instantiation (generic arguments)
  - Value write for a field assignment target (`x.f = v`, `x.f += v`), which rust-analyzer's documentHighlight also reports.
  - A path qualifier takes the type of its whole path, as in intellij-rust. Annotations are matched through type wrappers (references, generics, tuples, arrays, qualified paths) up to depth 8.
- **Registry.** The `rust` language's `references.usage_types` becomes `true`.
- **Case table:** `tests/unit/references/usage_cases/rust.lua`, with its source in `tests/unit/references/usage_cases/rust/usages.rs`.
- **Fixture.** The `rustproj` fixture gains `src/money.rs`, `src/ledger.rs` and `tests/money.rs`, two `pub mod` lines at the end of `src/lib.rs`, and a `Money` manifest entry. Every existing line and manifest entry holds.
- **Render:** "Proposed R1 — usage types of a Rust struct".

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `references`: extend usage type classification and grouping to Rust.

## Impact

- Code:
  - New: `queries/rust/usages.scm`.
  - Changed: `lua/gleb/languages/rust/init.lua` (`references.usage_types = true`).
- Tests:
  - unit: `tests/unit/references/usage_cases/rust.lua` and its source, run by the shared case driver.
  - integration:
    - rust-analyzer `gr` on `Money` and on the `cents` field in the extended `rustproj` fixture (`tests/integration/references/test_kind.lua`, with its existing rust-analyzer readiness wait);
    - the Rust case of `tests/integration/references/test_languages.lua` expects a `Macro argument` type row under each scope when the `rust` parser is installed.
  - screen: R1.
- Fixture: `tests/fixtures/build.sh` `rustproj` (three new files, two appended `pub mod` lines and the `Money` manifest entry).
- Plugins: none. Core keymaps: none.
- Unchanged scenarios:
  - `languages: A missing usages query breaks the contract` still holds: the Rust facet is enabled only together with `queries/rust/usages.scm`, so the contract continues to reject any enabled language whose query is absent.
  - `references: Rust usages in production and test code` still holds: the new files don't reference `total`, and the scenario places usages by scope and folder only; the `Macro argument` level sits between them.
  - `references: gr classifies every Rust variable usage` still holds: `n += 1` matches no type pattern and `{n}` lies inside string content, so rust-analyzer's write/read still decides.
  - `references: rust-analyzer kinds classify a Rust variable` still holds: the same positions get no syntactic type.
  - `references: Rust test paths` still holds: the test patterns are unchanged.
  - `references: Position inside Rust cfg test module` still holds: test-module detection doesn't read the usages query.
  - `file-tree: gr keeps its global meaning in git status tree` still holds: the global `gr` mapping and its callback are untouched; only the Rust query, the rust facet flag and the fixture change.
- Out of scope:
  - Classifying inside macro expansions. intellij-rust resolves a call inside `println!` as "function call"; the treesitter query sees a flat token tree, so it is `Macro argument`.
  - Inline format arguments (`format!("{x}")`): they are string content, so they get the server's write/read or stay `Unclassified`.
  - intellij-rust's "meta item" (`#[derive(Debug)]` arguments) and "mod" (`mod money;`). The catalogue has no such ids, so they stay `Unclassified`.
  - rust-analyzer omitting non-macro references when a symbol is also used inside a macro in the same file (design.md, Risks). The fixture doesn't depend on it; it is a follow-up for the references request, not for classification.
  - "Usage in comments" and "Usage in string constants": servers don't return those locations.

## Decision (user, 2026-10-17)

- "it is implemented, but lacking. Goland system is ALOT reacher. … I want goland-like observability over references, which is sueprior. … create a spec to fix it for all langauges."

## Agent decisions

- **Mapping:** intellij-rust's lowercase strings map onto the GoLand-worded catalogue:
  - "function call" and "method call" → Call (GoLand uses Call for both).
  - "type reference" → the position-specific Field declaration, Parameter declaration, Return type, Variable declaration, Type alias, Type cast or Type instantiation, as GoLand splits it.
  - "trait reference" → Type constraint in bounds, Supertype in `impl Trait for T`.
  - "init struct" → Struct initialization, "init field" → Field initialization, "field" → Field access, "use" → Import, "macro call" → Macro call, "variable binding" and struct patterns → Pattern.
- **Path qualifiers** take the type of the whole path, as intellij-rust does: `Money` in `Money::from_cents(..)` is a Call, `model` in `model::Thing` inside a field type is a Field declaration.
- **`dyn Trait` and `impl Trait`** are Type constraint wherever they appear, including parameter and return positions.
- **Shorthand `T { a }`** is Field initialization for both the field and the local it reads.
- **Field writes:** the draft gave every `x.f` the type Field access. An assignment target now captures `write` instead, so it reaches Value write as in GoLand; reads stay Field access, as intellij-rust's "field".
- **Render size:** R1 uses a 70-column editor like V4, so there is no preview, but 36 rows: the Money tree has 30 rows.
