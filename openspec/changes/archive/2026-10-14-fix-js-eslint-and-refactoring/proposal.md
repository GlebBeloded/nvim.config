## Why
JS/TS: `eslint-lsp` is installed but `eslint` is never enabled (`lua/gleb/lsp/config/js/init.lua`), so no ESLint diagnostics; and the none-ls `code_actions.refactoring` source needs `ThePrimeagen/refactoring.nvim`, which is not installed, so every ranged code action logs "failed to run generator".
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/lsp/config/js/init.lua:3` exposes only `vtsls`, while `lua/gleb/lsp/config/init.lua:43`-`lua/gleb/lsp/config/init.lua:50` enable exactly the names exposed by each language module; installing `eslint-lsp` at `lua/gleb/lsp/config/js/init.lua:47`-`lua/gleb/lsp/config/js/init.lua:50` does not enable its `eslint` server.
- `lua/gleb/lsp/config/js/init.lua:41`-`lua/gleb/lsp/config/js/init.lua:44` registers the none-ls refactoring source. The installed source at `/Users/hlebbeladzed/.local/share/nvim/lazy/none-ls.nvim/lua/null-ls/builtins/code_actions/refactoring.lua:25` evaluates `require("refactoring").get_refactors`, and `/Users/hlebbeladzed/.local/share/nvim/lazy/none-ls.nvim/lua/null-ls/generators.lua:146`-`/Users/hlebbeladzed/.local/share/nvim/lazy/none-ls.nvim/lua/null-ls/generators.lua:149` logs generator failures; `refactoring.nvim` is not configured in this repo.

## What Changes
- Enable `eslint` alongside `vtsls`; drop the refactoring source (no plugin added). Tests: js config enables both servers; ranged code action in a Lua buffer logs no generator failure.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `lsp`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: `lua/gleb/lsp/config/js/init.lua` and `tests/integration/lsp/test_config.lua`.
- Plugins: none added or upgraded.
- Core keymaps: unchanged.
- Out of scope: adding a refactoring plugin, changing LSP readiness bounds, or changing other language configurations.
