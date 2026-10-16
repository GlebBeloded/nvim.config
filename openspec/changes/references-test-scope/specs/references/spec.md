## Purpose

Shows every usage of the symbol under the cursor in a grouped, previewable Find Usages view, for any language whose attached LSP client supports references.

## ADDED Requirements

### Requirement: Test file detection
A path SHALL count as test code when it matches its language's convention: Go `*_test.go`; TS/JS `*.test.*`, `*.spec.*` or a `__tests__` directory; Python `test_*.py`, `*_test.py`, `conftest.py` or a `tests` directory; Lua `*_spec.lua`, a `spec` or `tests` directory; Rust a `tests` directory; Bash `*.bats`, a `test` or `tests` directory; Terraform `*.tftest.hcl` or a `tests` directory; any language a `test`, `tests`, `spec` or `__tests__` path segment.

#### Scenario: Language conventions classify paths
- **WHEN** test detection is asked about `a/b_test.go`, `src/x.test.ts`, `src/y.spec.js`, `src/__tests__/z.js`, `pkg/test_a.py`, `pkg/b_test.py`, `pkg/conftest.py`, `lua/m_spec.lua`, `tests/unit/test_rows.lua`, `crates/core/tests/api.rs`, `t/run.bats`, `main.tftest.hcl` and `infra/tests/plan.tftest.hcl`
- **THEN** every one of them is test code

#### Scenario: Production paths are not test code
- **WHEN** test detection is asked about `cmd/main.go`, `src/x.ts`, `src/testing_utils.ts`, `pkg/contest.py`, `lua/gleb/references/scope.lua`, `src/lib.rs`, `bin/run.sh` and `main.tf`
- **THEN** none of them is test code

#### Scenario: Unknown languages use the generic segments
- **WHEN** test detection is asked about `app/spec/models/user.rb` and `app/models/user.rb` with filetype `ruby`
- **THEN** only `app/spec/models/user.rb` is test code

### Requirement: Rust inline test modules
A position SHALL count as test code when it lies inside a Rust `mod` item annotated `#[cfg(test)]`. When the `rust` treesitter parser is not installed, only the path conventions SHALL apply.

#### Scenario: A usage inside a cfg(test) module is test code
- **WHEN** test detection is asked about `src/lib.rs` positions inside and outside a `#[cfg(test)] mod tests { ... }` block of a given text, with the `rust` parser available
- **THEN** the position inside is test code and the position outside is not

#### Scenario: Missing rust parser falls back to paths
- **WHEN** the same question is asked with the `rust` parser unavailable
- **THEN** no error is raised and both positions are production code

### Requirement: Project test patterns
`vim.g.gleb_test_patterns` (a table of filetype to Lua patterns) SHALL extend the built-in conventions without replacing them.

#### Scenario: A project adds its own test pattern
- **WHEN** `vim.g.gleb_test_patterns = { go = { "/e2e/" } }` is set and test detection is asked about `svc/e2e/flow.go` and `svc/flow_test.go`
- **THEN** both are test code
