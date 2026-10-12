## Why
The diagnostic maps (`lua/gleb/keymaps.lua:109-115`) call `vim.diagnostic.goto_next/goto_prev`, deprecated since Neovim 0.11 (removal in 0.13), and pass `{ border = "rounded" }`, which is not a goto option and has no effect (the float border already comes from `vim.diagnostic.config` in `lua/gleb/lsp/config/handlers.lua:24`). LuaLS reports `deprecated` on `keymaps.lua:109`, `:111` and `:114`.

Kind: bug

## What Changes
- `<A-w>` and `ge`: `vim.diagnostic.jump({ count = 1, float = true })`.
- `[d`: `vim.diagnostic.jump({ count = -1, float = true })`.
- Drop the dead `border` option. The float keeps the border set by `vim.diagnostic.config`.
- Once these hits are gone, the `deprecated` diagnostic code can go back to Warning in `.luarc.jsonc` if no other hit remains (`lsp/config/python/typecheck.lua:7` is still one; see `fix-type-check-baseline`).

## Capabilities
### Modified Capabilities
- `keymaps`: `Diagnostic navigation` uses the non-deprecated jump API and opens the diagnostic float after each jump.

## Impact
- Code: `lua/gleb/keymaps.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged (same keys, same jumps; no deprecation message).
- Out of scope: the float's look (border, source, header); `]d`/`[d` defaults Neovim already provides; `lsp/config/python/typecheck.lua:7`.
