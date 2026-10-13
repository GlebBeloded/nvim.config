## MODIFIED Requirements

### Requirement: Global statusline layout
The config SHALL configure lualine with a global statusline (`laststatus=3`), no component or section separators, disabled for filetypes `alpha`, `dashboard` and `Outline`, with sections: a = mode; b = branch (icon U+E725), diff (symbols U+F457 added, U+F459 modified, U+F458 removed); c = navic breadcrumb; x = LSP progress, Copilot glyph, diagnostics (symbols U+F057 error, U+F071 warn), language chip; y and z empty; and an empty tabline.

#### Scenario: statusline is global
- **WHEN** the config has loaded (after `VimEnter`)
- **THEN** `vim.o.laststatus` is `3`

#### Scenario: mode section shows current mode
- **WHEN** a file buffer is open in Normal mode and the screen is redrawn
- **THEN** the last screen line starts with ` NORMAL `

#### Scenario: diagnostics always visible
- **WHEN** a buffer with no diagnostics is shown in a window wider than 80 columns
- **THEN** the statusline contains the error and warn symbols each followed by `0`

#### Scenario: diagnostics show error and warn counts
- **WHEN** `vim.diagnostic.set` adds 2 errors and 1 warning to the current buffer and the statusline refreshes
- **THEN** the statusline contains U+F057 followed by ` 2` and U+F071 followed by ` 1`

#### Scenario: diff hidden in narrow windows
- **WHEN** the current window is 80 columns wide or less and the buffer has git changes
- **THEN** the statusline contains none of the diff symbols U+F457, U+F459, U+F458

#### Scenario: navic breadcrumb shown when available
- **WHEN** nvim-navic reports a location for the current buffer (e.g. `Server ▸ Handle`)
- **THEN** that location text appears in the left half of the statusline

#### Scenario: statusline disabled on dashboard
- **WHEN** the current buffer has `filetype=alpha`
- **THEN** lualine does not render its sections for that window

### Requirement: Language chip
The config SHALL render, via `require("gleb.statusline.language").component()`, an empty string when `filetype` is empty; otherwise `<left cap><space><filetype logo><space><filetype><space><right cap>` where the left cap is the half-circle glyph U+E0B6 in highlight `StatuslineLangCapOk` if a non-stopped LSP client is attached to the current buffer and `StatuslineLangCapError` otherwise, and the right cap is the half-circle glyph U+E0B4 in `StatuslineLangEdge`.

#### Scenario: chip empty without filetype
- **WHEN** `vim.bo.filetype` is `""` and `component()` is called
- **THEN** it returns `""`

#### Scenario: chip shows error cap without LSP
- **WHEN** `vim.bo.filetype` is `lua`, no LSP client is attached, and `component()` is called
- **THEN** the result starts with `%#StatuslineLangCapError#`, contains `lua` and ends with `%#StatuslineLangEdge#` followed by U+E0B4

#### Scenario: chip shows ok cap with running LSP
- **WHEN** a running LSP client is attached to the current `lua` buffer and `component()` is called
- **THEN** the result starts with `%#StatuslineLangCapOk#` followed by U+E0B6

#### Scenario: chip has rounded caps
- **WHEN** `vim.bo.filetype` is `lua`, no LSP client is attached, and `component()` is called
- **THEN** the result starts with `%#StatuslineLangCapError#` followed by U+E0B6 and ends with U+E0B4

### Requirement: Copilot failure indicator
The config SHALL render, via `require("gleb.statusline.copilot").component()`, an empty string while Copilot has not been loaded or is healthy, and the Copilot glyph U+F4B8 (colored with the palette `err` color in the statusline) when Copilot is loaded and is disabled, failed to start, has no client, or reports status `Warning`.

#### Scenario: copilot glyph hidden before load
- **WHEN** `package.loaded["copilot.client"]` is nil and `component()` is called
- **THEN** it returns `""` and `copilot.client` is still not loaded

#### Scenario: copilot glyph hidden when healthy
- **WHEN** Copilot is loaded, enabled, started without error, has a client, and its status is not `Warning`
- **THEN** `component()` returns `""`

#### Scenario: copilot glyph shown when disabled
- **WHEN** Copilot is loaded and disabled (e.g. after `:Copilot disable`)
- **THEN** `component()` returns U+F4B8

#### Scenario: copilot glyph shown on warning
- **WHEN** Copilot is loaded with a client and its status is `Warning`
- **THEN** `component()` returns U+F4B8
