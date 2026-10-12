## MODIFIED Requirements

### Requirement: Language chip
The config SHALL render, via `require("gleb.statusline.language").component()`, an empty string when `filetype` is empty; otherwise `<left cap><space><filetype logo><space><filetype><space><right cap>` where the left cap uses highlight `StatuslineLangCapOk` if a non-stopped LSP client is attached to the current buffer and `StatuslineLangCapError` otherwise, and the right cap uses `StatuslineLangEdge`. Highlight groups are (re)defined on `ColorScheme` by a single autocmd in augroup `gleb_statusline_language` (created with `clear = true`). The logo highlight group is named `StatuslineLang_<filetype>` with every character outside `[%w_]` replaced by `_`.

#### Scenario: chip empty without filetype
- **WHEN** `vim.bo.filetype` is `""` and `component()` is called
- **THEN** it returns `""`

#### Scenario: chip shows error cap without LSP
- **WHEN** `vim.bo.filetype` is `lua`, no LSP client is attached, and `component()` is called
- **THEN** the result starts with `%#StatuslineLangCapError#`, contains `lua` and ends with `%#StatuslineLangEdge#`

#### Scenario: chip shows ok cap with running LSP
- **WHEN** a running LSP client is attached to the current `lua` buffer and `component()` is called
- **THEN** the result starts with `%#StatuslineLangCapOk#`

#### Scenario: chip logo highlight per filetype
- **WHEN** `component()` is called for a buffer with `filetype=lua`
- **THEN** highlight group `StatuslineLang_lua` exists with `bg` equal to the palette `chip_bg`

#### Scenario: chip highlights survive colorscheme change
- **WHEN** `:colorscheme <any>` is executed
- **THEN** highlight groups `StatuslineLangText`, `StatuslineLspOk`, `StatuslineLspError`, `StatuslineLangEdge`, `StatuslineLangCapOk` and `StatuslineLangCapError` are defined

#### Scenario: chip colorscheme autocmd not duplicated on reload
- **WHEN** `gleb.statusline.language` is required, then removed from `package.loaded` and required again
- **THEN** `nvim_get_autocmds({ group = "gleb_statusline_language", event = "ColorScheme" })` returns exactly one autocmd

#### Scenario: chip logo highlight name sanitized
- **WHEN** `component()` is called for a buffer with `filetype=foo-bar.baz`
- **THEN** highlight group `StatuslineLang_foo_bar_baz` exists with `bg` equal to the palette `chip_bg`
