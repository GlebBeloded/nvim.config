## 1. Omit the unavailable Terraform formatter
Scenarios: `lsp: Terraform formatter is omitted when Terraform is unavailable`
- [x] 1.1 Write the test `lsp: Terraform formatter is omitted when Terraform is unavailable` in tests/integration/lsp/test_config.lua and see it fail
- [x] 1.2 Return no `terraform_fmt` source from the Terraform language config when `vim.fn.executable("terraform")` is not `1`
- [x] 1.3 Run `make test FILE=tests/integration/lsp/test_config.lua CASE="Terraform formatter is omitted when Terraform is unavailable"` and see it pass
