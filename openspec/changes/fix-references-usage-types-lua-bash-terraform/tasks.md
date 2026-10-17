## 1. Case tables and queries

Scenarios: `references: Lua query classifies every usage type`, `references: Bash query classifies every usage type`, `references: Terraform query classifies every usage type`, `references: Treesitter fallback classifies writes where a parser exists`, `references: HCL fallback classifies variable labels and traversals`, `references: Every query capture is in the catalogue`

- [ ] 1.1 Port `drafts/verify.lua` into `tests/unit/references/usage_cases/lua.lua`, `shell.lua` and `terraform.lua`, with the draft fixtures copied to `usage_cases/{lua,shell,terraform}/`. Rename the ids per design.md Decision 1 and apply the HCL expectation changes in Decision 3. Drop the `parity()` checks. Run the terraform table with both `hcl` and `terraform`. Run them with the shared case driver and see them fail against the write/read-only queries.
- [ ] 1.2 Replace `queries/lua/usages.scm`, `queries/bash/usages.scm` and `queries/hcl/usages.scm` with the draft queries:
  - rename `local_declaration` to `variable_declaration`;
  - drop the `variable_`, `module_`, `output_`, `resource_` and `data_declaration` label patterns, keeping the `variable` label's `write` pattern;
  - keep `queries/terraform/usages.scm` as `; inherits: hcl`.
- [ ] 1.3 Run the three case tables, `tests/unit/references/test_kind_ts.lua` (or its query-runner successor) and the catalogue test, and see them pass

## 2. Registry

Scenarios: `languages: Every configured language meets the contract`

- [ ] 2.1 Flip `references.usage_types` to `true` in `lua/gleb/languages/{lua,shell,terraform}/init.lua` and see the contract test fail until the three case tables and queries from task 1 are in place.
- [ ] 2.2 Run `tests/unit/languages/test_contract.lua` and see it pass. Terraform's `target_kinds = { Class = "unknown" }` comes from `languages-registry`; this change adds no target-kind code.

## 3. Fixtures and gr through the real servers

Scenarios: `references: gr classifies Lua function calls and redefinitions`, `references: gr classifies Bash exports, writes and reads`, `references: gr classifies Bash function usages as calls`, `references: gr classifies Terraform module variable usages`, `references: gr classifies Terraform module usages`, `references: Lua usages in production and spec files`, `references: Bash usages in production and test scripts`, `references: Terraform variable usages`, `references: gr classifies every Lua local usage`, `references: gr classifies every Bash variable usage`, `references: gr classifies every Terraform variable usage`, `references: Terraform blocks are not type targets`

- [ ] 3.1 Write the five new scenarios in `tests/integration/references/test_kind.lua`. The `cidr` one opens `network.tf` before `net/main.tf` and waits until terraform-ls returns the module argument. See them fail.
- [ ] 3.2 Extend `luaproj`, `bashproj` and `tfproj` in `tests/fixtures/build.sh` with the new files and manifest symbols from design.md Decision 7, verbatim. Add the new Bash scripts to `bash -n`, and change no existing file or line.
- [ ] 3.3 Make current-file write highlights that `gr` appends go through the same classification order (design.md, Decision 5), if the template doesn't already.
- [ ] 3.4 Run `make test FILE=tests/integration/references/test_kind.lua` and `make test FILE=tests/integration/references/test_languages.lua`, and see every scenario pass, the existing ones included.

## 4. Screens

Scenarios: `references: Lua usage types match the approved render`, `references: Bash usage types match the approved render`, `references: Terraform usage types match the approved render`

- [ ] 4.1 Add screen tests in `tests/screen/references/test_view.lua` at `70x24` for Proposed L1, B1 and H1, with reference screenshots and attribute blocks per the mask groups (real glyphs where the render has stand-ins). See them fail.
- [ ] 4.2 Make them pass, compare `make render` with `renders/{lua_l1,bash_b1,terraform_h1}_proposed.ansi`, then run `make check`.
