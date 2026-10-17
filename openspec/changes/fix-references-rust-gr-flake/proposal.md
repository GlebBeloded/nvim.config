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
