## 1. Registry and facets

Scenarios: `languages: Every configured language is registered`, `languages: A filetype resolves to its language`, `languages: A new language folder is discovered`, `languages: Registered facets`, `languages: A language missing a facet fails at startup`, `languages: A disabled facet needs a reason`, `languages: A new facet must be answered by every language`

- [ ] 1.1 Write the scenarios in tests/unit/languages/test_registry.lua and see them fail
- [ ] 1.2 Add `lua/gleb/languages/types.lua`, `init.lua` (discovery, `for_filetype`, `facet`, `register_facet`, `validate`, `M.state`/`M.reset`) and the eleven language folders (design Decisions 1, 2 and 5)
- [ ] 1.3 Run `make test FILE=tests/unit/languages/test_registry.lua` and `make types` and see them pass

## 2. LSP and treesitter read the registry

Scenarios: `languages: Enabled LSP servers are unchanged`, `languages: Installed parsers are unchanged`

- [ ] 2.1 Write the two scenarios in tests/integration/languages/test_setup.lua and see them fail
- [ ] 2.2 Move each `lsp/config/<lang>/init.lua` into `languages/<lang>/lsp.lua` (`lsp_name`/`lsp_names` → `servers`). `lsp/config/init.lua` registers the `lsp` facet and iterates it; `treesitter.lua` registers `treesitter` and builds the list from editor parsers plus facets.
- [ ] 2.3 Run `make test FILE=tests/integration/languages/test_setup.lua`, `make test FILE=tests/integration/lsp/test_config.lua` and `make smoke`, and see them pass

## 3. References facet and contract

Scenarios: `languages: Test patterns come from the facet`, `languages: Terraform queries inherit the HCL query`, `languages: Every configured language meets the contract`, `languages: A missing usages query breaks the contract`, `languages: A missing fixture breaks the contract`, `languages: A stale queued reason breaks the contract`, `languages: Each references facet gets a gr run`, `references: Go test paths`, `references: TypeScript and JavaScript test paths`, `references: Python test paths`, `references: Lua test paths`, `references: Rust test paths`, `references: Bash test paths`, `references: Terraform test paths`

- [ ] 3.1 Write the scenarios in tests/unit/languages/test_contract.lua and tests/unit/references/test_scope.lua. Move the Go query cases into `tests/unit/references/usage_cases/go.lua`, run by a shared driver. Make `tests/integration/references/test_languages.lua` iterate the registry. See the new cases fail.
- [ ] 3.2 Add `lua/gleb/languages/contract.lua` (design Decision 4). `references/init.lua` registers the facet; `scope.lua`, `kind.lua` and `kind_ts.lua` read it instead of their filetype tables.
- [ ] 3.3 Run `make test FILE=tests/unit/languages/test_contract.lua`, the scope test and the languages suite, then `make check`
- [ ] 3.4 Add rule 1.10 and the `languages/` row of the module map to `docs/architecture.md`
