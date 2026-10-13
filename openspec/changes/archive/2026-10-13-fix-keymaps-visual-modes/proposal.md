## Why
Visual-mode maps in `lua/gleb/keymaps.lua` use `v` (visual + select), so printable keys such as `p` run a mapping instead of replacing a Select-mode selection. The completed implementation on `loop/fix-20261013-120359` has not landed on `auto`, and its original full-config scenario cannot use `gh` because mini.diff owns that normal-mode key.

Kind: bug

## Decision

- **2026-10-13 — Select-mode scenario entry:** Keep mini.diff's normal-mode `gh` mapping. The scenario "Typing p in select mode inserts p" enters Visual mode with `v`, switches to Select mode with `<C-g>`, and then types `p`. Its observable assertion stays `{ { "foo", "par baz" }, "i" }`: the line is `par baz` and the mode is Insert. Neovim's built-in replacement of the unnamed register is not part of this assertion.

## What Changes
- Map every visual-mode behaviour in `lua/gleb/keymaps.lua` once, in `x` mode: `<`, `>`, `p`, `<A-j>`, `<A-k>`, `<C-CR>`.
- Remove the duplicate `v` maps for `<A-j>`, `<A-k>` (`:m .+1<CR>==` / `:m .-2<CR>==`) and `<C-CR>`.
- Select mode gets no maps from `keymaps.lua`, so typed characters replace the selection.
- Port the completed code and test from `loop/fix-20261013-120359` onto current `auto`, while retaining `auto`'s `query_focused_pane()` plus `retry_cli` implementation in `tests/shortcuts/stack.lua`.
- Update the synced `keymaps` spec and the scenario test to use `v`, `<C-g>`, `p`.

## Capabilities
### Modified Capabilities
- `keymaps`: `Visual mode editing helpers` drops the select-mode `<A-j>/<A-k>` behaviour and states that select mode is unmapped; `LSP actions and navigation` maps `<C-CR>` in `x` instead of "visual modes".

## Impact
- Code: `lua/gleb/keymaps.lua`.
- Tests: `tests/integration/keymaps/test_keymaps.lua`; `tests/shortcuts/stack.lua` remains unchanged from `auto`.
- Plugins: none added, removed or upgraded.
- Core keymaps: changed: select mode loses `<`, `>`, `p`, `<A-j>`, `<A-k>`, `<C-CR>`; visual (`x`) behaviour unchanged.
- Out of scope: remapping mini.diff's `gh`; preserving the unnamed register during built-in Select-mode typing; visual `J`/`K` overriding the built-in join / keyword lookup; `desc` and `<Cmd>` cleanup (change `cleanup-keymaps`).
