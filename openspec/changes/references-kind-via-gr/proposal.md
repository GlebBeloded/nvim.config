## Why

Kind: feature

The user asked for one per-language suite that verifies read/write usages are correct. The shipped
tests/integration/references/test_kind.lua calls `client:request` and `kind.classify` itself instead of the real
`gr` path, and its Lua case builds usages from documentHighlight because lua_ls leaves assignment targets out of
`textDocument/references`, so a real `gr` on a Lua local likely lists no write at all. Bash is covered only by a
unit test of the treesitter fallback, which classifies every non-target use as `other` (never `read`), and
Terraform has no read/write check.

## What Changes

- test_kind.lua becomes the one per-language read/write suite: one case per language (Go, Lua, Python,
  TypeScript, Rust, Bash, Terraform) presses the real `gr` in a fixture buffer (the `references-languages` and
  extended `gomod` fixtures, plus temporary projects where needed), waits for classification, and asserts the
  exact `write`/`read` kind of every usage row the view lists. A missing server or parser is a test failure
  with its reason, not a skip.
- For lua_ls, `gr` also lists the write targets the server's documentHighlight reports in the current file but
  its references omit, so a Lua local's assignments appear as `write` usages.
- The treesitter fallback classifies a variable use that is not a write target as `read` (still `other` for
  call-only symbols per the existing rule), and covers HCL: a `variable "<name>"` block label is `write`,
  each `var.<name>` traversal is `read`.
- tree.lua's `tagged` and `has_kinds` parameters get `---@param` annotations (review minor of
  references-usage-kind).

## Capabilities

- `references`: Usage kind classification (MODIFIED), read/write suite scenarios per language.

## Impact

- lua/gleb/references/request.lua, kind.lua, kind_ts.lua, tree.lua
- tests/integration/references/test_kind.lua, tests/unit/references/test_kind_ts.lua
- tests/fixtures/build.sh (only if a fixture lacks a variable to classify)
