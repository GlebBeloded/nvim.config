## Why
`make types` (LuaLS `--checklevel=Warning`) is green only because `.luarc.jsonc` downgrades five diagnostic codes to `Information`. A run at `--checklevel=Information` on 2026-10-12 (lua-language-server 3.19.1) lists the hits below, so restoring `Warning` today would fail the gate.

Kind: bug

## What Changes
Fix the hits, then delete each code's line from `"diagnostics.severity"` in `.luarc.jsonc` (back to the default `Warning`):
- `param-type-mismatch` (13):
  - `lua/gleb/colors/gruvbox-material/init.lua:9` and `lua/gleb/file_tree/diff_preview.lua:81`, `:155`: `pcall(vim.cmd, "<string>")` (`vim.cmd` is typed as a table); use `pcall(vim.cmd --[[@as fun(cmd: string)]], ...)` or `pcall(vim.api.nvim_command, ...)`.
  - `lua/gleb/colors/gruvbox-material/util/init.lua:17` (x2): `integer?` passed to `rgb_to_hex`; make `hsl_to_rgb` return non-optional integers.
  - `lua/gleb/plugins/plugins.lua:338`: `vim.fn.getchar()` returns `string|integer`; handle the string case before `nr2char`.
  - `lua/gleb/run/init.lua:3`: `vim.fn.finddir` returns `string|string[]`; narrow it to a string.
  - New since the findings: `tests/render/colorize.lua:234`, `:236` (x2) (`vim.NIL|get_hl_info`), `tests/shortcuts/chain.lua:116` (`number?` to `nr2char`), `tests/shortcuts/stack.lua:140`, `:260` (`table<string, string?>` env).
- `deprecated` (4): `lua/gleb/lsp/config/python/typecheck.lua:7` `vim.lsp.stop_client` -> `client:stop()`. `lua/gleb/keymaps.lua:109`, `:111`, `:114` (`vim.diagnostic.goto_*`) are fixed by change `fix-diagnostic-navigation`; restore `deprecated` to Warning only after it has landed (or fix them here if it has not).
- `undefined-doc-name` (2): `SessionConfig` (`lua/gleb/file_tree/diff_preview.lua:60`, codediff) and `LazyPluginSpec` (`lua/gleb/plugins/plugins.lua:50`, lazy.nvim). Plugin sources are not in the LuaLS library; either add the needed plugin type files to `workspace.library` (installed by `make deps`), or replace the annotations with local types (convention rule 5.3 prefers the plugin's own types).
- `duplicate-set-field` (1): `lua/gleb/select/init.lua:13` overrides `vim.ui.select`; add `---@diagnostic disable-next-line: duplicate-set-field` with a reason, since the override is intended.
- `need-check-nil` (1): `lua/gleb/statusline/lsp_progress.lua:75` is fixed by change `fix-lsp-progress-stuck-task`; restore after it lands (or fix here with a local timer variable).
- Run `make types` with the downgrades removed; it must pass.

## Capabilities
### Modified Capabilities
- None (`skip_specs: true`: type annotations and narrowing only, no behaviour change).

## Impact
- Code: the files listed above, `.luarc.jsonc`, possibly `tests/types.sh` / `tests/bootstrap.sh` if plugin type libraries are added.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: new diagnostics codes beyond these five, `--checklevel=Information` hits of other codes, and the behaviour changes owned by `fix-diagnostic-navigation` and `fix-lsp-progress-stuck-task`.
