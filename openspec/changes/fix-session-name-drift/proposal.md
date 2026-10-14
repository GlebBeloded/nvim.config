## Why
`lua/gleb/session/init.lua` (~40, 48) recomputes the session name from the cwd at every save, but project.nvim (`manual_mode=false`) changes the cwd to the project root, so a bare `nvim` started in `repo/sub` saves under `…%repo` and the next bare `nvim` in `repo/sub` restores nothing (confirmed with `:cd repo/sub` + opening `repo/sub/f.txt`).
Found by the second audit of auto (2026-10-14).

Kind: bug
Adopt: loop/fix-session-name-drift

## Evidence
- Confirmed in a headless full-config child by the audit; locate code with `rg -n` (line numbers may drift).

## What Changes
- Record the session name once at startup (before any chdir, e.g. at module load or VimEnter) and use it for both restore and save.
- `session` scenario: starting in a subdirectory and letting project.nvim change the cwd saves under the start directory's name; test RED first.

## Capabilities
### Modified Capabilities
- `session`: scenarios for the fixed behaviour.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded. Core keymaps: unchanged.

## Rejected run
Run on `loop/fix-session-name-drift` was rejected by the judge:
- fix loop exhausted (3 attempts) with gates still red: spec,review_skipped

## Unblocked
The previous run's code and tests were green (all check layers ok); only the trial archive failed: `spec/session requirements[2]: Requirement text is very long (>500 characters)`. Shorten that requirement's text in the change's session delta (move examples and edge cases into scenarios, keep the meaning), run `python3 .archon/scripts/spec_trial.py fix-session-name-drift` until it exits 0, and keep the code and tests as adopted.
