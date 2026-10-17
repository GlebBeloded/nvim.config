## Why

Kind: bug

`gr` silently does nothing when one attached client is stopping: `client:request` returns false without calling
the handler, so the pending count in `lua/gleb/references/request.lua` never reaches 0, `finish` never runs, and
neither the view nor "No usages found" appears. Raised as a minor in three reviews of run e15e8b69 and left open.

## Evidence

- `lua/gleb/references/request.lua:94,109-110,133-135` initializes `pending` from every capable client, but
  decrements it only from the response handler and ignores the boolean returned by `client:request`.
- `/opt/homebrew/Cellar/neovim/0.12.5_1/share/nvim/runtime/lua/vim/lsp/client.lua:742-764` forwards the RPC
  request status to the caller without invoking the response handler itself when sending fails.
- `/opt/homebrew/Cellar/neovim/0.12.5_1/share/nvim/runtime/lua/vim/lsp/rpc.lua:266-267,313-324` returns false
  while the transport is closing and registers the response callback only after a successful send.

## What Changes

- A request that `client:request` refuses counts as finished with no result, so the other clients' usages
  still open the view (or "No usages found" shows when none are left).
- An integration test stubs one of two clients' `request` to return false and asserts the view opens with the
  other client's usages.

## Impact

- lua/gleb/references/request.lua
- tests/integration/references/
- No plugin dependency is added, removed, or upgraded.
- Core keymaps do not change.
- Out of scope: changing the Find Usages layout, grouping, preview, or navigation behavior.
