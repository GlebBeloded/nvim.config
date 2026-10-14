## Why
`gr` (`lua/gleb/keymaps.lua:105`) calls `telescope.builtin.lsp_references` with defaults, and its `include_current_line = false` drops every reference on the cursor's line. Pressed on a declaration, the picker omits the declaration although `include_declaration` is true. The e2e case "lsp: References of a Go function list call sites across packages" (`tests/e2e/lsp/test_go_references.lua`, change `add-synthetic-repo-e2e`) shows 4 entries for `Format` in the `gomod` fixture instead of the 5 the `Go references workflow` requirement asks for; it is wrapped in `H.xfail` until this lands.

Kind: bug
Adopt: loop/fix-lsp-references-current-line

## What Changes
- `gr`: `lsp_references({ include_current_line = true })` (a small named function in `keymaps.lua`).
- Remove the `H.xfail` around the case in `tests/e2e/lsp/test_go_references.lua`.
- Out of scope: changing the `gr` key, Telescope layout or sorting, gopls settings, or reference selection behavior.

## Capabilities
### Modified Capabilities
- `lsp`: `Go references workflow` lists the declaration under the cursor too.

## Impact
- Code: `lua/gleb/keymaps.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: `gr` same key; the picker also lists references on the cursor's line.

## Rejected run
Run on `loop/fix-lsp-references-current-line` was rejected by the judge:
- review: test weakened
- blocked: tasks.md: ## Blocked

- loop: `tests/unit/shortcuts/test_sandbox.lua` has a check-then-read race while a stale lock owner file is replaced; the gate hit E484, while the exact file passed on rerun.
- Review findings to fix: (1) add a MODIFIED delta for the keymaps scenario at `openspec/specs/keymaps/spec.md:207-209` (the `gr` callback now calls `lsp_references` with `include_current_line = true`, as `tests/integration/keymaps/test_keymaps.lua:509-511` checks) and list `keymaps` under Modified Capabilities; (2) add a MODIFIED delta for `openspec/specs/file-tree/spec.md:140-142`, and restore an assertion in `tests/integration/file-tree/test_tree.lua:522` that proves the global `gr` callback reaches Telescope `lsp_references` (stub it as `test_keymaps.lua:47-61` does) instead of only checking the desc.
- The `loop:` sandbox-lock race is a loop issue fixed outside this change: delete that Blocked section from tasks.md.
