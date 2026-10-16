# references Specification

## Purpose
Classify reference locations as production or test code across every configured language so later Find Usages features can group or exclude tests consistently.

## Requirements

### Requirement: Primary language test paths
The references scope module SHALL classify Go files ending `_test.go`, TypeScript and JavaScript files whose basename contains `.test.` or `.spec.` or whose path contains `__tests__`, Python files named `test_*.py`, `*_test.py`, or `conftest.py` or under `tests`, and Lua files ending `_spec.lua` or under `spec` or `tests` as test code.

#### Scenario: Go test paths
- **WHEN** `require("gleb.references.scope").is_test(path, "go")` is called for Go test and production filenames
- **THEN** only paths ending `_test.go` are reported as test code

#### Scenario: TypeScript and JavaScript test paths
- **WHEN** `is_test` is called with TypeScript or JavaScript filetypes for `.test.`, `.spec.`, `__tests__`, and ordinary source paths
- **THEN** the three test conventions are reported as test code and ordinary source paths are not

#### Scenario: Python test paths
- **WHEN** `is_test` is called with the Python filetype for `test_*.py`, `*_test.py`, `conftest.py`, `tests/`, and ordinary source paths
- **THEN** the four test conventions are reported as test code and ordinary source paths are not

#### Scenario: Lua test paths
- **WHEN** `is_test` is called with the Lua filetype for `*_spec.lua`, `spec/`, `tests/`, and ordinary source paths
- **THEN** the three test conventions are reported as test code and ordinary source paths are not

#### Scenario: Language conventions classify paths
- **WHEN** test detection is asked about `a/b_test.go`, `src/x.test.ts`, `src/y.spec.js`, `src/__tests__/z.js`, `pkg/test_a.py`, `pkg/b_test.py`, `pkg/conftest.py`, `lua/m_spec.lua`, `tests/unit/test_rows.lua`, `crates/core/tests/api.rs`, `t/run.bats`, `main.tftest.hcl` and `infra/tests/plan.tftest.hcl`
- **THEN** every one of them is test code

#### Scenario: Production paths are not test code
- **WHEN** test detection is asked about `cmd/main.go`, `src/x.ts`, `src/testing_utils.ts`, `pkg/contest.py`, `lua/gleb/references/scope.lua`, `src/lib.rs`, `bin/run.sh` and `main.tf`
- **THEN** none of them is test code

### Requirement: Remaining and generic test paths
The references scope module SHALL classify Rust paths under `tests`, Bash files ending `.bats` or under `test` or `tests`, and Terraform files ending `.tftest.hcl` or under `tests` as test code. For any language, a `test`, `tests`, `spec`, or `__tests__` path segment SHALL be test code. It SHALL infer the applicable language from the path when no filetype is supplied.

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

### Requirement: Project test-pattern extensions
The references scope module SHALL append the Lua patterns in `vim.g.gleb_test_patterns[filetype]` to that filetype's built-in conventions. The built-in convention table SHALL remain the single source for default patterns, and missing or unrelated extension entries SHALL not change classification.

#### Scenario: Project pattern extends one filetype
- **WHEN** `vim.g.gleb_test_patterns` adds a pattern for one filetype and `is_test` is called for matching and nonmatching paths in that and another filetype
- **THEN** the matching path in the configured filetype is test code, built-in conventions still work, and the extension does not affect the other filetype

#### Scenario: A project adds its own test pattern
- **WHEN** `vim.g.gleb_test_patterns = { go = { "/e2e/" } }` is set and test detection is asked about `svc/e2e/flow.go` and `svc/flow_test.go`
- **THEN** both are test code

### Requirement: Rust inline test modules
For Rust source, `is_test_at(path, lnum, text)` SHALL report positions within a `#[cfg(test)]` module as test code by parsing the supplied text with Tree-sitter. Path-based test classification SHALL still apply. If the Rust parser is unavailable or parsing fails, the function SHALL not error and SHALL use path-based classification only.

#### Scenario: Position inside Rust cfg test module
- **WHEN** `is_test_at` receives Rust source containing a `#[cfg(test)]` module and positions inside and outside that module while the Rust parser is available
- **THEN** the inside position is reported as test code and the outside position is not

#### Scenario: Rust parser unavailable
- **WHEN** `is_test_at` receives Rust source containing a `#[cfg(test)]` module while the Rust parser is unavailable
- **THEN** it does not error, does not classify the position from source text, and still reports a path under `tests` as test code
