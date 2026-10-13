# Design

## Context
See proposal.md - Why. A re-run on 2026-10-13 (lua-language-server 3.19.1, `make deps` done, `--checklevel=Information`) lists 28 hits of the five codes. Line numbers moved since the proposal; the hits per root cause:

| Code | Site | Root cause |
|---|---|---|
| param-type-mismatch | `gruvbox-material/init.lua:9`, `file_tree/diff_preview.lua:87`, `:161` | `pcall(vim.cmd, ...)`: `vim.cmd` is typed as a callable table, `pcall` wants a function |
| param-type-mismatch | `gruvbox-material/util/init.lua:17` (x2) | `convert.rgb_to_hsl` is annotated `integer?` (and 0-360) but returns non-nil numbers in 0..1; the `?` flows into `hsl_to_rgb` |
| param-type-mismatch | `plugins/plugins.lua:343` | `vim.fn.getchar()` returns `string\|integer` |
| param-type-mismatch | `run/init.lua:3` | `vim.fn.finddir` is typed `string\|string[]`; with the default count it returns a string |
| param-type-mismatch | `tests/render/colorize.lua:232`, `:234` (x2) | `hls` values are `colorize.Hl\|vim.NIL`; comparing with `vim.NIL` does not narrow |
| param-type-mismatch | `tests/shortcuts/chain.lua:116` | `tonumber()` returns `number?` |
| param-type-mismatch | `tests/shortcuts/stack.lua:142`, `:283`, `tests/e2e/shortcuts/test_e2e.lua:271` | `Stack.env` is declared `table<string, string?>`; a Lua table never holds nil values, so the `?` is spurious |
| param-type-mismatch | `tests/unit/loop/test_cleanup.lua:158`, `:159`, `:187`, `:188`, `:189`, `:193`, `:202`, `:204` | a string is passed as the third argument of `MiniTest.expect.equality`, which takes an `opts` table. mini.test reads `opts.fail_reason`, which is nil on a string, so the message is silently dropped on failure. This is a real bug, not only a type issue |
| undefined-doc-name | `file_tree/diff_preview.lua:66` `SessionConfig`, `plugins/plugins.lua:59` `LazyPluginSpec` | vscode-diff.nvim and lazy.nvim are not in `workspace.library`; lazydev supplies them only in the editor |
| deprecated | `lsp/config/python/typecheck.lua:7` | `vim.lsp.stop_client` |
| duplicate-set-field | `select/init.lua:13` | intended override of `vim.ui.select` |
| need-check-nil | `statusline/lsp_progress.lua:75` | `timer` is an upvalue, so LuaLS cannot narrow it after `uv.new_timer()` |

`keymaps.lua` `deprecated` hits are gone: `fix-diagnostic-navigation` is archived. `fix-lsp-progress-stuck-task` is still queued.

## Goals / Non-Goals

**Goals:**
- `make types` passes with all five downgrades removed from `.luarc.jsonc`.
- Plugin types come from the plugin sources at the commits pinned in `lazy-lock.json` (rule 5.3), without needing the user's lazy install.

**Non-Goals:**
- Behaviour changes, except restoring the dropped failure messages in `test_cleanup.lua`.
- Typing the rest of the plugin APIs, or adding other plugins to the library beyond the two that are referenced.

## Decisions
- **`pcall(vim.cmd, s)` → `pcall(vim.api.nvim_command, s)`.** `nvim_command` is the function `vim.cmd(string)` calls and is typed `fun(command: string)`, so no cast is needed. Alternative: an `--[[@as fun(cmd: string)]]` cast, which hides the type instead of using a typed API.
- **Fix `convert.lua` annotations, not the call site.** `rgb_to_hsl` returns `number` (0..1, non-optional) and `hsl_to_rgb` takes `number`s; the comments say 0..1. The annotations are wrong, the code is right.
- **`vim.fn.nr2char(vim.fn.getchar())` → `vim.fn.getcharstr()`.** Built-in since 0.9, returns the key as a string, one call. Alternative: branch on `type()`, more code for the same result.
- **`finddir` → `--[[@as string]]` cast.** With no count argument `finddir` returns a string (documented); `vim.fs.root` would change the start directory from cwd to the buffer, which is a behaviour change.
- **`colorize.lua`: narrow through a small typed helper** (`---@return colorize.Hl?`) that maps `vim.NIL` to nil, then `or base`. LuaLS does not narrow `vim.NIL` checks, so the existing `--[[@as colorize.Hl]]` cast moves into the helper (commented); call sites have none.
- **`chain.lua`: `tonumber(code) --[[@as integer]]`**: the Lua pattern `(%d+)` guarantees digits.
- **`Stack.env` typed `table<string, string>`**; the constructor that reads `vim.env.*` gets one `--[[@as table<string, string>]]` cast with a comment that nil values are absent keys. Alternative: widen `run`'s parameter, which only moves the mismatch to `vim.system`.
- **`test_cleanup.lua`: pass `{ fail_reason = <msg> }`.** mini.test's documented option; the message then shows as the failure headline, with Left/Right context kept.
- **Plugin types: `tests/bootstrap.sh` also fetches lazy.nvim and vscode-diff.nvim into `.tests/deps/`**, at the commits read from `lazy-lock.json` (shallow fetch, same pattern as mini.nvim), and `.luarc.jsonc` adds `.tests/deps/lazy.nvim` and `.tests/deps/vscode-diff.nvim` to `workspace.library`. `tests/types.sh` adds both HEADs to its cache key. Library files are not diagnosed (LuaLS default). Alternatives: local `---@class` stand-ins (violates rule 5.3), pointing at `~/.local/share/nvim/lazy` (not reproducible, absent in the sandbox), or dropping the annotations (loses checking of the spec tables).
- **`vim.lsp.stop_client(client.id)` → `client:stop()`.**
- **`vim.ui.select` override: `---@diagnostic disable-next-line: duplicate-set-field` with a reason comment** (the override is the module's purpose).
- **`lsp_progress.lua`: local timer in `ensure_timer`** (`local t = assert(uv.new_timer())`, start `t`, then assign `timer = t`). This is the same edit `fix-lsp-progress-stuck-task` plans; whichever lands second keeps it.

## Risks / Trade-offs
- [Adding the plugin libraries surfaces new Warning-level hits in `diff_preview.lua` or `plugins.lua` now that their types resolve] → fix them in this change if they belong to the five codes; anything else gets queued as a change, not suppressed.
- [`lazy-lock.json` bumps (`make update`) change the fetched commits] → bootstrap reads the commit from the lock file, so the library follows the pin; the types cache key covers it.
- [Merge conflict with `fix-lsp-progress-stuck-task` on `ensure_timer`] → identical intent, resolve by keeping the local-variable form.
- [`fail_reason` messages in `test_cleanup.lua` may be long command output] → acceptable for a failing test; this is what the author intended.
