## Why
Terraform files never get an LSP: `lua/gleb/lsp/config/terraform/init.lua` sets `lsp_name = "terraform_lsp"` (binary `terraform-lsp`, not installed) while mason installs `terraform-ls`, whose server name is `terraformls`.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Use `terraformls`; a test proves a `.tf` buffer gets a client config named `terraformls` (stub/lsp config check, no network).
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `lsp`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
