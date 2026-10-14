# session Specification

## Purpose
Zellij-aware session recovery: every Neovim pane saves its window/buffer layout under a key derived from the zellij session, pane id and cwd, and a bare `nvim` restores it. Modified file buffers are auto-written so a restored session never misses edits.

## Requirements

### Requirement: Session key
The config SHALL name a session `<zellij session>-<pane id>-<cwd slug>` via `require("gleb.session.key").session_name()`, where the zellij session is `$ZELLIJ_SESSION_NAME` (default `no-zellij`), the pane id is `$ZELLIJ_PANE_ID` (default `0`), and the cwd slug is `getcwd()` with every `/`, `\` and `:` replaced by `%` (`key.slugify`).

#### Scenario: slugify replaces path separators
- **WHEN** `require("gleb.session.key").slugify("/Users/me/.config/nvim")` is called
- **THEN** it returns `"%Users%me%.config%nvim"`

#### Scenario: session_name combines zellij session, pane and cwd
- **WHEN** `$ZELLIJ_SESSION_NAME` is `blossom`, `$ZELLIJ_PANE_ID` is `5`, and `key.session_name()` is called
- **THEN** it returns `"blossom-5-" .. key.slugify(vim.fn.getcwd())`

#### Scenario: session_name degrades gracefully outside zellij
- **WHEN** `$ZELLIJ_SESSION_NAME` and `$ZELLIJ_PANE_ID` are unset and `key.session_name()` is called
- **THEN** it returns `"no-zellij-0-" .. key.slugify(vim.fn.getcwd())`

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
The config SHALL capture `key.session_name()` once at module load. On `VimEnter`, it SHALL load the resolved session only after a no-argument start, restore that session's cwd and buffers, fire nested buffer events, and silence load errors. Sessions SHALL be listed newest first so cwd fallback selects the most recently saved session.

#### Scenario: bare nvim restores the pane session
- **WHEN** a session named `key.session_name()` containing file `a.txt` exists and Neovim is started with no file arguments in the same cwd and zellij env
- **THEN** after `VimEnter` the current buffer is `a.txt` and its `filetype` option is set

#### Scenario: bare nvim restores a cwd session after pane id change
- **WHEN** only a session for another pane id with the same cwd exists (e.g. `$ZELLIJ_PANE_ID` changed from `9` to `5`) and Neovim is started with no file arguments
- **THEN** after `VimEnter` that session's cwd and buffers are restored

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
