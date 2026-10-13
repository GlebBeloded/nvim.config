## MODIFIED Requirements

### Requirement: Per-session log file
The config SHALL, when `require("gleb.nvim_debug_log").setup()` is called, create the directory `/tmp/nvim` if missing and start appending messages to `/tmp/nvim/<os.time()>_<pid>.txt`. Requiring the module without calling `setup()` SHALL NOT create the log file. The full config (`init.lua`) SHALL call `setup()` before any plugin loads.

#### Scenario: Log directory and file created
- **WHEN** `/tmp/nvim` does not exist and `require("gleb.nvim_debug_log").setup()` is called in a child Neovim, followed by `:echom "X"` and a wait of 3000 ms
- **THEN** `/tmp/nvim` exists and contains a file matching `<digits>_<child pid>.txt`

#### Scenario: Require alone does not log
- **WHEN** `require("gleb.nvim_debug_log")` is called in a child Neovim without `setup()`, followed by `:echom "X"` and a wait of 3000 ms
- **THEN** `/tmp/nvim` contains no file matching `<digits>_<child pid>.txt`

#### Scenario: Full config starts the log
- **WHEN** a child Neovim starts with the full config (`init.lua`), then `:echom "FULL_CONFIG_LOG"` and a wait of 3000 ms
- **THEN** `/tmp/nvim` contains a file matching `<digits>_<child pid>.txt` whose content includes `FULL_CONFIG_LOG`
