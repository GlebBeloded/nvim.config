## MODIFIED Requirements

### Requirement: Per-session log file
The config SHALL, when `require("gleb.nvim_debug_log").setup()` is called, create the directory `/tmp/nvim` if missing and start appending messages to `/tmp/nvim/<os.time()>_<pid>.txt`. Requiring the module without calling `setup()` SHALL NOT create the log file.

#### Scenario: Log directory and file created
- **WHEN** `/tmp/nvim` does not exist and `require("gleb.nvim_debug_log").setup()` is called in a child Neovim, followed by `:echom "X"` and a wait of 3000 ms
- **THEN** `/tmp/nvim` exists and contains a file matching `<digits>_<child pid>.txt`

#### Scenario: Require alone does not log
- **WHEN** `require("gleb.nvim_debug_log")` is called in a child Neovim without `setup()`, followed by `:echom "X"` and a wait of 3000 ms
- **THEN** `/tmp/nvim` contains no file matching `<digits>_<child pid>.txt`

### Requirement: Message capture
The config SHALL capture into the log file messages produced by `vim.notify`, `:echo`, `:echom`, and error messages.

#### Scenario: captures vim.notify
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called and then `vim.notify("TEST_notify")`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_notify` within 3000 ms

#### Scenario: captures :echo from ex command
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called and then `:echo "TEST_echo_excmd"`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_echo_excmd` within 3000 ms

#### Scenario: captures :echom from ex command
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called and then `:echom "TEST_echom_excmd"`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_echom_excmd` within 3000 ms

#### Scenario: captures errors
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called and then `vim.api.nvim_err_writeln("TEST_err_msg")`
- **THEN** the latest `/tmp/nvim/*.txt` contains `TEST_err_msg` within 3000 ms

### Requirement: Periodic flush
The config SHALL flush the log every 2000 ms during the session via a single repeating timer, and the flush SHALL NOT end or replace a redirection that the module did not start.

#### Scenario: periodic flush works during session
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called, then `:echom "FLUSH_DURING_SESSION"`, and the session stays open
- **THEN** the latest `/tmp/nvim/*.txt` contains `FLUSH_DURING_SESSION` within 3000 ms without the child exiting

#### Scenario: Other redirection survives a flush
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called, then `:redir => g:other`, `:echo "OTHER_REDIR"`, a wait of 3000 ms, `:echo "AFTER_FLUSH"`, and `:redir END`
- **THEN** `vim.g.other` contains both `OTHER_REDIR` and `AFTER_FLUSH`

#### Scenario: Setup twice logs once
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called twice, then `:echom "LOGGED_ONCE"` and a wait of 3000 ms
- **THEN** `#vim.api.nvim_get_autocmds({ event = "VimLeavePre" })` is 1 and the child's log file contains `LOGGED_ONCE` exactly once

### Requirement: Shutdown
The config SHALL, on `VimLeavePre` or when `require("gleb.nvim_debug_log").stop()` is called, stop the flush timer and end the log redirection.

#### Scenario: Log finalized on exit
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called, then `:echom "BEFORE_EXIT"`, then the child runs `:qa!` immediately
- **THEN** the latest `/tmp/nvim/*.txt` contains `BEFORE_EXIT`

#### Scenario: Stop ends logging
- **WHEN** `require("gleb.nvim_debug_log").setup()` is called, then `require("gleb.nvim_debug_log").stop()`, then `:echom "AFTER_STOP"` and a wait of 3000 ms
- **THEN** the child's log file does not contain `AFTER_STOP`
