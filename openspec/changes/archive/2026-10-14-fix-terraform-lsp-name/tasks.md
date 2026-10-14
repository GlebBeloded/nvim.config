## 1. Register the Terraform language server under its nvim-lspconfig name
Scenarios: `lsp: Terraform files use terraformls`
- [x] 1.1 Write the test `lsp: Terraform files use terraformls` in tests/integration/lsp/test_config.lua and see it fail
- [x] 1.2 Change the Terraform language configuration to register and enable `terraformls`
- [x] 1.3 Run `make test FILE=tests/integration/lsp/test_config.lua CASE="Terraform files use terraformls"` and see it pass
