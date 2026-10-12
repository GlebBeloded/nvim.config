## Why
The `<A-9>` menu (`normal_menu` in `lua/gleb/plugins/plugins.lua`) echoes `99> [s]earch [v]ibe: ` with `nvim_echo` and then blocks in `vim.fn.getchar()`. With `cmdheight = 0` (`lua/gleb/options.lua`) there is no message row and nothing redraws before `getchar()`, so the prompt is never drawn: the bottom row keeps the statusline while Neovim waits for the key. With `cmdheight = 1` the same echo shows. The `ai: Menu shows prompt` case in `tests/integration/ai/test_prompt_keys.lua` is `H.xfail` until this lands.

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.

## What Changes
- Make the menu prompt visible while it waits for the key with `cmdheight = 0`, e.g. raise `cmdheight` to 1 around the echo/`getchar()` and restore it, or show the menu with `vim.ui.select`/a float; prefer what `refactor-ai-99-config` settles on for where the menu lives.
- Remove the `H.xfail` from `ai: Menu shows prompt`.

## Capabilities
### Modified Capabilities
- None (`ai` `Menu shows prompt` already states the intended behaviour).

## Impact
- Code: `lua/gleb/plugins/plugins.lua` (or the module `refactor-ai-99-config` moves the menu to); `tests/integration/ai/test_prompt_keys.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: other `getchar()` prompts; changing `cmdheight` globally.
