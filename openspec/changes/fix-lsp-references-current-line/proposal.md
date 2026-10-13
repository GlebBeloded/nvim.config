## Why
`gr` (`lua/gleb/keymaps.lua:105`) calls `telescope.builtin.lsp_references` with defaults, and its `include_current_line = false` drops every reference on the cursor's line. Pressed on a declaration, the picker omits the declaration although `include_declaration` is true. The e2e case "lsp: References of a Go function list call sites across packages" (`tests/e2e/lsp/test_go_references.lua`, change `add-synthetic-repo-e2e`) shows 4 entries for `Format` in the `gomod` fixture instead of the 5 the `Go references workflow` requirement asks for; it is wrapped in `H.xfail` until this lands.

Kind: bug

## What Changes
- `gr`: `lsp_references({ include_current_line = true })` (a small named function in `keymaps.lua`).
- Remove the `H.xfail` around the case in `tests/e2e/lsp/test_go_references.lua`.

## Capabilities
### Modified Capabilities
- `lsp`: `Go references workflow` lists the declaration under the cursor too.

## Impact
- Code: `lua/gleb/keymaps.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: `gr` same key; the picker also lists references on the cursor's line.
