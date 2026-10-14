## Why
Terraform files never get an LSP: `lua/gleb/lsp/config/terraform/init.lua` sets `lsp_name = "terraform_lsp"` (binary `terraform-lsp`, not installed) while mason installs `terraform-ls`, whose server name is `terraformls`.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/lsp/config/terraform/init.lua:4` names the server `terraform_lsp`, while line 17 installs the `terraform-ls` executable.
- `lua/gleb/lsp/config/init.lua:44` and lines 48-49 pass that name to `vim.lsp.config` and `vim.lsp.enable`.
- `/Users/hlebbeladzed/.local/share/nvim/lazy/nvim-lspconfig/lsp/terraformls.lua:36-38` defines the installed server config as `terraformls`, with command `terraform-ls serve` and Terraform filetypes. The configured `terraform_lsp` name therefore cannot select this definition.

## What Changes
- Use `terraformls`; a test proves a `.tf` buffer gets a client config named `terraformls` (stub/lsp config check, no network).
- Task 1.1 shows the new assertion failing before the fix.
- This corrects the existing nvim-lspconfig server wiring without changing module layout or load order.
- No plugin dependency is added, removed, or upgraded.
- Core keymaps do not change.
- Out of scope: changing Terraform formatting, server settings, installation, or startup-time guarantees.

## Capabilities
### Modified Capabilities
- `lsp`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: `lua/gleb/lsp/config/terraform/init.lua` and its LSP integration test.
- Plugins: none added or upgraded.
