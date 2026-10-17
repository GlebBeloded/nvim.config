## 1. Rust query and language facet
Scenarios: `references: Rust query classifies every usage type`, `references: Rust usages in production and test code`
- [x] 1.1 Write the test `references: Rust query classifies every usage type` in `tests/unit/languages/test_contract.lua` and tighten `references: Rust usages in production and test code` in `tests/integration/references/test_languages.lua`, driving the installed Rust parser and real `gr` mapping against populated fixtures; run `make test FILE=tests/unit/languages/test_contract.lua CASE="Rust query classifies every usage type"` and `make test FILE=tests/integration/references/test_languages.lua CASE="Rust usages in production and test code"` and see them fail
- [x] 1.2 Add `queries/rust/usages.scm` from the verified draft and set `references.usage_types = true` in `lua/gleb/languages/rust/init.lua`
- [x] 1.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Rust query classifies every usage type"` and `make test FILE=tests/integration/references/test_languages.lua CASE="Rust usages in production and test code"` and see them pass

## 2. Rust struct and field usages
Scenarios: `references: gr classifies Rust struct usages`, `references: gr classifies Rust field usages`
- [x] 2.1 Write the tests `references: gr classifies Rust struct usages` and `references: gr classifies Rust field usages` in `tests/integration/references/test_kind.lua`, driving the real `gr` mapping with rust-analyzer attached and quiescent in a populated `rustproj` fixture, and run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Rust struct usages"` and `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Rust field usages"` and see them fail
- [x] 2.2 Extend `rustproj` in `tests/fixtures/build.sh` with the `Money` files, module declarations and manifest entry specified by design Decision 7
- [x] 2.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Rust struct usages"` and `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Rust field usages"` and see them pass

## 3. Rust usage-type grouping render
Scenarios: `references: Rust struct usages are grouped by usage type`
- [x] 3.1 Write the test `references: Rust struct usages are grouped by usage type` in `tests/screen/references/test_view.lua`, driving the real `gr` mapping on `Money` in the populated `rustproj` fixture at 70x36, and run `make test FILE=tests/screen/references/test_view.lua CASE="Rust struct usages are grouped by usage type"` and see it fail
- [x] 3.2 Make the smallest fixture or query correction needed for the screen to match approved render "Proposed R1 — usage types of a Rust struct"
- [x] 3.3 Run `make test FILE=tests/screen/references/test_view.lua CASE="Rust struct usages are grouped by usage type"` and see it pass
- [x] 3.4 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="A missing usages query breaks the contract"`, `make quick` and `make check`

## Agent decisions

- Keep numbered rows 11–34 in approved R1 by adding trailing blank fixture lines; this preserves Rust behavior and every manifest location.
