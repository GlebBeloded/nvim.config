## ADDED Requirements

### Requirement: LSP progress log size cap
The config SHALL, before appending a progress event line, empty the LSP progress log when it is larger than 1 MiB (1048576 bytes), so the log never exceeds 1 MiB plus one line. The log is `/tmp/nvim-lsp-progress.log`, or the path in `$NVIM_LSP_PROGRESS_LOG` when that variable is set and not empty at module load.

#### Scenario: oversized progress log is truncated
- **WHEN** `$NVIM_LSP_PROGRESS_LOG` points to a file of 1048577 bytes, `gleb.statusline.lsp_progress` is loaded and an `LspProgress` `begin` event fires
- **THEN** that file is smaller than 1048576 bytes and contains the line for the event

#### Scenario: progress log under the cap is appended
- **WHEN** `$NVIM_LSP_PROGRESS_LOG` points to a file with one line `KEEP`, `gleb.statusline.lsp_progress` is loaded and an `LspProgress` `begin` event fires
- **THEN** the file's first line is still `KEEP` and its second line is the event's line
