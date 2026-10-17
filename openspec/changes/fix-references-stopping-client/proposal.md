## Why

Kind: bug

`gr` silently does nothing when one attached client is stopping: `client:request` returns false without calling
the handler, so the pending count in `lua/gleb/references/request.lua` never reaches 0, `finish` never runs, and
neither the view nor "No usages found" appears. Raised as a minor in three reviews of run e15e8b69 and left open.

## Evidence

- lua/gleb/references/request.lua:99-101 ignores the boolean `client:request` returns
- `:h Client:request()`: returns false when the client has shut down or the request could not be sent

## What Changes

- A request that `client:request` refuses counts as finished with no result, so the other clients' usages
  still open the view (or "No usages found" shows when none are left).
- An integration test stubs one of two clients' `request` to return false and asserts the view opens with the
  other client's usages.

## Impact

- lua/gleb/references/request.lua
- tests/integration/references/
