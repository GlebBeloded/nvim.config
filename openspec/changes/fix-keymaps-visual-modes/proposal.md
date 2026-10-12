## Why
Visual-mode maps in `lua/gleb/keymaps.lua` use `v` (visual + select), and some are mapped again in `x`: `<A-j>/<A-k>` (`:42-43` and `:49-50`) and `<C-CR>` (`:97-98`). In visual mode the `x` map wins, so the `v` rhs only survives in select mode. The `v` maps for `<`, `>` and `p` (`:38-39`, `:44`) also apply in select mode, so typing those characters over a select-mode selection (e.g. a snippet placeholder) runs the map instead of inserting the character: with `"foo"` in the unnamed register, `gh` then `p` on `bar baz` gives `fooar baz` instead of `par baz` (checked in `nvim --clean`).

Kind: bug

## What Changes
- Map every visual-mode behaviour in `lua/gleb/keymaps.lua` once, in `x` mode: `<`, `>`, `p`, `<A-j>`, `<A-k>`, `<C-CR>`.
- Remove the duplicate `v` maps for `<A-j>`, `<A-k>` (`:m .+1<CR>==` / `:m .-2<CR>==`) and `<C-CR>`.
- Select mode gets no maps from `keymaps.lua`, so typed characters replace the selection.

## Capabilities
### Modified Capabilities
- `keymaps`: `Visual mode editing helpers` drops the select-mode `<A-j>/<A-k>` behaviour and states that select mode is unmapped; `LSP actions and navigation` maps `<C-CR>` in `x` instead of "visual modes".

## Impact
- Code: `lua/gleb/keymaps.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: changed: select mode loses `<`, `>`, `p`, `<A-j>`, `<A-k>`, `<C-CR>`; visual (`x`) behaviour unchanged.
- Out of scope: visual `J`/`K` (`:47-48`) overriding the built-in join / keyword lookup (open question for the user); `desc` and `<Cmd>` cleanup (change `cleanup-keymaps`).
