## Why
JS/TS: `eslint-lsp` is installed but `eslint` is never enabled (`lua/gleb/lsp/config/js/init.lua`), so no ESLint diagnostics; and the none-ls `code_actions.refactoring` source needs `ThePrimeagen/refactoring.nvim`, which is not installed, so every ranged code action logs "failed to run generator".
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Enable `eslint` alongside `vtsls`; drop the refactoring source (no plugin added). Tests: js config enables both servers; ranged code action in a Lua buffer logs no generator failure.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `lsp`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
