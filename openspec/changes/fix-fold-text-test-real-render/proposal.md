## Why
Review of fix-fold-text-current-buffer (b118d5f) noted: `tests/integration/folding/test_fold_text.lua` calls `ufo.config.fold_virt_text_handler` directly with a synthetic `ctx`, so it never exercises ufo's real render of a closed fold in a non-current window, and the Lua assertion `"}"` would also pass if the Go handler ran. Also the folding handler modules lack LuaCATS annotations for the new `bufnr` parameter (`lua/gleb/folding/go.lua`, `lua/gleb/folding/lua.lua`).

Kind: bug

## Evidence
- Review notes in run d4c71ec6 escalation.md (`- note: review (minor)`).

## What Changes
- Make the case open a Go and a Lua buffer in a split, close a fold in each, let ufo render, and assert each window's fold virtual text comes from its own handler with handler-specific text (an assertion the other handler cannot satisfy). Task 1.1 shows it failing by temporarily using the current buffer's filetype in the handler.
- Add `---@class`/`---@param`/`---@return` annotations to the handler modules.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/folding/test_fold_text.lua`, `lua/gleb/folding/*.lua` (annotations only).
- Plugins: none.
