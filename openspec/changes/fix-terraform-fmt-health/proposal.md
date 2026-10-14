## Why
`lua/gleb/lsp/config/terraform/init.lua` registers null-ls `terraform_fmt` even when `terraform` is not installed, so `:checkhealth` reports `ERROR terraform_fmt: the command "terraform" is not executable`.
Found by the second audit of auto (2026-10-14).

Kind: bug

## Evidence
- Confirmed in a headless full-config child by the audit; locate code with `rg -n` (line numbers may drift).

## What Changes
- Register the source only when `vim.fn.executable("terraform") == 1` (or set its `condition`); test with a PATH lacking terraform: no terraform_fmt source registered / no health error, RED first.

## Capabilities
### Modified Capabilities
- `lsp`: scenarios for the fixed behaviour.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded. Core keymaps: unchanged.
