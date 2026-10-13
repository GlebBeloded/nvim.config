## 1. Leader set in init.lua before lazy.nvim

Scenarios: "keymaps: Leader values after startup", "keymaps: Leader is set before lazy.nvim loads plugins"

- [x] 1.1 Failing tests: sync the `keymaps` delta into `openspec/specs/keymaps/spec.md` (trace reads only main specs). In `tests/integration/keymaps/test_keymaps.lua` change "Leader values after startup" to expect `{ " ", "\\" }` and add `T["keymaps: Leader is set before lazy.nvim loads plugins"]`: restart the child like `child.start_config` (`H.isolate()`, `child.restart`, `H.DISABLED_PLUGINS`) but with an extra `--cmd` ahead of `H.config_args()`: a `package.preload.lazy` that removes itself, requires the real lazy, wraps its `setup` to store `vim.g.mapleader` in `_G` at call time, and returns it; assert the stored value is `" "`. Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Leader"` and confirm both fail (`<D->` / `nil`).
- [x] 1.2 Add `vim.g.mapleader = " "` and `vim.g.maplocalleader = "\\"` as the first statements of `init.lua`; delete the `-- Leader keys` block at the end of `lua/gleb/keymaps.lua`; fix the comments on the `gleb.colors` / `gleb.keymaps` lines of `init.lua` (no false "before lazy.nvim" claims). Both cases pass.

## 2. Diffview conflict choices on Cmd chords

Scenarios: "git: Cmd+O chooses ours", "git: Cmd+I chooses theirs", "git: Cmd+D chooses base", "git: Cmd+A chooses all"

- [x] 2.1 Failing tests: sync the `git` delta into `openspec/specs/git/spec.md`. Add `tests/integration/git/test_diffview.lua` (new directory; no git integration tests exist yet) with one case per scenario: a temp git repo with a diff3 conflict (`merge.conflictStyle=diff3`, base `base`, ours `ours`, theirs `theirs`) in one file, `:cd` into it and `:DiffviewOpen` in a full-config child (`child.wait` until the view's diff windows exist), cursor inside the conflict in the main diff window, `nvim_input("<D-o>")` etc., then assert the working-file buffer lines and no `<<<<<<<`/`|||||||`/`=======`/`>>>>>>>` left. Confirm all four fail with `make test FILE=tests/integration/git/test_diffview.lua`.
- [x] 2.2 In `lua/gleb/git/diffview.lua` replace `<leader>co/ct/cb/ca` with `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>` (ours/theirs/base/all); `dx` unchanged. The four cases pass; `rg '<leader>' lua init.lua` finds nothing.

## 3. Cmd chords through Alacritty and zellij

Scenarios: "shortcuts: Cmd chords reach Neovim through real zellij", "shortcuts: Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press", "shortcuts: Alacritty bindings match the shortcut table", "shortcuts: Neovim receives the key in the table", "shortcuts: Every passed shortcut reaches its Neovim key through zellij", "shortcuts: Every passed shortcut reaches its Neovim key from a real key press"

- [x] 3.1 Failing tests: sync the `shortcuts` delta into `openspec/specs/shortcuts/spec.md` and add four `kitty` rows to its shortcut table: `Cmd+O | kitty | \e[111;9u | pass | <D-o> | none`, `Cmd+I … \e[105;9u … <D-i>`, `Cmd+D … \e[100;9u … <D-d>`, `Cmd+A … \e[97;9u … <D-a>`. Add the stack case to `tests/stack/shortcuts/` and the e2e case to `tests/e2e/shortcuts/test_e2e.lua` (recorders for `<D-x>`, `<M-x>` and the plain letters; assert exactly the four `<D-x>` hits in order; e2e also asserts Alacritty is alive). `make chain` and `make stack` run; the new cases fail only where the harness lacks support (fix that harness, not the expectation).
- [x] 3.2 Make the harness support the rows if needed. Expected none: `tests/shortcuts/chain.lua` already encodes and decodes the Super bit (`alacritty_kitty_bytes` Command = 8, `kitty_mods` → `D-`) and `tests/e2e/keys.swift` already maps `o`, `i`, `d`, `a`; touch `stack.lua` only if a stack case fails on the harness. `make chain` and `make stack` green.
- [x] 3.3 `make e2e` in the sandbox VM (`make check E2E=1`): the new e2e case and "Every passed shortcut reaches its Neovim key from a real key press" pass for the four rows. If a chord does not arrive as `<D-x>`, stop and escalate (the chord choice is a user decision); never drop the row.

## 4. Docs and gate

Scenarios: none (docs and the merge gate; every scenario above is already covered by tasks 1–3)

- [x] 4.1 `docs/architecture.md`: the load-order note says the leader (Space, fallback for plugin defaults) is set at the top of `init.lua`; rule 3.8 becomes "No `<leader>` maps in the config; Cmd shortcuts instead. Core keymap changes need user approval."; rule 3.7 adds that an unbound Cmd chord arrives as `<D-…>` (kitty protocol). Update the git spec text that still mentions `<D->` if any remains. `make trace` shows no orphan and every new scenario tested.
- [ ] 4.2 `make check E2E=1` green.
