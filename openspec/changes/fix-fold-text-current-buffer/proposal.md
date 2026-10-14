## Why
The ufo fold-text handler (`lua/gleb/folding/init.lua`, `folding/go.lua`, `folding/lua.lua`) reads `vim.bo.filetype` and the current buffer's lines; ufo calls it for every visible window, so in a Go | Lua split folds in the other window get the wrong handler and text.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/folding/init.lua:24-30` accepts only five handler arguments and selects the language handler from `vim.bo.filetype`, which belongs to the current buffer.
- `lua/gleb/folding/go.lua:4-5` and `lua/gleb/folding/lua.lua:3-4` read folded lines from `nvim_get_current_buf()`.
- `/Users/hlebbeladzed/.local/share/nvim/lazy/nvim-ufo/lua/ufo/decorator.lua:264-295` renders an explicit `bufnr` and passes that buffer as `ctx.bufnr` in the handler's sixth argument. The configured handlers ignore it, so rendering a non-current split reads and dispatches against the wrong buffer.

## What Changes
- Use the handler's `ctx.bufnr` (6th argument) for filetype and lines; test: a split with a Go and a Lua buffer renders each window's fold text with its own handler.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### New Capabilities
- `folding`: fold text is selected and generated from the buffer being rendered.

### Modified Capabilities
- None.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
- Core keymaps: unchanged.
- Out of scope: changing fold-text wording, styling, providers, or fold keymaps.
