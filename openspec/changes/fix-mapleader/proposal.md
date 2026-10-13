## Why
`vim.g.mapleader = "<D->"` (`lua/gleb/keymaps.lua:118`) is a literal 4-character string, not a key, and it is set after `require("gleb.plugins")` (`init.lua:6`) has run `lazy.setup`, so plugin `<leader>` maps (diffview `<leader>co/ct/cb/ca`, `lua/gleb/git/diffview.lua:34-37`) bind to the wrong keys. The comments on `init.lua:8-9` are false: colors is required after lazy.nvim (lazy only uses `install.colorscheme` while installing), and the mapleader is not set before lazy.nvim.

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.
Open question for the user: which key should `<leader>` be (e.g. `<Space>`, `,`, `\`)? `<D->` (Cmd) cannot be a leader: a terminal does not send Cmd as a modifier.

## What Changes
Per the Decision below:
- Set `vim.g.mapleader = " "` and `vim.g.maplocalleader = "\\"` at the top of `init.lua`, before `require("gleb.plugins")`; the leader is only a fallback for plugin defaults.
- Remove the leader assignments from the end of `lua/gleb/keymaps.lua`. Do not move `require("gleb.keymaps")`: it needs `smart-splits` and `telescope.builtin` at load time.
- Move the diffview conflict maps off `<leader>`: Cmd+O `<D-o>` ours, Cmd+I `<D-i>` theirs, Cmd+D `<D-d>` base, Cmd+A `<D-a>` all (`lua/gleb/git/diffview.lua`). `dx` (none) stays. These are the only `<leader>` maps the config defines.
- Add the four chords to the shortcut table as `kitty` rows (no Alacritty binding: Alacritty sends its kitty flag-1 encoding with the Super bit, zellij passes it, Neovim decodes `<D-…>`); prove them with an e2e scenario.
- Fix the comments on `init.lua:8-9` and the leader notes in `docs/architecture.md` (load-order note, rule 3.7/3.8).

## Capabilities
### Modified Capabilities
- `keymaps`: `Leader keys`: Space / `\`, set in `init.lua` before lazy.nvim loads.
- `git`: `Diffview view mappings`: conflict choices on `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`.
- `shortcuts`: shortcut table rows Cmd+O/I/D/A; a real key press delivers them as `<D-…>`.

## Impact
- Code: `init.lua`, `lua/gleb/keymaps.lua`, `lua/gleb/git/diffview.lua`; docs: `docs/architecture.md`. No change to `terminal/`.
- Plugins: none added, removed or upgraded.
- Core keymaps: changed: `<leader>` becomes Space (no config map uses it); diffview conflict choices move from `<leader>co/ct/cb/ca` to Cmd+O/I/D/A.
- Out of scope: moving `require("gleb.colors")`; adding new maps beyond the four conflict chords; `dx`; Cmd chords that Alacritty, the app menu or zellij take (`fix-cmd-q-shortcut`, `fix-cmd-shift-minus-equal`).

## Decision (user, 2026-10-12)
Cmd-based maps, no leader. Every map this config defines with `<leader>` (diffview conflict maps included) moves to a Cmd chord `<D-x>`, which reaches Neovim through Alacritty's kitty keyboard protocol. Pick chords Alacritty, the macOS app menu and zellij do not already take (Cmd+C/V/N/T/W/M/Q/H etc.; see the shortcut table and `fix-cmd-q-shortcut`), and prove each one with an e2e scenario in the sandbox VM (real Alacritty → zellij → Neovim). Set `vim.g.mapleader = " "` (Space) at the top of `init.lua`, before lazy.nvim, only as a fallback for plugin defaults; `maplocalleader` stays `\`.
