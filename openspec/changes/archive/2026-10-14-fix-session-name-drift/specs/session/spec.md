## MODIFIED Requirements

### Requirement: Restore on bare startup
The config SHALL capture `key.session_name()` once at module load, before later cwd changes. On `VimEnter`, it SHALL load `key.resolve(<captured session name>, <saved sessions>)` only when started with no file arguments (`argc(-1) == 0`), with nested autocmds so `FileType` fires for restored buffers and with errors silenced. Saved sessions SHALL be listed newest first by modification time, so cwd fallback picks the most recently saved session for the cwd.

#### Scenario: bare nvim restores the pane session
- **WHEN** a session named `key.session_name()` containing file `a.txt` exists and Neovim is started with no file arguments in the same cwd and zellij env
- **THEN** after `VimEnter` the current buffer is `a.txt` and its `filetype` option is set

#### Scenario: bare nvim restores a cwd session after pane id change
- **WHEN** only a session for another pane id with the same cwd exists (e.g. `$ZELLIJ_PANE_ID` changed from `9` to `5`) and Neovim is started with no file arguments
- **THEN** after `VimEnter` that session's buffers are loaded

#### Scenario: bare nvim restores the newest cwd session
- **WHEN** sessions for pane ids `7` (containing `new.txt`) and `8` (containing `old.txt`) with the same cwd exist, pane `7`'s session file has the later modification time, and Neovim is started with no file arguments and `$ZELLIJ_PANE_ID` `9`
- **THEN** after `VimEnter` the current buffer is `new.txt`

#### Scenario: nvim with a file argument does not restore
- **WHEN** a matching session exists and Neovim is started as `nvim b.txt`
- **THEN** after `VimEnter` the only listed buffer is `b.txt`

#### Scenario: no matching session leaves startup untouched
- **WHEN** no saved session matches the cwd (see Session resolution) and Neovim is started with no file arguments
- **THEN** after `VimEnter` the current buffer is the empty startup buffer (or the dashboard)

### Requirement: Save on write and exit
The config SHALL save the current layout as the session name captured once during module load (without notification) on every `BufWritePost` and on `VimLeavePre`, but only when Neovim was started with no file arguments (`argc(-1) == 0`) and at least one listed buffer has a non-empty name and an empty `buftype`; otherwise it SHALL NOT save and an existing session with that name stays unchanged. The session plugin's own periodic autosave is disabled.

#### Scenario: writing a buffer saves the session
- **WHEN** `:write` is executed on a file buffer
- **THEN** `require("resession").list()` contains `key.session_name()`

#### Scenario: quitting saves the session
- **WHEN** `:qall` is executed
- **THEN** a session named `key.session_name()` exists on disk and lists the buffers that were open

#### Scenario: nvim with a file argument does not save the session
- **WHEN** a session named `key.session_name()` listing `a.txt` exists, Neovim is started as `nvim b.txt`, `:write` is executed and then `:qall`
- **THEN** the session file named `key.session_name()` is unchanged and still lists `a.txt`

#### Scenario: quitting without file buffers keeps the previous session
- **WHEN** a session named `key.session_name()` listing `a.txt` exists, Neovim is started with no file arguments, `:%bwipeout` leaves only an unnamed buffer, and `:qall` is executed
- **THEN** the session file named `key.session_name()` is unchanged and still lists `a.txt`

#### Scenario: project cwd change preserves the startup session name
- **WHEN** Neovim starts with no file arguments in a project subdirectory, project.nvim changes the cwd to the project root after a file buffer opens, and that buffer is written
- **THEN** the saved session name is derived from the startup subdirectory rather than the project root
