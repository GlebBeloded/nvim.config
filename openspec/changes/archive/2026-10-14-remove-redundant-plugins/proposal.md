## Why
Two plugins duplicate something already in place. `echasnovski/mini.diff` (`plugins/plugins.lua:236-242`, `setup({})`) draws hunk signs next to gitsigns (`git/gitsigns.lua`, the spec's "Gutter signs") and hides them. lazy.nvim loads mini.diff from `require("gleb.plugins")` before `require("gleb.options")` sets `number = true` (`init.lua:6-7`), so mini.diff's default `view.style` resolves to `"sign"`. Its `▒` sign (`MiniDiffSignAdd`, extmark priority 199) and gitsigns' `┃` (priority 6) land on the same line, and with `signcolumn = "yes"` only one fits: the screen shows `▒`, never the `┃` the spec requires. Checked in a tmux capture of the full config on an added line. `lewis6991/impatient.nvim` (`plugins/plugins.lua:8`) is installed, never required, and superseded by `vim.loader.enable()` (`options.lua:59`).

Kind: bug

## What Changes
- Remove the `echasnovski/mini.diff` and `lewis6991/impatient.nvim` specs from `plugins.lua` and their entries from `lazy-lock.json`.

## Capabilities
### Modified Capabilities
- `git`: "Gutter signs" gains a reference-screenshot scenario that asserts the `┃` sign is what the screen draws on an added line. The existing scenario checks only gitsigns' extmark, which is why the hidden sign went unnoticed. No requirement covers impatient.nvim.

## Impact
- Code: `lua/gleb/plugins/plugins.lua`, `lazy-lock.json`; tests: new `tests/screen/git/` screen test and reference screenshot, a `git-hunk` case in `tests/render/cases.lua`
- Plugins: removed `echasnovski/mini.diff` and `lewis6991/impatient.nvim`; none added or upgraded
- Core keymaps: unchanged. mini.diff's default buffer maps go away (`gh`/`gH` apply/reset hunk and textobject, `[h`/`]h`/`[H`/`]H` hunk jumps); this config never referenced them, and gitsigns' `:Gitsigns` commands cover the same actions.
- Out of scope: diffview.nvim (kept on purpose for comparison with differ.nvim), adding gitsigns hunk keymaps.
