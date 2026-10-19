## Why

Kind: refactor

Depends: file-tree-performance

The references usage-kind rule "a function or type target drops read and write" lives in three places, and the
highlight-eligibility check in two:

- `lua/gleb/references/kind.lua:491` (`is_syntactic` filters read/write/unclassified before refining) and `kind.lua:511`
  (`drops_read_write`, then `refine_query_kind` runs again on every usage, including the ones `kind.lua:494` already
  refined: it is called at 494 and 512).
- `tests/unit/languages/test_contract.lua:185-193` re-implements the rule, so a production change would not be caught
  (an earlier review note says so).
- The highlight predicate (client present, `write_access ~= false`, supports `documentHighlight`) is copied at
  `kind.lua:581-584` and `604-607` (related: `usage_client`, `kind.lua:206`).

## What Changes

- One exported finalizer (e.g. `kind_refine.finalize(kind, target, ft)`) applying the rule once per usage, used by
  `kind.lua` and by `test_contract.lua` (the test calls production code instead of its own copy).
- One `highlights_allowed(client, references)` helper for both call sites.
- Behaviour unchanged: every references test and approved render stays green with its assertions as they are.

## Impact

- `lua/gleb/references/kind.lua` (and a small rules module if the finalizer moves out), `tests/unit/languages/test_contract.lua`.
