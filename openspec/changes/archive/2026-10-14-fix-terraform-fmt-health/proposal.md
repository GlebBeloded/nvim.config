## Why
`lua/gleb/lsp/config/terraform/init.lua` registers null-ls `terraform_fmt` even when `terraform` is not installed, so `:checkhealth` reports `ERROR terraform_fmt: the command "terraform" is not executable`.
Found by the second audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/lsp/config/terraform/init.lua:11` returns the `terraform_fmt` builtin unconditionally; there is no executable check.
- `lua/gleb/lsp/config/init.lua:59` appends every source returned by a language config to the null-ls source list, so the unavailable formatter reaches null-ls health checks.

## What Changes
- Register `terraform_fmt` only when `vim.fn.executable("terraform") == 1`; test with a `PATH` lacking Terraform and prove the source is omitted, RED first.
- Out of scope: changing `terraformls`, installing Terraform, or changing other formatter registrations.

## Capabilities
### Modified Capabilities
- `lsp`: scenarios for the fixed behaviour.

## Impact
- Code: `lua/gleb/lsp/config/terraform/init.lua` and `tests/integration/lsp/test_config.lua`.
- Plugins: none added or upgraded. Core keymaps: unchanged.
