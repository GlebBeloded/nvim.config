## 1. Discover language modules

Scenarios: `languages: Every configured language is registered`, `languages: A filetype resolves to its language`, `languages: A new language folder is discovered`

- [x] 1.1 Write the three cases in `tests/unit/languages/test_registry.lua`, calling `all()` and `for_filetype()` against the configured runtimepath and a temporary complete Zig language module, and see them fail
- [x] 1.2 Add the typed registry in `lua/gleb/languages/types.lua` and `lua/gleb/languages/init.lua`, including discovery, lookup and resettable module state, then add the eleven language folders
- [x] 1.3 Run `make test FILE=tests/unit/languages/test_registry.lua CASE="Every configured language is registered"`, `make test FILE=tests/unit/languages/test_registry.lua CASE="A filetype resolves to its language"`, and `make test FILE=tests/unit/languages/test_registry.lua CASE="A new language folder is discovered"`, then run `make types` and see them pass

## 2. Enforce the facet API

Scenarios: `languages: Registered facets`, `languages: A language missing a facet fails at startup`, `languages: A disabled facet needs a reason`, `languages: A new facet must be answered by every language`

- [x] 2.1 Write the four cases in `tests/unit/languages/test_registry.lua`, registering facets and validating complete and deliberately incomplete language specs through the real registry API, and see them fail
- [x] 2.2 Implement `register_facet()`, `facet()` and startup validation, including unknown keys, non-empty disabled reasons and validator errors
- [x] 2.3 Run `make test FILE=tests/unit/languages/test_registry.lua CASE="Registered facets"`, `make test FILE=tests/unit/languages/test_registry.lua CASE="A language missing a facet fails at startup"`, `make test FILE=tests/unit/languages/test_registry.lua CASE="A disabled facet needs a reason"`, and `make test FILE=tests/unit/languages/test_registry.lua CASE="A new facet must be answered by every language"`, then run `make smoke` and see them pass

## Agent decisions

- Facet validators return an optional error string, which preserves the validator's exact diagnostic while a `nil` return means valid.
- LSP and treesitter validators require their list fields to be Lua lists, catching malformed facet data at feature registration.

## 3. Drive LSP and treesitter from facets

Scenarios: `languages: Enabled LSP servers are unchanged`, `languages: Installed parsers are unchanged`

- [x] 3.1 Write the two cases in `tests/integration/languages/test_setup.lua`, loading the full config and observing the real server-enable calls and populated treesitter installer list, and see them fail against the registry contract
- [x] 3.2 Move each language's LSP data into its language folder, unify `lsp_name` and `lsp_names` as `servers`, then make `lua/gleb/lsp/config/init.lua` and `lua/gleb/treesitter.lua` register and consume their facets
- [x] 3.3 Run `make test FILE=tests/integration/languages/test_setup.lua CASE="Enabled LSP servers are unchanged"`, `make test FILE=tests/integration/languages/test_setup.lua CASE="Installed parsers are unchanged"`, and `make test FILE=tests/integration/lsp/test_config.lua`, then run `make smoke` and see them pass

## 4. Drive references from its facet

Scenarios: `languages: Test patterns come from the facet`, `languages: Terraform queries inherit the HCL query`

- [ ] 4.1 Write the two cases in `tests/unit/languages/test_references.lua`, changing the registry's Go facet before calling `is_test()` and classifying a populated Terraform buffer through the real query runner, and see them fail
- [ ] 4.2 Register the references facet and make `lua/gleb/references/scope.lua`, `kind.lua` and `kind_ts.lua` read test patterns, parser languages, write access and target kinds from it
- [ ] 4.3 Run `make test FILE=tests/unit/languages/test_references.lua CASE="Test patterns come from the facet"` and `make test FILE=tests/unit/languages/test_references.lua CASE="Terraform queries inherit the HCL query"`, then run `make test FILE=tests/unit/references/test_scope.lua`, `make test FILE=tests/integration/references/test_kind.lua`, and `make test FILE=tests/screen/references/test_view.lua CASE="Struct usages are grouped by usage type"` and see them pass

## 5. Check every language contract

Scenarios: `languages: Every configured language meets the contract`, `languages: A missing usages query breaks the contract`, `languages: A missing fixture breaks the contract`, `languages: A stale queued reason breaks the contract`, `languages: Each references facet gets a gr run`

- [ ] 5.1 Write the five cases in `tests/unit/languages/test_contract.lua`; make the language-suite case enumerate the registry and drive the real `gr` mapping over each enabled facet's built fixture and symbol in `tests/integration/references/test_languages.lua`, and see the new assertions fail
- [ ] 5.2 Add the pure contract checker, per-language query case tables and data-driven references suite; reject missing or invalid queries, captures, cases, fixtures, symbols and queued changes
- [ ] 5.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Every configured language meets the contract"`, `make test FILE=tests/unit/languages/test_contract.lua CASE="A missing usages query breaks the contract"`, `make test FILE=tests/unit/languages/test_contract.lua CASE="A missing fixture breaks the contract"`, `make test FILE=tests/unit/languages/test_contract.lua CASE="A stale queued reason breaks the contract"`, and `make test FILE=tests/unit/languages/test_contract.lua CASE="Each references facet gets a gr run"`, then run `make test FILE=tests/integration/references/test_languages.lua` and see them pass
- [ ] 5.4 Add architecture rule 1.10 and the `languages/` module-map row to `docs/architecture.md`, then run `make check`
