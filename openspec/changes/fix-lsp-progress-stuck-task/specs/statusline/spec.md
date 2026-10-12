## ADDED Requirements

### Requirement: LSP progress cleanup
The config SHALL remove all progress tasks of a client when it detaches or stops, and SHALL remove a task that has had no `begin` or `report` event for 60 s. The statusline refresh timer of `gleb.statusline.lsp_progress` SHALL run only while a task is active and SHALL be stopped on `VimLeavePre`.

#### Scenario: detached client tasks are removed
- **WHEN** a `begin` fires for a client and then `LspDetach` fires for that client, and `progress()` is called after 500 ms
- **THEN** it returns `""`

#### Scenario: stale task is removed
- **WHEN** a `begin` fires and no further event arrives for that token for more than 60 s
- **THEN** `progress()` returns `""`

#### Scenario: refresh timer stops when idle
- **WHEN** `require("lualine").refresh` is replaced by a call counter, a `begin` is followed by an `end` for the same token, and 300 ms pass
- **THEN** the counter no longer increases

#### Scenario: refresh timer stops on exit
- **WHEN** `require("lualine").refresh` is replaced by a call counter, a `begin` fires without an `end`, and `VimLeavePre` is triggered
- **THEN** the counter no longer increases
