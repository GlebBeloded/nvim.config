## Why
`lsp: JavaScript config enables vtsls and eslint` (`tests/integration/lsp/test_config.lua`, from fix-js-eslint-and-refactoring ad75558) compares the enabled config names in a fixed order, but the order Neovim returns is not stable: on 2026-10-14 it failed alone and in `make check` with `Left: { "vtsls", "eslint" }  Right: { "eslint", "vtsls" }` (line 20). Every gate is red while it fails.

Kind: bug

## Evidence
- `FAIL in tests/integration/lsp/test_config.lua | lsp: JavaScript config enables vtsls and eslint:` (`different values at key 1, left = "vtsls", right = "eslint"`).

## What Changes
- Compare as sets: sort both lists (or compare membership) before `eq`, keeping the same two expected names. Do the same for any sibling case in the file that compares config-name lists in order.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/lsp/test_config.lua`.
- Plugins: none.
