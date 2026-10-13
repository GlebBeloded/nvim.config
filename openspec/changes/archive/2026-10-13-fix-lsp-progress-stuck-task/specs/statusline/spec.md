## ADDED Requirements

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
