## Why

Kind: bug

`references: gr classifies every Rust variable usage` fails about one run in five: the helper presses `gr` as soon
as rust-analyzer is attached, before it finished loading the crate, so the server returns only the declaration
and no highlight kinds.

## Evidence

- `make test` on auto e477291, run 5 of 5:
  `FAIL in tests/integration/references/test_kind.lua | references: gr classifies every Rust variable usage | renders every usage kind:`
  `Left: { { "src/main.rs", 2, 5, "other" } }  Right: { { "src/main.rs", 2, 5, "write" }, { "src/main.rs", 3, 16, "read" } }`
- tests/integration/references/test_kind.lua:128 (`open_references`) waits only for an attached client, never for
  the server to finish indexing; the direct-classify cases pass a `minimum` usage count for the same reason.

## What Changes

- Before pressing `gr`, the read/write cases wait until the server is ready: for rust-analyzer its
  `experimental/serverStatus` notification with `quiescent = true` (the readiness helpers' pattern), for the others
  the existing readiness wait; no sleeps, no retries of `gr`, no weakened assertion.

## Impact

- tests/integration/references/test_kind.lua (and tests/helpers.lua only if the readiness wait belongs there)
- `file-tree: gr keeps its global meaning in git status tree` still holds because the change only synchronizes the references test helper and does not alter the global `gr` mapping.
- `references: gr opens the view in a Go module` still holds with its existing assertion; the helper continues to use the real `gr` mapping after readiness.
- `references: gr with no usages notifies and opens nothing` still holds because no production empty-result handling changes.
- `references: gr without a references-capable client notifies` still holds because no production client-capability handling changes.
- `references: gr continues when one client refuses the request` still holds because no production multi-client request handling changes.
- `references: Wide view matches reference screenshot` still holds because the change does not alter rendering.
- `references: Narrow view fits its content` still holds because the change does not alter layout.
- `references: Preview leaves no buffer or client behind` still holds because the change does not alter preview cleanup.
- `references: Escape returns to the origin window` still holds because the change does not alter view key handling.
- `references: Built-in close returns to the origin window` still holds because the change does not alter close handling.
- `references: Lua usages in production and spec files` still holds with its existing assertion; only test readiness synchronization changes.
- `references: Python usages in production and test files` still holds with its existing assertion; only test readiness synchronization changes.
- `references: TypeScript usages in production and test files` still holds with its existing assertion; only test readiness synchronization changes.
- `references: Rust usages in production and test code` still holds with its existing assertion; only test readiness synchronization changes.
- `references: Bash usages in production and test scripts` still holds with its existing assertion; only test readiness synchronization changes.
- `references: Terraform variable usages` still holds with its existing assertion; only test readiness synchronization changes.
- `references: Variable usages are grouped by write and read` still holds because the expected write/read groups and production grouping code are unchanged.
- `references: gr classifies every Go variable usage` still holds with its existing assertion; the helper continues to press the real `gr` mapping after readiness.
- `references: gr classifies every Lua local usage` still holds with its existing assertion; the helper continues to press the real `gr` mapping after readiness.
- `references: gr classifies every Python variable usage` still holds with its existing assertion; the helper continues to press the real `gr` mapping after readiness.
- `references: gr classifies every TypeScript variable usage` still holds with its existing assertion; the helper continues to press the real `gr` mapping after readiness.
- `references: gr classifies every Rust variable usage` keeps its exact write/read assertion; the helper waits for rust-analyzer to become quiescent before pressing the real `gr` mapping.
- `references: gr classifies every Bash variable usage` still holds with its existing assertion; the helper continues to press the real `gr` mapping after readiness.
- `references: gr classifies every Terraform variable usage` still holds with its existing assertion; the helper continues to press the real `gr` mapping after readiness.
- `references: The view opens before classification finishes` still holds because the change waits only before opening the view and does not alter asynchronous classification after it opens.
