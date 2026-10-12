## Why
The language chip builds its highlight name from data (`"StatuslineLang_" .. filetype`, `lua/gleb/statusline/language.lua:66`) without sanitizing it (convention rule 4.5), and its `ColorScheme` autocmd (`language.lua:37-42`) has no augroup, so re-sourcing the module adds a second autocmd (rule 7.1).
Verified on NVIM v0.12.5: names with `-` or `.` are accepted by `nvim_set_hl` and render in the statusline, and `'filetype'` rejects other characters (`set ft=a+b` gives E474). So the unsanitized name causes no visible bug today; the sanitizing is a convention fix with no behaviour change.

Kind: bug

## What Changes
- Build the logo group name with the filetype sanitized to `[%w_]` (e.g. `gsub("[^%w_]", "_")`); `StatuslineLang_lua` keeps its name, so the scenario "chip logo highlight per filetype" still holds.
- Create the `ColorScheme` autocmd in an augroup `gleb_statusline_language` with `clear = true`.

## Capabilities
### Modified Capabilities
- None (`skip_specs: true`: the "Language chip" requirement and its scenarios are unchanged).

## Impact
- Code: `lua/gleb/statusline/language.lua`; a unit test that a filetype with `-`/`.` maps to a sanitized group and that re-requiring the module leaves one `ColorScheme` autocmd in the group.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: the empty `CAP_LEFT`/`CAP_RIGHT` glyphs (`fix-empty-nerd-font-glyphs`), chip layout and colors.
