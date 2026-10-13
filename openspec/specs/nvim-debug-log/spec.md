# nvim-debug-log Specification

## Purpose
Session message logging loaded first in `init.lua` (`lua/gleb/nvim_debug_log/`): all Neovim messages are redirected to a per-session file under `/tmp/nvim/` and flushed periodically so the log is readable while the session runs.

## Requirements
### Requirement: Per-session log file
The config SHALL, when `gleb.nvim_debug_log` is required, create the directory `/tmp/nvim` if missing and start appending messages (`:redir >>`) to `/tmp/nvim/<os.time()>_<pid>.txt`.

#### Scenario: Log directory and file created
- **WHEN** `/tmp/nvim` does not exist and `require("gleb.nvim_debug_log")` is called in a child Neovim, followed by `:echom "X"` and a wait of 3000 ms
- **THEN** `/tmp/nvim` exists and contains a file matching `<digits>_<child pid>.txt`

### Requirement: Message capture
The config SHALL capture into the log file messages produced by `vim.notify`, `:echo`, `:echom`, and error messages.

#### Scenario: captures vim.notify
- **WHEN** `require("gleb.nvim_debug_log")` is called and then `vim.notify("TEST_notify")`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_notify` within 3000 ms

#### Scenario: captures :echo from ex command
- **WHEN** `require("gleb.nvim_debug_log")` is called and then `:echo "TEST_echo_excmd"`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_echo_excmd` within 3000 ms

#### Scenario: captures :echom from ex command
- **WHEN** `require("gleb.nvim_debug_log")` is called and then `:echom "TEST_echom_excmd"`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_echom_excmd` within 3000 ms

#### Scenario: captures errors
- **WHEN** `require("gleb.nvim_debug_log")` is called and then `vim.api.nvim_err_writeln("TEST_err_msg")`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_err_msg` within 3000 ms

### Requirement: Periodic flush
The config SHALL flush the log every 2000 ms during the session by ending and restarting the redirection to the same file, via a repeating timer.

#### Scenario: periodic flush works during session
- **WHEN** `require("gleb.nvim_debug_log")` is called, then `:echom "FLUSH_DURING_SESSION"`, and the session stays open
- **THEN** the latest `/tmp/nvim/*.txt` contains `FLUSH_DURING_SESSION` within 3000 ms without the child exiting

### Requirement: Shutdown
The config SHALL, on `VimLeavePre`, stop the flush timer and end the redirection.

#### Scenario: Log finalized on exit
- **WHEN** `require("gleb.nvim_debug_log")` is called, then `:echom "BEFORE_EXIT"`, then the child runs `:qa!` immediately
- **THEN** the latest `/tmp/nvim/*.txt` contains `BEFORE_EXIT`

### Requirement: Old log pruning
The config SHALL, when the debug log starts (before the current session's file is created), delete every file in `/tmp/nvim` whose name is `<digits>_<digits>.txt` and whose leading `<digits>` (the `os.time()` the file was created at) is more than 7 days (604800 s) before now. It SHALL NOT delete any other file, nor files of that name format that are 7 days old or newer.

#### Scenario: logs older than 7 days are deleted
- **WHEN** `/tmp/nvim` contains `<os.time() - 8 days>_<unused pid>.txt` and `<os.time() - 1 day>_<other unused pid>.txt`, and `require("gleb.nvim_debug_log")` is called in a child Neovim
- **THEN** the 8-day-old file no longer exists and the 1-day-old file still exists

#### Scenario: other files in the log directory are kept
- **WHEN** `/tmp/nvim` contains `<os.time() - 8 days>_<unused pid>.log` and `notes_<os.time() - 8 days>.txt`, and `require("gleb.nvim_debug_log")` is called in a child Neovim
- **THEN** both files still exist
