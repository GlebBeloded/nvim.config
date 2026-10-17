## 1. Rust query, case table and facet

Scenarios: `references: Rust query classifies every usage type`, `references: Rust usages in production and test code`

- [ ] 1.1 Add `tests/unit/references/usage_cases/rust.lua` from `drafts/expected.lua` and its source `tests/unit/references/usage_cases/rust/usages.rs` from `drafts/fixtures/usages.rs` (design Decision 6). Add the `Macro argument` rows to the Rust case of tests/integration/references/test_languages.lua (design Decision 8). See the case driver and that case fail: no `rust` query, and the facet is still disabled
- [ ] 1.2 Add `queries/rust/usages.scm` from `drafts/queries/rust/usages.scm` (design Decision 1; already in catalogue ids, including the field `write` patterns)
- [ ] 1.3 Set `references.usage_types = true` in `lua/gleb/languages/rust/init.lua` (design Decision 5)
- [ ] 1.4 Run the case driver, the catalogue test, `tests/unit/languages/test_contract.lua` and `make test FILE=tests/integration/references/test_languages.lua`, and see them pass

## 2. Fixture and gr through rust-analyzer

Scenarios: `references: gr classifies Rust struct usages`, `references: gr classifies Rust field usages`

- [ ] 2.1 Write the two `gr` scenarios in tests/integration/references/test_kind.lua, opening the fixture through the existing rust-analyzer readiness wait (`experimental/serverStatus` quiescent), and see them fail: the fixture has no `Money`.
- [ ] 2.2 Extend `rustproj` in tests/fixtures/build.sh: append the two `pub mod` lines to `src/lib.rs`, add `src/money.rs`, `src/ledger.rs` and `tests/money.rs` with the exact text of design Decision 7, and add the `Money` manifest entry
- [ ] 2.3 Run `make test FILE=tests/integration/references/test_kind.lua` and `make test FILE=tests/integration/references/test_languages.lua`, and see every scenario in them pass, the old ones included

## 3. Screen

Scenarios: `references: Rust struct usages are grouped by usage type`

- [ ] 3.1 Add the R1 screen test to tests/screen/references/test_view.lua at 70x36, with real glyphs where the render has stand-ins and attribute blocks per the mask groups, and see it fail
- [ ] 3.2 Make `make test-screen` pass and commit the screenshot. Compare `make render` with `renders/type_r1_rust_struct.ansi`.
- [ ] 3.3 Run `make check`
