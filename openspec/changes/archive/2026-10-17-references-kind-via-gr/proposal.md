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

## Decision (auditor, 2026-10-17, from the user's goal)

- Every configured language's treesitter parser is installed by the config: add `hcl`, `terraform`, `rust`, `python`, `typescript`, `tsx` and `javascript` to the parser list in `lua/gleb/treesitter.lua`, so the fallback and its tests run on real parsers in the test environment too.
- The HCL fallback test parses real HCL with the installed parser (no stubbed `language.add`, `query.parse` or parser); Terraform kinds come from that fallback, never from matching the client name or a `var.` text prefix.
- The direct-classify scenarios of the shipped spec keep their cases under their original titles next to the new `gr` cases.

## Capabilities

- `references`: Usage kind classification (MODIFIED), read/write suite scenarios per language.

## Impact

- lua/gleb/references/request.lua, kind.lua, kind_ts.lua, tree.lua
- tests/integration/references/test_kind.lua, tests/unit/references/test_kind_ts.lua
- tests/fixtures/build.sh (only if a fixture lacks a variable to classify)
- No plugin dependency is added, removed, or upgraded.
- Core keymaps do not change; the existing normal-mode `gr` entry point is exercised.
- Out of scope: changing view layout, grouping controls, navigation, preview behavior, or function-call classification.
- `file-tree: gr keeps its global meaning in git status tree` still holds because the change does not alter mapping ownership or the git status tree.
- `references: gr opens the view in a Go module` still holds because the real-`gr` suite retains the Go fixture path and expected view opening.
- `references: gr with no usages notifies and opens nothing` still holds because only non-empty reference classification changes.
- `references: gr without a references-capable client notifies` still holds because client discovery and the no-support path are unchanged.
- `references: gr continues when one client refuses the request` still holds because merging usage kinds occurs after accepted reference requests complete.
- `references: Wide view matches reference screenshot` still holds because layout and the function-only `Format` render are unchanged.
- `references: Narrow view fits its content` still holds because sizing and the function-only `Format` render are unchanged.
- `references: Preview leaves no buffer or client behind` still holds because classification reads source without opening preview buffers or attaching clients.
- `references: Escape returns to the origin window` still holds because close handling is unchanged.
- `references: Built-in close returns to the origin window` still holds because window teardown and origin restoration are unchanged.
- `references: Lua usages in production and spec files` still holds because omitted write highlights are added only to the current variable-symbol request and existing function usages remain unchanged.
- `references: Python usages in production and test files` still holds because the references request and scope grouping are unchanged.
- `references: TypeScript usages in production and test files` still holds because the references request, deduplication, and scope grouping are unchanged.
- `references: Rust usages in production and test code` still holds because the references request and parser-dependent test scope are unchanged.
- `references: Bash usages in production and test scripts` still holds because function-only symbols remain `other` and their usage rows are unchanged.
- `references: Terraform variable usages` still holds because the same server-reported rows remain listed while their read kinds become explicit.
- `references: Variable usages are grouped by write and read` still holds and is extended to the other configured languages through the existing grouping behavior.
- `references: The view opens before classification finishes` still holds because reference collection still opens the view before asynchronous classification and highlight merging finish.
