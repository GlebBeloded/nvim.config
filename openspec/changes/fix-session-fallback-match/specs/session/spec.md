## MODIFIED Requirements

### Requirement: Session resolution
The config SHALL resolve which saved session to load with `key.resolve(name, saved)`: return `name` if it is in `saved`; otherwise return the first entry of `saved` of the form `<zellij session>-<pane id>-<cwd slug>`, where `<cwd slug>` is the whole current cwd slug, `<pane id>` is digits and `<zellij session>` contains no `%`; otherwise return `nil`.

#### Scenario: resolve prefers the exact pane key
- **WHEN** `key.resolve("blossom-5-<cwd slug>", { "blossom-9-<cwd slug>", "blossom-5-<cwd slug>" })` is called
- **THEN** it returns `"blossom-5-<cwd slug>"`

#### Scenario: resolve falls back to any session for this cwd
- **WHEN** `key.resolve("blossom-5-<cwd slug>", { "blossom-9-<cwd slug>" })` is called
- **THEN** it returns `"blossom-9-<cwd slug>"`

#### Scenario: resolve returns nil when no session matches the cwd
- **WHEN** `key.resolve("blossom-5-<cwd slug>", { "blossom-5-%some%other%dir" })` is called
- **THEN** it returns `nil`

#### Scenario: resolve ignores a session for a deeper path with the same tail
- **WHEN** `key.resolve("blossom-5-<cwd slug>", { "blossom-9-%baz<cwd slug>", "x-9-%baz-1-<cwd slug>" })` is called (sessions for the deeper paths `/baz<cwd>` and `/baz-1-<cwd>`)
- **THEN** it returns `nil`

### Requirement: Restore on bare startup
The config SHALL, on `VimEnter`, load the session returned by `key.resolve(key.session_name(), <saved sessions>)` only when Neovim was started with no file arguments (`argc(-1) == 0`), with nested autocmds enabled so `FileType` fires for restored buffers, and errors silenced. The saved sessions SHALL be listed newest first by modification time, so the cwd fallback picks the most recently saved session for the cwd.

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
