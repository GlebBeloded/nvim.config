## Why

The planned Find Usages view groups usages into `Production` and `Test`. No LSP server marks a reference location as test code, so the config needs its own test-file detection. It has to cover every language the config sets up, not just Go.

Kind: feature

## What Changes

- New pure module `lua/gleb/references/scope.lua`. Given a path, it answers whether the path is test code (`is_test(path, filetype?)`), using a table of conventions for each language:
  - **Go:** `*_test.go`
  - **TypeScript / JavaScript:** `*.test.*`, `*.spec.*`, `__tests__/`
  - **Python:** `test_*.py`, `*_test.py`, `conftest.py`, `tests/`
  - **Lua:** `*_spec.lua`, `spec/`, `tests/`
  - **Rust:** `tests/`
  - **Bash:** `*.bats`, `test/`, `tests/`
  - **Terraform:** `*.tftest.hcl`, `tests/`
  - **Any other language:** a `test`, `tests`, `spec` or `__tests__` path segment
- Rust inline tests: `is_test_at(path, lnum, text)` also reports a position inside a `#[cfg(test)]` module as test code. It parses the given text with treesitter and is a no-op when the `rust` parser is missing.
- The table is the only place conventions live. A project can extend it with `vim.g.gleb_test_patterns` (filetype → Lua patterns).

## Capabilities

### New Capabilities
- `references`: Find Usages for the symbol under the cursor. This change adds only test-file detection; `references-view` adds the view.

### Modified Capabilities
- none.

## Impact

- Code: new `lua/gleb/references/scope.lua`. It is pure logic (rule 1.3) and has no UI.
- Tests: unit tests for every language's conventions, the generic fallback, project extension, and Rust `cfg(test)` both with and without the parser.
- Plugins: none. Core keymaps: unchanged.
- Out of scope: the view (`references-view`), usage kinds (`references-usage-kind`), and per-language server checks (`references-languages`).

## Decision (user, 2026-10-16)

- "conditional grouping on read/write references, excluding tests"
- "It should work [for] all supported languages in config (where applicable), not only go."
- "Split work into steps if possible, I will drain the queue myself."
