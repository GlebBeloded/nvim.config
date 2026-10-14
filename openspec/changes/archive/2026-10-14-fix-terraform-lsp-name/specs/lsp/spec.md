## ADDED Requirements

### Requirement: Terraform language server registration
The config SHALL register and enable the nvim-lspconfig server named `terraformls` for Terraform buffers, using the installed `terraform-ls` executable definition.

#### Scenario: Terraform files use terraformls
- **WHEN** a full-config Neovim opens a `.tf` file whose detected filetype is `terraform`
- **THEN** the buffer's enabled language-server config is named `terraformls`
