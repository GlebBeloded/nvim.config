## Context
See proposal.md (Why). On Neovim 0.12.5 `goto_next/goto_prev` call `vim.deprecate(..., '0.13')`, which is hard-deprecated and echoes once per session; with `cmdheight = 0` the echo lands in `:messages` and the steady screen after `ge` is identical (captured with a full-config child: same buffer, same rounded float `Lua Diagnostics.: <message>`). `vim.diagnostic.jump` defaults to no float; its `float` option is deprecated for `on_jump` (removal 0.14: silent on 0.12, echoed on 0.13 nightly). `on_jump(diagnostic, bufnr)` runs through `vim.schedule` after the cursor moves.

## Goals / Non-Goals
Goals: same keys, same jumps, same float; no deprecated diagnostic API on stable or nightly.
Non-goals: no visible UI change, so no renders; the float's look stays owned by `vim.diagnostic.config` in `lua/gleb/lsp/config/handlers.lua`.

## Decisions
- Proposed A (picked): in `lua/gleb/keymaps.lua`, a small named `on_jump` function that opens `vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })` when a diagnostic was jumped to, and two named functions `jump_next` / `jump_prev` calling `vim.diagnostic.jump({ count = ±1, on_jump = ... })`. These are the options `goto_next` used for its default float, so the float is unchanged.
- Proposed B: `jump({ count, float = true })`, as the queued proposal first said. Rejected: `float` is deprecated for `on_jump` and warns on nightly.
- Proposed C: `vim.diagnostic.config({ jump = { on_jump = ... } })` in `handlers.lua` and plain `jump({ count })` maps. Rejected: it also changes the built-in `]d`/`[d`/`]D`/`[D`, which the proposal keeps out of scope, and splits one keymap's behaviour across two modules.
- Testability: the "not deprecated" scenario wraps `vim.deprecate` in the child before pressing keys, so soft deprecations (silent on 0.12) are caught too, not just echoed ones. The float scenario waits (`child.wait`) for the scheduled `on_jump`.

## Risks / Trade-offs
- [`on_jump` does not exist before 0.12] → stable is 0.12; the config already requires 0.11+ APIs (`vim.o.winborder`), and 0.11 is no longer a target.
- [`.luarc.jsonc` `deprecated` severity] → raise back to Warning only if `make check` type layer shows no other hit (`lsp/config/python/typecheck.lua:7` remains until `fix-type-check-baseline`); otherwise leave it.
