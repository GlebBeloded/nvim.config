## Why
Review note (run f513826a): `tests/integration/actions/test_plugin_ownership.lua:119` clears `package.loaded["gleb.copilot.setup"]`, a module that does not exist (`lua/gleb/copilot/` holds only `init.lua` and `actions.lua`).

Kind: bug

## Evidence
- `tests/integration/actions/test_plugin_ownership.lua:119`; `lua/gleb/copilot/init.lua`, `lua/gleb/copilot/actions.lua`.

## What Changes
- Drop the stale `package.loaded["gleb.copilot.setup"] = nil` line; the test's assertions are unchanged.

## Impact
- Code: `tests/integration/actions/test_plugin_ownership.lua` only.
