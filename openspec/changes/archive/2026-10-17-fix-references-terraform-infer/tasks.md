## 1. Classify inferred Terraform paths
Scenarios: `references: Generic and inferred test paths`
- [x] 1.1 Extend `tests/unit/references/test_scope.lua` so the real `require("gleb.references.scope").is_test` entry point classifies `main.tftest.hcl` and `main.tf` without an explicit filetype, then run `make test FILE=tests/unit/references/test_scope.lua CASE="Generic and inferred test paths"` and see the new assertion fail
- [x] 1.2 Map the `tf` and `hcl` filetypes to the Terraform test conventions in `lua/gleb/references/scope.lua`
- [x] 1.3 Run `make test FILE=tests/unit/references/test_scope.lua CASE="Generic and inferred test paths"` and see it pass

## Agent decisions

- Share one Terraform pattern list across `terraform`, `tf`, and `hcl` so their conventions cannot drift.
