# Tasks

**Goal:** ship the adopted `cleanup-convention-targets` work after the sandbox-sync fix already on
`auto` removes the rejected run's e2e failure.

## No implementation tasks

- [x] Mark this adopted, implementation-free follow-up as `skip_specs` metadata.

The adopted merge at `b0e8345` already combines the rejected cleanup branch with `auto`'s fresh
sandbox staging. The existing mini.test scenario `shortcuts: sandbox.sh e2e restores guest state after
syncing and before the e2e layer` passes, as does the quick gate. There is therefore no failing scenario
from which to start another TDD task; adding code or a duplicate scenario test would be outside this
follow-up's scope. The normal review, judge, and ship steps can proceed on the adopted merge.
