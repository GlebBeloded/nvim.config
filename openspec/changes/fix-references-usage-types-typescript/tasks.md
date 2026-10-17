## 1. Enable the JavaScript references facet

Scenarios: `languages: Every configured language meets the contract`

- [x] 1.1 In `tests/unit/languages/test_contract.lua`, extend the existing query-case-table coverage with the populated `js` case table and set `lua/gleb/languages/js/init.lua` `references.usage_types = true`; run `make test FILE=tests/unit/languages/test_contract.lua CASE="Every configured language meets the contract"` and see it fail because the JavaScript, TypeScript and TSX usage queries are missing
- [x] 1.2 Add the five parser query files and JavaScript case table described by design Decisions 1, 2 and 7, using the real `gleb.references.kind_ts.classify` entry point with the installed parsers
- [x] 1.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Every configured language meets the contract"` and see it pass

## Agent decisions

- The JavaScript case module exposes TypeScript as its contract-compatible top-level suite and all three parser suites under `suites`, preserving the existing contract shape while covering each configured parser.
- Query classification stays capture-only; production and the populated case table share the pure target-kind refinement function.
- The catalogue test resolves `ecma` through `javascript` and `ts_angle_cast` through `typescript`, their direct real-parser inheritors, so Neovim compiles each pseudo-language capture without a nonexistent parser.
- The fixture manifest generator records every identifier occurrence on a line, so the two `Money` static-member lines retain both the annotation and member-object locations; the real references exposed no query gap.

## 2. Classify TypeScript, TSX and JavaScript syntax

Scenarios: `references: TypeScript query classifies every usage type`, `references: TSX and TypeScript buffers use their own parser`, `references: TypeScript type alias targets keep their usage types`

- [x] 2.1 Write `references: TypeScript query classifies every usage type` in `tests/unit/languages/test_contract.lua`, `references: TSX and TypeScript buffers use their own parser` in `tests/unit/references/test_kind_ts.lua`, and `references: TypeScript type alias targets keep their usage types` in `tests/integration/references/test_kind.lua`; drive the populated case table and real `gr` mapping, then run `make test FILE=tests/unit/languages/test_contract.lua CASE="TypeScript query classifies every usage type"`, `make test FILE=tests/unit/references/test_kind_ts.lua CASE="TSX and TypeScript buffers use their own parser"`, and `make test FILE=tests/integration/references/test_kind.lua CASE="TypeScript type alias targets keep their usage types"` and see them fail
- [x] 2.2 Keep parser selection through `vim.treesitter.language.get_lang`, and apply the existing `type_identifier` target-kind upgrade to vtsls type aliases; change the classifier only if either scenario exposes a gap
- [x] 2.3 Run the three focused commands from 2.1 and see them pass

## 3. Validate every query capture

Scenarios: `references: Every query capture is in the catalogue`

- [x] 3.1 Tighten `tests/unit/references/test_usage_types.lua` so the real catalogue test resolves the parserless `ecma` and `ts_angle_cast` query bases through their inheriting parser queries; run `make test FILE=tests/unit/references/test_usage_types.lua CASE="Every query capture is in the catalogue"` and see it fail on the new query files
- [x] 3.2 Make the smallest test-driver change needed to validate inherited captures without requiring nonexistent pseudo-language parsers
- [x] 3.3 Run `make test FILE=tests/unit/references/test_usage_types.lua CASE="Every query capture is in the catalogue"` and see it pass

## 4. Classify real vtsls references

Scenarios: `references: gr classifies TypeScript class usages`, `references: gr classifies TypeScript method usages as calls`

- [x] 4.1 Extend the populated `tsproj` fixture and manifest with the exact files and locations from design Decision 6, write both scenarios in `tests/integration/references/test_kind.lua`, drive the real `gr` mapping after vtsls returns all manifest locations, and run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies TypeScript"` and see them fail
- [x] 4.2 Fix only query pattern or precedence gaps exposed by the real references, preserving all unit cases
- [x] 4.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies TypeScript"` and see both scenarios pass

## 5. Group TypeScript class usages on screen

Scenarios: `references: TypeScript class usages are grouped by usage type`

- [x] 5.1 Add the 70x50 P1 case to `tests/screen/references/test_view.lua`, drive the real `gr` mapping against the populated `tsproj` data, and run `make test FILE=tests/screen/references/test_view.lua CASE="TypeScript class usages are grouped by usage type"` with the approved P1 screenshot expectation to see it fail
- [x] 5.2 Make the query-backed classification produce the approved render without changing the existing tree layout, then compare `make render CASE=ts_p1_class COLUMNS=70 LINES=50` with `renders/ts_p1_class.ansi`
- [x] 5.3 Run `make test FILE=tests/screen/references/test_view.lua CASE="TypeScript class usages are grouped by usage type"` and see it pass
