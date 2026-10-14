## ADDED Requirements

### Requirement: Unavailable Terraform formatter is omitted
When the `terraform` executable is unavailable, the config SHALL omit the `terraform_fmt` source from null-ls so its health check does not report a missing command.

#### Scenario: Terraform formatter is omitted when Terraform is unavailable
- **WHEN** a full-config Neovim starts with a `PATH` where `terraform` is not executable
- **THEN** the registered null-ls sources do not include `terraform_fmt`
