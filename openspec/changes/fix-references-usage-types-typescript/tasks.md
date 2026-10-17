## 1. Queries and case table

Scenarios: `references: TypeScript query classifies every usage type`, `references: Every query capture is in the catalogue`, `languages: Every configured language meets the contract`

- [ ] 1.1 Port the TypeScript, TSX and JavaScript suites of `drafts/cases.lua` into `tests/unit/references/usage_cases/js.lua`, with their sources from `drafts/fixtures/usages.{ts,tsx,js}` in `tests/unit/references/usage_cases/js/`. Rename the expected ids per design Decision 1. Flip the `js` facet's `references.usage_types` to `true`. Run the shared usage-case driver from `languages-registry` and `make test FILE=tests/unit/languages/test_contract.lua`, and see them fail for `js`.
- [ ] 1.2 Add `queries/ecma/usages.scm`, `queries/javascript/usages.scm`, `queries/typescript/usages.scm`, `queries/tsx/usages.scm` and `queries/ts_angle_cast/usages.scm` from `drafts/queries`. Keep the `; inherits:` lines and rename captures per Decision 1 (`type_argument` → `type_instantiation`, `local_declaration` → `variable_declaration`, `catch_declaration` → `catch`). Regenerate `typescript` with `drafts/gen_ts.py`, or hand-maintain it.
- [ ] 1.3 Make the catalogue test resolve the pseudo-languages `ecma` and `ts_angle_cast` through the files that inherit them (design Decision 2).
- [ ] 1.4 Run both files and `make test FILE=tests/unit/references/test_usage_types.lua`, and see them pass

## 2. Parser per filetype and type alias targets

Scenarios: `references: TSX and TypeScript buffers use their own parser`, `references: TypeScript type alias targets keep their usage types`

- [ ] 2.1 Write the parser scenario in tests/unit/references/test_kind_ts.lua and the type alias scenario in tests/integration/references/test_kind.lua (temporary vtsls project), and see them fail
- [ ] 2.2 Confirm the query runner picks `tsx` for `typescriptreact` and `javascript` for `javascriptreact` through `vim.treesitter.language.get_lang` (design Decision 3); fix the runner only if it doesn't
- [ ] 2.3 Confirm the template's `type_identifier` upgrade covers vtsls's Variable report for `type Amount` (design Decision 4); fix `request_target_kind` only if it doesn't
- [ ] 2.4 Run both files, the contract test and `make types`, and see them pass

## 3. Fixture and gr classification

Scenarios: `references: gr classifies TypeScript class usages`, `references: gr classifies TypeScript method usages as calls`, `references: TypeScript usages in production and test files`

- [ ] 3.1 Extend `tsproj()` in tests/fixtures/build.sh: add `src/money.ts`, `src/wallet.ts` and `src/money.test.ts` with the exact text of design Decision 6, the second `node --check` loop, and the `Money` manifest entry. Write the two `gr` scenarios in tests/integration/references/test_kind.lua, waiting until vtsls's references reply holds every manifest usage (Decision 5). See them fail.
- [ ] 3.2 Fix any pattern or ordering gap the scenarios expose, keeping every case of task 1 green
- [ ] 3.3 Run `make test FILE=tests/integration/references/test_kind.lua` and `make test FILE=tests/integration/references/test_languages.lua`, and see them pass

## 4. Screen

Scenarios: `references: TypeScript class usages are grouped by usage type`

- [ ] 4.1 Add the P1 case to tests/screen/references/test_view.lua at 70x50, with a reference screenshot from the approved render (real glyphs where the render has stand-ins; attribute blocks per the mask groups). See it fail.
- [ ] 4.2 Make it pass, then compare `make render` of the case with `renders/ts_p1_class.ansi` and `make colorize FILE=openspec/changes/fix-references-usage-types-typescript/design.md`
- [ ] 4.3 Run `make check`
