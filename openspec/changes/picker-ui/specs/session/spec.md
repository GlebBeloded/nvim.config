## MODIFIED Requirements

### Requirement: Save on write and exit
The config SHALL save the current layout under the session name captured once during module load, without notification, on `BufWritePost` and `VimLeavePre`, only when Neovim started with no file arguments and has a listed, named file buffer. Otherwise it SHALL NOT save, and an existing session with that name SHALL stay unchanged. The session plugin's periodic autosave SHALL be disabled.

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
- **WHEN** Neovim starts with no file arguments in a project subdirectory, its cwd changes to the project root after a file buffer opens, and that buffer is written
- **THEN** the saved session name is derived from the startup subdirectory rather than the project root
