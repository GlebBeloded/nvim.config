## MODIFIED Requirements

### Requirement: Old log pruning
The config SHALL, when `require("gleb.nvim_debug_log").setup()` starts the log (before the current session's file is created), delete every file in `/tmp/nvim` whose name is `<digits>_<digits>.txt` and whose leading `<digits>` (the `os.time()` the file was created at) is more than 7 days (604800 s) before now. It SHALL NOT delete any other file, nor files of that name format that are 7 days old or newer. Requiring the module without calling `setup()` SHALL NOT delete anything.

#### Scenario: logs older than 7 days are deleted
- **WHEN** `/tmp/nvim` contains `<os.time() - 8 days>_<unused pid>.txt` and `<os.time() - 1 day>_<other unused pid>.txt`, and `require("gleb.nvim_debug_log").setup()` is called in a child Neovim
- **THEN** the 8-day-old file no longer exists and the 1-day-old file still exists

#### Scenario: other files in the log directory are kept
- **WHEN** `/tmp/nvim` contains `<os.time() - 8 days>_<unused pid>.log` and `notes_<os.time() - 8 days>.txt`, and `require("gleb.nvim_debug_log").setup()` is called in a child Neovim
- **THEN** both files still exist
