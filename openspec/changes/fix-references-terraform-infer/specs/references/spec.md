# Spec Delta

## MODIFIED Requirements

### Requirement: Remaining and generic test paths
The references scope module SHALL classify Rust paths under `tests`, Bash files ending `.bats` or under `test` or `tests`, and Terraform files ending `.tftest.hcl` or under `tests` as test code for explicit or inferred `terraform`, `tf`, and `hcl` filetypes. For any language, a `test`, `tests`, `spec`, or `__tests__` path segment SHALL be test code. It SHALL infer the applicable language from the path when no filetype is supplied.

#### Scenario: Rust test paths
- **WHEN** `is_test` is called with the Rust filetype for paths inside and outside a `tests` segment
- **THEN** only paths inside `tests` are reported as test code

#### Scenario: Bash test paths
- **WHEN** `is_test` is called with the Bash filetype for `.bats`, `test/`, `tests/`, and ordinary shell paths
- **THEN** the three test conventions are reported as test code and ordinary shell paths are not

#### Scenario: Terraform test paths
- **WHEN** `is_test` is called with a Terraform filetype for `.tftest.hcl`, `tests/`, and ordinary Terraform paths
- **THEN** the two test conventions are reported as test code and ordinary Terraform paths are not

#### Scenario: Generic and inferred test paths
- **WHEN** `is_test` is called for configured filetypes with generic test segments, or without a filetype for paths whose extension identifies a primary language
- **THEN** generic test segments and inferred language conventions are reported as test code while ordinary source paths are not

#### Scenario: Unknown languages use the generic segments
- **WHEN** test detection is asked about `app/spec/models/user.rb` and `app/models/user.rb` with filetype `ruby`
- **THEN** only `app/spec/models/user.rb` is test code
