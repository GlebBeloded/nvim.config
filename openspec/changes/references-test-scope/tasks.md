## 1. Classify primary language test paths
Scenarios: `references: Go test paths`, `references: TypeScript and JavaScript test paths`, `references: Python test paths`, `references: Lua test paths`
- [x] 1.1 Write the tests for these scenarios in `tests/unit/references/test_scope.lua`, calling `require("gleb.references.scope").is_test` with matching and near-miss paths, and see them fail
- [x] 1.2 Add the typed, pure pattern table and `is_test` path classifier in `lua/gleb/references/scope.lua`
- [x] 1.3 Run `make test FILE=tests/unit/references/test_scope.lua CASE="test paths"` and see it pass

## 2. Classify remaining and inferred test paths
Scenarios: `references: Rust test paths`, `references: Bash test paths`, `references: Terraform test paths`, `references: Generic and inferred test paths`
- [x] 2.1 Write the tests for these scenarios in `tests/unit/references/test_scope.lua`, driving `scope.is_test` with explicit and omitted filetypes, and see them fail
- [x] 2.2 Extend the central pattern table for Rust, Bash, Terraform, generic path segments, and filetype inference
- [x] 2.3 Run `make test FILE=tests/unit/references/test_scope.lua CASE="test paths"` and see it pass

## 3. Apply project pattern extensions
Scenarios: `references: Project pattern extends one filetype`
- [x] 3.1 Write the test `references: Project pattern extends one filetype` in `tests/unit/references/test_scope.lua`, setting and restoring `vim.g.gleb_test_patterns` around real `scope.is_test` calls, and see it fail
- [x] 3.2 Append filetype-specific project patterns without mutating the built-in convention table
- [x] 3.3 Run `make test FILE=tests/unit/references/test_scope.lua CASE="Project pattern extends one filetype"` and see it pass

## 4. Detect Rust inline test modules
Scenarios: `references: Position inside Rust cfg test module`, `references: Rust parser unavailable`
- [x] 4.1 Write the tests for these scenarios in `tests/unit/references/test_scope.lua`, calling `scope.is_test_at` with populated Rust source and controlled real parser availability, and see them fail
- [x] 4.2 Add guarded Tree-sitter parsing that recognizes positions inside `#[cfg(test)]` modules and falls back to path classification
- [x] 4.3 Run `make test FILE=tests/unit/references/test_scope.lua CASE="Rust"` and see it pass
