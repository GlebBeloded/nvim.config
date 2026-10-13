## MODIFIED Requirements

### Requirement: Save on write and exit
The config SHALL save the current layout as session `key.session_name()` (without notification) on every `BufWritePost` and on `VimLeavePre`, but only when Neovim was started with no file arguments (`argc(-1) == 0`) and at least one listed buffer has a non-empty name and an empty `buftype`; otherwise it SHALL NOT save and an existing session with that name stays unchanged. The session plugin's own periodic autosave is disabled.

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

### Requirement: Auto-save modified buffers
The config SHALL automatically write modified buffers after a 1000 ms debounce, but only for buffers with a non-empty name and an empty `buftype` whose `filetype` is not `gitcommit` or `gitrebase`.

#### Scenario: modified file buffer is auto-written
- **WHEN** a normal file buffer is changed (e.g. `ihello<Esc>` in Normal mode) and more than 1000 ms pass
- **THEN** the file on disk contains `hello` and `modified` is false

#### Scenario: gitcommit buffer is not auto-written
- **WHEN** a buffer with `filetype=gitcommit` is changed and more than 1000 ms pass
- **THEN** `modified` is still true and the file on disk is unchanged

#### Scenario: special buffer is not auto-written
- **WHEN** a buffer with non-empty `buftype` (e.g. `nofile`) is changed and more than 1000 ms pass
- **THEN** no write occurs and `modified` remains as set

#### Scenario: unnamed buffer is not auto-written
- **WHEN** `:enew` is executed, `ihello<Esc>` is typed in Normal mode and more than 1000 ms pass
- **THEN** `modified` is still true and `v:errmsg` does not contain `E32`
