## Why

Kind: bug
Depends: languages-registry

Find Usages has GoLand's usage types for Go only. TypeScript and JavaScript have no `usages` query, so a class's imports, `new` calls, `extends` clauses, casts, type checks and annotations are all `Unclassified` and the view shows them as one flat list. WebStorm and GoLand classify the same usages with JetBrains' `JSUsageTypeProvider`. The user wants that observability for every configured language.

## Evidence

- Root cause: `lua/gleb/languages/js/init.lua:38` disables `references.usage_types` for the `js` language, and `lua/gleb/references/kind_ts.lua:48`-`60` can only apply syntactic usage types when the buffer parser has a loadable `usages` query. The configured `javascript`, `typescript` and `tsx` parsers have no such repo query, so type targets fall through to `unclassified`.
- `gr` on `Money` in the extended `tsproj` fixture (design.md, Decision 6), checked with vtsls 0.3.0 (TypeScript 5.9.3): the server returns 15 usages in `src/money.ts`, `src/wallet.ts` and `src/money.test.ts`, each range starting at the `Money` identifier.
  - Today every one of them is `read`, except the two `import { Money }` specifiers, which tsserver marks `isWriteAccess`.
  - Once `fix-references-usage-types` lands, `Money` is a `type` target, which never gets write/read, and no TypeScript query exists. So all 15 are `Unclassified`, and the view has no usage type level (render "Current — class usages").
- JetBrains' classifier for JavaScript and TypeScript (`JSUsageTypeProvider`, decompiled from the local GoLand install) has these types:
  - Usage in import, Usage in function call, New instance creation
  - Usage in extends/implements clause, Usage in cast target type (`as`), Usage in instanceof (`instanceof` and the type predicate `is`), Class static member access
  - Method parameter declaration, Catch clause parameter declaration, Method return type
  - Field declaration and Local variable declaration
  - Usage in string constants
  - Read/write comes from `JSReadWriteAccessDetector`.
- `languages-registry` leaves the `js` language's `references.usage_types` as `{ disabled = "queued: fix-references-usage-types-typescript" }`.
- A verified draft is in `drafts/`: `ecma`, `javascript`, `typescript`, `tsx` and `ts_angle_cast` queries, case fixtures and a verifier. With the template's target-kind rules and catalogue ids, its 133 TypeScript, TSX and JavaScript cases pass on Neovim 0.12.5 with the installed parsers.

## What Changes

- **TypeScript, TSX and JavaScript queries.** New `queries/{ecma,javascript,typescript,tsx,ts_angle_cast}/usages.scm`, ported from `drafts/queries` with the draft ids renamed to catalogue ids (design.md, Decision 1):
  - `ecma` holds the patterns all three grammars share. `javascript` and `typescript` inherit it, and `tsx` inherits `typescript`.
  - The `<T>x` cast lives in `ts_angle_cast`, which only `typescript` inherits, because the tsx grammar has no such node.
- **Types:** Call, Import, New instance creation, Static member access, Supertype (`extends`/`implements`), Type cast (`as`, `satisfies`, `<T>x`), Type check (`instanceof`, `x is T`), Field declaration, Variable declaration, Parameter declaration, Catch clause, Return type, Type instantiation (generic arguments) and Type alias (`type A = T`).
  - Annotations are matched through pure type wrappers (arrays, generics, unions, intersections, tuples, `readonly`, qualified names) up to depth 4.
  - Static member access applies only when the target is a type (the template's target-kind rule).
- **Registry.** The `js` language's `references.usage_types` becomes `true`. No registry type changes: the query runner already uses each buffer filetype's own parser language (`languages-registry` Decision 6), so `typescriptreact` uses `tsx` (design.md, Decision 3).
- **Case table:** `tests/unit/references/usage_cases/js.lua`, with its sources in `tests/unit/references/usage_cases/js/`.
- **Fixture.** The `tsproj` fixture gains `src/money.ts`, `src/wallet.ts` and `src/money.test.ts`, and a `Money` manifest entry. New files only, so every existing line and manifest entry holds.
- **Render:** "Proposed P1 — TypeScript usage types of a class".

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `references`: added 'TypeScript usage types'.

## Impact

- Code:
  - New: `queries/ecma/usages.scm`, `queries/javascript/usages.scm`, `queries/typescript/usages.scm`, `queries/tsx/usages.scm`, `queries/ts_angle_cast/usages.scm`.
  - Changed:
    - `lua/gleb/languages/js/init.lua`: `usage_types = true`.
- Tests:
  - unit: `tests/unit/references/usage_cases/js.lua` and its three sources, run by the shared case driver. The catalogue test resolves the pseudo-languages `ecma` and `ts_angle_cast` through the files that inherit them.
  - integration: vtsls `gr` on `Money` and on `parse` in the extended `tsproj` fixture.
  - screen: P1.
- Fixture: `tests/fixtures/build.sh` `tsproj` (three new files and the `Money` manifest entry).
- Plugins: none. Core keymaps: none.
- Unchanged scenarios:
  - `languages: Requirement: References facet` still holds: the enabled `js` facet continues to take test patterns, write-access source, symbol-kind overrides and each query parser language from the registry contract.
  - `languages: A missing usages query breaks the contract` still holds: enabling the `js` facet requires a query for each configured parser language, and the existing missing-query diagnostic is unchanged.
  - `references: TypeScript usages in production and test files` still holds: the new files don't reference `total`, and the scenario names no type rows.
  - `references: gr classifies every TypeScript variable usage` still holds: `hits++` and `console.log(hits)` match no type pattern, so tsserver's write/read still decides.
  - `references: tsserver kinds classify a TypeScript variable` still holds: the same lines get no syntactic type.
  - `references: TypeScript and JavaScript test paths` still holds: the test patterns are unchanged.
  - `file-tree: gr keeps its global meaning in git status tree` still holds: the global `gr` mapping and its callback are untouched. Only the queries, the `js` facet and target-kind resolution change.
- Out of scope:
  - "Usage in string constants": servers don't return string locations.
  - JSX tag usages (`<Price />`). They stay unclassified, as in the draft.
  - Decorators, and `export` as its own type.
  - Svelte, Vue and other embedded scripts.

## Decision (user, 2026-10-17)

- "it is implemented, but lacking. Goland system is ALOT reacher. … I want goland-like observability over references, which is sueprior. … create a spec to fix it for all langauges."

## Decision (auditor, 2026-10-17, test and spec integrity)

- The P1 screen case asserts its whole colour mask (`expect_screen_colors`, legend from renders/ts_p1_class.ansi) like K1/T1, and its screenshot is regenerated only once the render matches renders/ts_p1_class.ansi; a self-created reference never stands in for the approved render.
- Usage-type refinement has one implementation, the one real `gr` uses; tests drive that path, never a test-only copy of the rules.
- An existing test keeps its expectation unless a spec scenario changes it: when live TS/JS queries change the no-tsserver fallback, that is a MODIFIED scenario with the new result, not a test that disables the queries.
- The TS/JS usage types stay a SHALL of their own (the 14 types and the per-filetype parser rule); tasks.md keeps its `make types`, `make check` and `make colorize` gates.

## Agent decisions

- **Mapping:** JetBrains' JS wording maps onto the GoLand-worded catalogue:
  - "Usage in extends/implements clause" → Supertype
  - "Usage in cast target type" → Type cast, which `satisfies` also gets
  - "Usage in instanceof" → Type check
  - "Class static member access" → Static member access
  - "Field / Local variable declaration" → Field declaration and Variable declaration
  - "Method parameter / Catch clause parameter declaration" → Parameter declaration and Catch clause
  - "Method return type" → Return type
- **Richer than JetBrains:**
  - Generic arguments are Type instantiation (GoLand's label).
  - `type A = T` is Type alias. The draft left it unclassified, so `drafts/gen_ts.py` and `drafts/cases.lua` gained it.
  - Re-exports `export { T } from "m"` are Import.
- **Precedence** follows the draft: the first pattern wins, and inherited files come first. So `Array<Money>` in an annotation is Type instantiation, not the annotation's type.
- **Fixture symbol:** the `js` facet keeps `total` as its smoke symbol. `Money` is a second manifest entry for the type scenarios.
- **Render size:** P1 is drawn at `70x50` instead of V4's `70x24`. Its 43 tree rows need that height to show without scrolling, and below 80 columns there is no preview.
