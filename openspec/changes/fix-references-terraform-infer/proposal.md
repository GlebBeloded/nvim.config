## Why

Kind: bug

`require("gleb.references.scope").is_test("main.tftest.hcl")` returns false: with no filetype given,
`vim.filetype.match` names `*.tftest.hcl` `hcl` and `*.tf` `tf`, never `terraform`, so the Terraform
conventions in `PATTERNS` never apply. `infra/tests/plan.tftest.hcl` passes only through the generic
`tests` segment. The LSP config already lists the filetypes as `{ "terraform", "tf", "hcl" }`.

## Evidence

- lua/gleb/references/scope.lua:16 keys Terraform patterns only as `terraform`
- lsp/config/terraform/init.lua:7 attaches terraformls to `terraform`, `tf`, `hcl`
- headless probe on auto 073520c: `is_test("main.tftest.hcl")` → false, `is_test("infra/tests/plan.tftest.hcl")` → true

## What Changes

- Terraform conventions apply to the `tf` and `hcl` filetypes (and to paths inferred as them).
- The unit test asks the inferred (no filetype) question for `main.tftest.hcl` and `main.tf`.

## Impact

- lua/gleb/references/scope.lua
- tests/unit/references/test_scope.lua
