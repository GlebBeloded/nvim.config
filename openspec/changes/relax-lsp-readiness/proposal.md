## Why
lua_ls readiness (2.5 s bound) fails on this host under load and holds up loop gates.

Kind: bug

## Decision (user, 2026-10-14)
"Update timeout to 10s for everything. It is what it is. We will optimize later. Make sure it doesn't get
in the way." Every LSP readiness bound is 10000 ms; the spec states no number (tunables live in the test).

## What Changes
- `tests/integration/lsp/test_readiness.lua`: every bound 10000 ms, wait ceiling above it.
- `lsp` spec: readiness requirement and scenario titles drop the ms/s numbers.
