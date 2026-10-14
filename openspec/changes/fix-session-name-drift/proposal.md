## Why
The session module recomputes its key from the current working directory at every save. Because project.nvim automatically changes that directory to the project root, a bare `nvim` started in `repo/sub` can save under `…%repo`; the next bare `nvim` in `repo/sub` then restores nothing.
Found by the second audit of auto (2026-10-14).

Kind: bug
Adopt: loop/fix-session-name-drift

## Evidence
- `lua/gleb/session/init.lua:40` and `lua/gleb/session/init.lua:48` call `key.session_name()` separately when saving and restoring.
- `lua/gleb/session/key.lua:19` derives each call from the live `vim.fn.getcwd()` value.
- `lua/gleb/project.lua:16` enables automatic project-directory changes, and installed project.nvim source at `~/.local/share/nvim/lazy/project.nvim/lua/project_nvim/project.lua:180` changes the global cwd.

## What Changes
- Record the session name once at startup (before any chdir, e.g. at module load or VimEnter) and use it for both restore and save.
- `session` scenario: starting in a subdirectory and letting project.nvim change the cwd saves under the start directory's name; test RED first.

## Capabilities
### Modified Capabilities
- `session`: scenarios for the fixed behaviour.

## Impact
- Code: `lua/gleb/session/init.lua`.
- Tests: `tests/integration/session/test_session.lua`.
- Plugins: none added or upgraded. Core keymaps: unchanged.
- Out of scope: changing project.nvim configuration, changing the session-key format, or migrating existing session files.

## Rejected run
Run on `loop/fix-session-name-drift` was rejected by the judge:
- fix loop exhausted (3 attempts) with gates still red: spec,review_skipped

## Unblocked
The previous run's code and tests were green (all check layers ok); only the trial archive failed: `spec/session requirements[2]: Requirement text is very long (>500 characters)`. Shorten that requirement's text in the change's session delta (move examples and edge cases into scenarios, keep the meaning), run `python3 .archon/scripts/spec_trial.py fix-session-name-drift` until it exits 0, and keep the code and tests as adopted.
