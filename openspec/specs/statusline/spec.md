# statusline Specification

## Purpose
A single global lualine statusline styled from the gruvbox-material palette, showing mode, git branch/diff, navic breadcrumb, delayed LSP progress, a Copilot failure glyph, diagnostics and an LSP-health language chip.

## Requirements

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

### Requirement: Statusline visual style
The config SHALL color the statusline from `gleb.statusline.palette` (derived from the gruvbox-material palette: bar = `bg0` blended 5% toward orange and brightened 2%; mode accents normal=green, insert=blue, visual=purple, replace=red, command=yellow, terminal=aqua; section a text in `bg0`, bold; inactive text in `bg5`) and render the language chip as a rounded pill with `chip_bg` background.

#### Scenario: statusline matches reference screenshot
- **WHEN** a Lua file is open in Normal mode with gruvbox-material active, no LSP client attached to its buffer, and `MiniTest` child `expect.reference_screen()` is taken of the statusline row
- **THEN** it matches the stored reference screenshot, including mode accent, bar color and language chip, and in an 80-column statusline the chip takes columns 72–80 with the left cap in `StatuslineLangCapError` and the right cap in `StatuslineLangEdge`

#### Scenario: insert mode accent matches reference screenshot
- **WHEN** `i` is pressed in Normal mode, no LSP client is attached to the buffer, and a screenshot of the statusline row is taken
- **THEN** it matches the stored reference screenshot with the insert (blue) accent on the mode section, and the chip takes columns 72–80 with the left cap in `StatuslineLangCapError` and the right cap in `StatuslineLangEdge`

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

### Requirement: Language chip highlights
The config SHALL (re)define the language chip highlight groups on `ColorScheme` by a single autocmd in augroup `gleb_statusline_language` (created with `clear = true`), and SHALL name the logo highlight group `StatuslineLang_<filetype>` with every character outside `[%w_]` replaced by `_`.

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

### Requirement: Delayed LSP progress
The config SHALL track `LspProgress` events per `<client_id>:<token>` (`begin` adds a task, `report` updates its message/percentage, `end` removes it) and render, via `require("gleb.statusline.lsp_progress").progress()`, one entry per task active for at least 500 ms as `<spinner> <label>` or `<spinner> <label> <pct>%%`, joined by two spaces. Every event SHALL be appended to `/tmp/nvim-lsp-progress.log`.

#### Scenario: progress hidden before 500 ms
- **WHEN** an `LspProgress` event with `kind=begin`, `title="Indexing"` fires and `progress()` is called immediately
- **THEN** it returns `""`

#### Scenario: progress shown after 500 ms with alias
- **WHEN** an `LspProgress` `begin` with `message="Setting up workspace"`, `percentage=40` fires and `progress()` is called after 500 ms
- **THEN** it returns `<spinner> indexing workspace 40%%` where `<spinner>` is one of `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`

#### Scenario: report updates percentage
- **WHEN** a `begin` with `title="Building"` is followed by a `report` with `percentage=75` for the same token, and `progress()` is called after 500 ms
- **THEN** it returns `<spinner> building 75%%`

#### Scenario: end removes the task
- **WHEN** a `begin` is followed by an `end` for the same client and token, and `progress()` is called after 500 ms
- **THEN** it returns `""`

#### Scenario: concurrent tasks joined
- **WHEN** two tokens have active tasks older than 500 ms
- **THEN** `progress()` returns both entries separated by two spaces

#### Scenario: progress events are logged
- **WHEN** any `LspProgress` event fires
- **THEN** a line containing its `kind`, `title`, `message` and percentage is appended to `/tmp/nvim-lsp-progress.log`

### Requirement: LSP progress cleanup
The config SHALL remove all progress tasks of a client on `LspDetach` when that client is gone, is stopped, or the detaching buffer is its last attached buffer, and SHALL remove a task that has had no `begin` or `report` event for 60 s. The statusline refresh timer of `gleb.statusline.lsp_progress` SHALL run only while a task is active and SHALL be stopped on `VimLeavePre`.

#### Scenario: detached client tasks are removed
- **WHEN** a `begin` fires for client 1, then `LspDetach` fires with `data.client_id = 1` while `vim.lsp.get_client_by_id(1)` returns `nil`, and `progress()` is called after 500 ms
- **THEN** it returns `""`

#### Scenario: detach keeps tasks of a client still attached elsewhere
- **WHEN** a `begin` fires for client 1, then `LspDetach` fires for buffer 1 with `data.client_id = 1` while `vim.lsp.get_client_by_id(1)` returns a running client attached to buffers 1 and 2, and `progress()` is called after 500 ms
- **THEN** it returns one entry for that task

#### Scenario: stale task is removed
- **WHEN** a `begin` fires and `vim.uv.hrtime` then advances by more than 60 s without another event for that token
- **THEN** `progress()` returns `""`

#### Scenario: report keeps a task fresh
- **WHEN** a `begin` fires, `vim.uv.hrtime` advances by 40 s, a `report` fires for the same token, and `vim.uv.hrtime` advances by another 40 s
- **THEN** `progress()` returns one entry for that task

#### Scenario: refresh timer stops when idle
- **WHEN** `require("lualine").refresh` is replaced by a call counter, a `begin` is followed by an `end` for the same token, and 300 ms pass
- **THEN** the counter no longer increases

#### Scenario: refresh timer stops on exit
- **WHEN** `require("lualine").refresh` is replaced by a call counter, a `begin` fires without an `end`, and `VimLeavePre` is triggered
- **THEN** the counter no longer increases

### Requirement: LSP progress labels
The config SHALL label a progress entry with the first alias matching its message, else the message verbatim, else the first alias matching its title, else the title, else `working`. Aliases (first match wins): `[Ss]etting up workspace`→`indexing workspace`, `[Ll]oading`→`loading`, `[Ii]ndex`→`indexing`, `[Dd]iagnos`→`checking`, `[Dd]ownload`→`downloading deps`, `[Bb]uild`→`building`, `[Ff]ormat`→`formatting`, `[Pp]rocessing`→`processing`.

#### Scenario: progress falls back to working
- **WHEN** a `begin` event without title or message fires and `progress()` is called after 500 ms
- **THEN** it returns `<spinner> working`

#### Scenario: unmatched message shown verbatim
- **WHEN** a `begin` event with `message="Resolving"` fires and `progress()` is called after 500 ms
- **THEN** it returns `<spinner> Resolving`

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
