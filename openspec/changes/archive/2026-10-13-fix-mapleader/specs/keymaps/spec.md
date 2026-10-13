## MODIFIED Requirements

### Requirement: Leader keys
The config SHALL set `g:mapleader` to Space (`" "`) and `g:maplocalleader` to `\` in `init.lua` before lazy.nvim is set up, so every `<leader>` map a plugin defines while loading binds to Space.

#### Scenario: Leader values after startup
- **WHEN** the full config is loaded and `vim.g.mapleader` and `vim.g.maplocalleader` are read
- **THEN** `vim.g.mapleader == " "` and `vim.g.maplocalleader == "\\"`

#### Scenario: Leader is set before lazy.nvim loads plugins
- **WHEN** the full config is started with a `--cmd` hook that wraps `require("lazy").setup` to record `vim.g.mapleader` at call time
- **THEN** the recorded value is `" "`
