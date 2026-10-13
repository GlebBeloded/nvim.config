## Context

All maps live in `lua/gleb/keymaps.lua`, loaded from `init.lua` after `lazy.setup`, so smart-splits,
telescope and vim-bbye (eager, `lua/gleb/plugins/plugins.lua`) are available when it runs. The bufferline
close already uses `Bdelete! %d` (`lua/gleb/bufferline.lua:22`). `lua/gleb/debugging/keybindings.lua` is
never required (`lua/gleb/debugging/init.lua:1` is a comment). Pending changes edit the same file:
`fix-keymaps-visual-modes` (visual maps to `x`), `fix-diagnostic-navigation` (`vim.diagnostic.jump`),
`fix-mapleader` (leader lines). This change only touches `desc`/opts/rhs, so merges are line-local.

Root cause: none beyond what proposal.md states; checked in `nvim --clean` that a `:…<CR>` map fires
`CmdlineEnter` and a `<Cmd>…<CR>` map does not, and with `make render` that `<C-q>` (`:bdelete`) in a
`:vsplit` showing the same buffer collapses to one window while `:Bdelete` keeps both.

## Goals / Non-Goals

**Goals:**
- One small helper so every call passes `desc` and `silent` without repeating an opts table.
- Normal-mode Ex maps use `<Cmd>`; `<C-q>` uses `<Cmd>Bdelete<CR>`.

**Non-Goals:**
- Regrouping maps, moving them to other modules, or a which-key style registry.
- Changing the visual `:move` maps' rhs (they need `'<`/`'>`, which `<Cmd>` does not update).

## Decisions

- **Helper**: a local `map(mode, lhs, rhs, desc)` wrapping `vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })`, typed with LuaCATS. Alternative: keep per-call opts tables with `desc` — rejected, it repeats `silent` on 38 lines. `noremap` is dropped because `vim.keymap.set` defaults to `remap = false`; the `Mapping options` scenario still checks `noremap == 1`.
- **Desc areas**: `Window`, `Jump`, `Buffer`, `Edit`, `Tree`, `Git`, `Search`, `LSP`, `Diagnostic` (e.g. `Window: Resize up`, `Buffer: Close`, `Git: Open Differ`, `Search: Live grep`).
- **`<Cmd>` over Lua functions** for resize/`Differ`/`live_grep`/`Bdelete`: same command, no cmdline round-trip, and the rhs stays readable in `:map`. Functions are used only where one already exists (smart-splits, `vim.lsp.buf.*`).
- **`<C-q>` = `Bdelete` without `!`** (user decision): keeps the layout like the bufferline close, but refuses modified buffers like today's `:bdelete`.
- **Delete `debugging/keybindings.lua`** and the commented require (user decision). The new `Smart-splits resize keys are not remapped` scenario guards the collision.

### Current render

80x12, normal mode, `sample.lua` in two `:vsplit` windows, `init.lua` listed, after `<C-q>`, no LSP:

```text
▎       init.lua
  1   █equire("sample")









 NORMAL                                                           0  0   lua
```

### Proposed render (approved: user picked `Bdelete`)

80x12, same state, after `<C-q>`: the split stays, both windows show `init.lua`:

```text
▎       init.lua
  1   █equire("sample")                ┃  1   require("sample")
                                       ┃
                                       ┃
                                       ┃
                                       ┃
                                       ┃
                                       ┃
                                       ┃
                                       ┃
                                       ┃
 NORMAL                                                           0  0   lua
```

Colors are unchanged, so no mask or legend. Before `<C-q>` (both renders, excerpt: rows 1-5):

```text
        init.lua       ▕▎      sample.lua
  1   █ocal M = {}                     ┃  1   local M = {}
    1                                  ┃    1
    2 return M                         ┃    2 return M
                                       ┃
```

## Risks / Trade-offs

- [Edits overlap the pending keymaps changes] → each change keeps its lines; whichever merges second rebases on `auto` and keeps the `desc` helper on any line it rewrites.
- [Bdelete shows the alternate buffer, or an empty one when `<C-q>` closes the last buffer] → same as the bufferline close; the existing `Close current buffer` scenario still holds.
- [auto-save may write a modified buffer before `<C-q>` in the refusal scenario] → the test sets lines and presses `<C-q>` within the auto-save debounce, or uses a buffer auto-save skips.
