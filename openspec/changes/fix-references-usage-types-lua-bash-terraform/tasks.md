## 1. Lua query cases

Scenarios: `references: Lua query classifies every usage type`

- [x] 1.1 Port the Lua cases from `drafts/verify.lua` to `tests/unit/references/usage_cases/lua.lua` with their real sources under `usage_cases/lua/`, add the scenario to the shared driver in `tests/unit/languages/test_contract.lua`, run `make test FILE=tests/unit/languages/test_contract.lua CASE="Lua query classifies every usage type"`, and see it fail against the write/read-only query
- [x] 1.2 Replace `queries/lua/usages.scm` with the verified draft using the catalogue ids in design.md Decision 1
- [x] 1.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Lua query classifies every usage type"` and see it pass; also run the Lua cases of `references: Treesitter fallback classifies writes where a parser exists`

## Agent decisions

- Keep draft `false` values as `query_expected`, while `expected` uses the classifier's documented `read` fallback so negative positions remain distinguishable in the case data.
- Declare and consume the draft fixture's synthetic globals on existing lines so it stays lint-clean without moving any verified position.

## 2. Bash query cases

Scenarios: `references: Bash query classifies every usage type`

- [x] 2.1 Port the Bash cases from `drafts/verify.lua` to `tests/unit/references/usage_cases/shell.lua` with their real sources under `usage_cases/shell/`, add the scenario to the shared driver in `tests/unit/languages/test_contract.lua`, run `make test FILE=tests/unit/languages/test_contract.lua CASE="Bash query classifies every usage type"`, and see it fail against the write/read-only query
- [x] 2.2 Replace `queries/bash/usages.scm` with the verified draft using the catalogue ids in design.md Decision 1
- [x] 2.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Bash query classifies every usage type"` and see it pass; also run the Bash cases of `references: Treesitter fallback classifies writes where a parser exists`

## 3. Terraform query cases

Scenarios: `references: Terraform query classifies every usage type`

- [ ] 3.1 Port the Terraform cases from `drafts/verify.lua` to `tests/unit/references/usage_cases/terraform.lua` with their real sources under `usage_cases/terraform/`, add the scenario to the shared driver in `tests/unit/languages/test_contract.lua` for both the `hcl` and `terraform` parsers, run `make test FILE=tests/unit/languages/test_contract.lua CASE="Terraform query classifies every usage type"`, and see it fail against the write/read-only query
- [ ] 3.2 Replace `queries/hcl/usages.scm` with the verified draft after applying design.md Decisions 1 and 3; keep `queries/terraform/usages.scm` as `; inherits: hcl`
- [ ] 3.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Terraform query classifies every usage type"` and see it pass; also run `references: HCL fallback classifies variable labels and traversals` and `references: Every query capture is in the catalogue`

## 4. Enable the language facets

Scenarios: `languages: Every configured language meets the contract`, `languages: A missing usages query breaks the contract`

- [ ] 4.1 Tighten `tests/unit/languages/test_contract.lua` so the configured-language case requires Lua, Shell and Terraform among the enabled usage-type case tables; run `make test FILE=tests/unit/languages/test_contract.lua CASE="Every configured language meets the contract"` and see it fail while their facets remain disabled
- [ ] 4.2 Set `references.usage_types = true` in `lua/gleb/languages/{lua,shell,terraform}/init.lua`
- [ ] 4.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Every configured language meets the contract"` and `make test FILE=tests/unit/languages/test_contract.lua CASE="A missing usages query breaks the contract"` and see both pass

## 5. Lua references through the real picker

Scenarios: `references: gr classifies Lua function calls and redefinitions`

- [ ] 5.1 Write the scenario in `tests/integration/references/test_kind.lua`, driving `gr` through the real picker on `apply` with lua_ls and populated fixture data, and see it fail
- [ ] 5.2 Add the `luaproj` files and `apply` manifest entry from design.md Decision 7 to `tests/fixtures/build.sh`, and make appended current-file write highlights pass through the same query-first classification as listed usages if the template does not already
- [ ] 5.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Lua function calls and redefinitions"` and see it pass; run the existing Lua language and local-usage scenarios in `tests/integration/references/{test_languages,test_kind}.lua`

## 6. Bash references through the real picker

Scenarios: `references: gr classifies Bash exports, writes and reads`, `references: gr classifies Bash function usages as calls`

- [ ] 6.1 Write both scenarios in `tests/integration/references/test_kind.lua`, driving `gr` through the real picker on `rate` and `total` with bashls and populated fixture data, and see them fail
- [ ] 6.2 Add the `bashproj` files and `rate` manifest entry from design.md Decision 7 to `tests/fixtures/build.sh`, add the new scripts to `bash -n`, and change no existing fixture line
- [ ] 6.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Bash exports, writes and reads"` and `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Bash function usages as calls"` and see both pass; run the existing Bash language and variable-usage scenarios

## 7. Terraform references through the real picker

Scenarios: `references: gr classifies Terraform module variable usages`, `references: gr classifies Terraform module usages`

- [ ] 7.1 Write both scenarios in `tests/integration/references/test_kind.lua`, driving `gr` through the real picker on `cidr` and `vpc` with terraform-ls and populated fixture data; open `network.tf` before `net/main.tf` for `cidr`, wait for the indexed module argument, and see the tests fail
- [ ] 7.2 Add the `tfproj` files and `cidr`/`vpc` manifest entries from design.md Decision 7 to `tests/fixtures/build.sh`, changing no existing fixture line
- [ ] 7.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Terraform module variable usages"` and `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Terraform module usages"` and see both pass; run the existing Terraform language, variable-usage and block-target scenarios

## 8. Lua approved render

Scenarios: `references: Lua usage types match the approved render`

- [ ] 8.1 Write the `70x24` screen scenario in `tests/screen/references/test_view.lua`, driving `gr` on `apply` with the real picker, lua_ls and populated fixture data, and see it fail against the approved screenshot
- [ ] 8.2 Add the Proposed L1 reference screenshot and attribute block from design.md
- [ ] 8.3 Run `make test FILE=tests/screen/references/test_view.lua CASE="Lua usage types match the approved render"` and see it pass; compare `make render` with `renders/lua_l1_proposed.ansi`

## 9. Bash approved render

Scenarios: `references: Bash usage types match the approved render`

- [ ] 9.1 Write the `70x24` screen scenario in `tests/screen/references/test_view.lua`, driving `gr` on `rate` with the real picker, bashls and populated fixture data, and see it fail against the approved screenshot
- [ ] 9.2 Add the Proposed B1 reference screenshot and attribute block from design.md
- [ ] 9.3 Run `make test FILE=tests/screen/references/test_view.lua CASE="Bash usage types match the approved render"` and see it pass; compare `make render` with `renders/bash_b1_proposed.ansi`

## 10. Terraform approved render

Scenarios: `references: Terraform usage types match the approved render`

- [ ] 10.1 Write the `70x24` screen scenario in `tests/screen/references/test_view.lua`, driving `gr` on `vpc` with the real picker, terraform-ls and populated fixture data, and see it fail against the approved screenshot
- [ ] 10.2 Add the Proposed H1 reference screenshot and attribute block from design.md
- [ ] 10.3 Run `make test FILE=tests/screen/references/test_view.lua CASE="Terraform usage types match the approved render"` and see it pass; compare `make render` with `renders/terraform_h1_proposed.ansi`, then run `make check`
