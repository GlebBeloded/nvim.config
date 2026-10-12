## 1. ColorScheme autocmd in a cleared augroup

Scenarios: "statusline: chip colorscheme autocmd not duplicated on reload", "statusline: chip highlights survive colorscheme change"

- [x] 1.1 Add the failing unit test "statusline: chip colorscheme autocmd not duplicated on reload" to `tests/unit/statusline/test_language.lua`: set `package.loaded["gleb.statusline.language"] = nil`, require again, assert `#vim.api.nvim_get_autocmds({ group = "gleb_statusline_language", event = "ColorScheme" }) == 1`. Run `make test FILE=tests/unit/statusline/test_language.lua CASE="not duplicated"`; it fails (the group does not exist yet).
- [x] 1.2 Copy the delta's "Language chip" requirement (`specs/statusline/spec.md`) over the one in `openspec/specs/statusline/spec.md`, so `make trace` links the new cases instead of reporting them as orphans. The archive's MODIFIED replacement is then a no-op.
- [x] 1.3 In `lua/gleb/statusline/language.lua`, create augroup `gleb_statusline_language` with `{ clear = true }` and pass it as `group` to the `ColorScheme` autocmd; replace the anonymous callback with a named local function (`on_colorscheme`).
- [x] 1.4 Run `make test CASE=chip`; the new test and the integration test "chip highlights survive colorscheme change" pass.

## 2. Sanitized logo highlight name

Scenarios: "statusline: chip logo highlight name sanitized", "statusline: chip logo highlight per filetype"

- [x] 2.1 Add the failing unit test "statusline: chip logo highlight name sanitized" to `tests/unit/statusline/test_language.lua`: `filetype=foo-bar.baz`, call `component()`, assert `nvim_get_hl(0, { name = "StatuslineLang_foo_bar_baz" }).bg` equals the palette `chip_bg` (same shape as "chip logo highlight per filetype"). Run it; it fails (only `StatuslineLang_foo-bar.baz` is defined).
- [x] 2.2 In `logo()`, build the group name with a small named helper `logo_group(filetype)` returning `"StatuslineLang_" .. filetype:gsub("[^%w_]", "_")` (wrap the `gsub` in parentheses to drop its count); keep `logo_defined` keyed by filetype.
- [x] 2.3 Run `make test CASE=chip`, then `make check`; all pass, including "chip logo highlight per filetype", and `make trace` shows both new scenarios as tested with no orphans.
