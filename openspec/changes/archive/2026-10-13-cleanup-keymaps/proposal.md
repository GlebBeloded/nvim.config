## Why
No map in `lua/gleb/keymaps.lua` has a `desc`, so they are unnamed in `:map` and pickers (the 99 maps have one). Every call repeats `{ noremap = true, silent = true }` (`:1`), though `vim.keymap.set` is non-recursive by default. Several maps use `:…<CR>` string rhs (`:19-22`, `:32`, `:42-50`, `:87`, `:93`), which flash the command line and leave visual mode, instead of `<Cmd>` or functions. `<C-q>` runs the built-in `:bdelete` (`:32`), which closes every window showing the buffer, while the bufferline close uses vim-bbye `Bdelete!` (`lua/gleb/bufferline.lua`), which keeps the layout. `lua/gleb/debugging/keybindings.lua` is not loaded (`lua/gleb/debugging/init.lua:1` is commented out) and would map `<A-J>/<A-H>/<A-L>` to dap steps, colliding with the smart-splits resize maps (`keymaps.lua:26-29`).

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.
Open questions for the user:
- `<C-q>`: keep `:bdelete` (closes windows), or switch to vim-bbye `Bdelete` / `Bdelete!` to match bufferline (keeps layout; `!` discards changes)?
- `lua/gleb/debugging/keybindings.lua`: delete it, or keep it with new keys that don't collide with `<A-H>/<A-J>/<A-K>/<A-L>` (which ones)?

## What Changes
- Give every map in `keymaps.lua` a `desc` in the form `<Area>: <Action>` (e.g. `Window: Move left`, `LSP: Rename`).
- Use `{ silent = true, desc = ... }`; drop the redundant `noremap = true` (the `Mapping options` requirement still holds: `vim.keymap.set` is non-recursive by default).
- Replace `:…<CR>` string rhs with `<Cmd>…<CR>` or Lua functions where behaviour stays the same (resize, `:Differ`, `:Telescope live_grep`); the visual `:move` maps keep the range they need.
- `<C-q>` and `debugging/keybindings.lua` per the user's answers.

## Capabilities
### Modified Capabilities
- `keymaps`: adds a `desc` requirement for every map in `keymaps.lua`; `Buffer close` changes if the user picks `Bdelete`.

## Impact
- Code: `lua/gleb/keymaps.lua`, possibly `lua/gleb/debugging/keybindings.lua` and `lua/gleb/debugging/init.lua`.
- Plugins: none added, removed or upgraded (vim-bbye is already installed).
- Core keymaps: changed: descs added on all maps; `<C-q>` behaviour may change (user decision).
- Out of scope: the leader key (`fix-mapleader`), `v`/`x` mode duplicates (`fix-keymaps-visual-modes`), diagnostic API (`fix-diagnostic-navigation`), visual `J`/`K`, neo-tree git_status `gr`/`c` shadowing.

## Decision (user, 2026-10-12)
`<C-q>` uses vim-bbye `Bdelete` (keeps the layout, like the bufferline close). Delete `lua/gleb/debugging/keybindings.lua` (unused, collides with resize maps) and its commented require.
