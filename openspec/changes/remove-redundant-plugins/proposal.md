## Why
Two plugins duplicate something already in place. `echasnovski/mini.diff` (`plugins/plugins.lua:236-242`, `setup({})`) draws hunk indicators next to gitsigns (`git/gitsigns.lua`, the spec's "Gutter signs"); with `number = true` (`options.lua:28`) mini.diff colors the line numbers while gitsigns draws `┃` signs. `lewis6991/impatient.nvim` (`plugins/plugins.lua:8`) is installed, never required, and superseded by `vim.loader.enable()` (`options.lua:59`).

Kind: bug

## What Changes
- Remove the `echasnovski/mini.diff` and `lewis6991/impatient.nvim` specs from `plugins.lua` and their entries from `lazy-lock.json`.

## Capabilities
### Modified Capabilities
None. No spec requirement covers mini.diff or impatient.nvim; gitsigns stays the only hunk sign source, as the git spec already says. `skip_specs: true`.

## Impact
- Code: `lua/gleb/plugins/plugins.lua`, `lazy-lock.json`
- Plugins: removed `echasnovski/mini.diff` and `lewis6991/impatient.nvim`; none added or upgraded
- Core keymaps: unchanged. mini.diff's default buffer maps go away (`gh`/`gH` apply/reset hunk and textobject, `[h`/`]h`/`[H`/`]H` hunk jumps); this config never referenced them, and gitsigns' `:Gitsigns` commands cover the same actions.
- Out of scope: diffview.nvim (kept on purpose for comparison with differ.nvim), adding gitsigns hunk keymaps.
