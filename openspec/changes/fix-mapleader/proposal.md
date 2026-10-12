## Why
`vim.g.mapleader = "<D->"` (`lua/gleb/keymaps.lua:118`) is a literal 4-character string, not a key, and it is set after `require("gleb.plugins")` (`init.lua:6`) has run `lazy.setup`, so plugin `<leader>` maps (diffview `<leader>co/ct/cb/ca`, `lua/gleb/git/diffview.lua:34-37`) bind to the wrong keys. The comments on `init.lua:8-9` are false: colors is required after lazy.nvim (lazy only uses `install.colorscheme` while installing), and the mapleader is not set before lazy.nvim.

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.
Open question for the user: which key should `<leader>` be (e.g. `<Space>`, `,`, `\`)? `<D->` (Cmd) cannot be a leader: a terminal does not send Cmd as a modifier.

## What Changes
- Set `vim.g.mapleader` (and `vim.g.maplocalleader`) at the top of `init.lua`, before `require("gleb.plugins")`, to the key the user picks.
- Remove the leader assignments from the end of `lua/gleb/keymaps.lua`. Do not move `require("gleb.keymaps")`: it needs `smart-splits` and `telescope.builtin` at load time (`keymaps.lua:9-12`, `:105`).
- Fix the comments on `init.lua:8-9` (colors is not required before lazy.nvim; the leader no longer lives in keymaps.lua).
- Update the `Leader keys` requirement in `openspec/specs/keymaps/spec.md` to the chosen value and location.

## Capabilities
### Modified Capabilities
- `keymaps`: `Leader keys` gets the chosen leader value, set in `init.lua` before lazy.nvim loads, so plugin `<leader>` maps resolve to it.

## Impact
- Code: `init.lua`, `lua/gleb/keymaps.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: changed: `<leader>` becomes a real key, so diffview conflict maps `<leader>co/ct/cb/ca` become usable.
- Out of scope: moving `require("gleb.colors")`; adding new `<leader>` maps; `maplocalleader` value (stays `\` unless the user says otherwise).
