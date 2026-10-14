## Why
fix-session-name-drift captures the session name once at startup, but the pane-id-changed fallback in `lua/gleb/session/key.lua` (`rg -n getcwd lua/gleb/session/key.lua`) still builds its slug from the live `vim.fn.getcwd()`. project.nvim's VimEnter autocmd (registered before the session's) can cd to the git root before `restore()` runs, so the fallback can look up the wrong cwd's session (review of run 2b5060b7, by code reading).

Kind: bug
Adopt: loop/fix-session-fallback-cwd

## Evidence
- `lua/gleb/project.lua` VimEnter autocmd registration precedes `gleb.session`; `key.resolve` uses `getcwd()` for the fallback slug.

## What Changes
- Capture the startup cwd slug together with the name and pass it to `resolve`; never read the live cwd there.
- Test: start in `repo/sub` with a changed pane id and project.nvim cd'ing to `repo` before restore; the fallback restores `repo/sub`'s newest session. Task 1.1 shows it failing on the current code (use `make probe` to confirm the ordering first).

## Capabilities
### Modified Capabilities
None. `skip_specs: true` (unless a scenario must be added for the fallback path).

## Impact
- Code: `lua/gleb/session/init.lua`, `lua/gleb/session/key.lua`, session tests.
- Plugins: none.

## Rejected run
Run on `loop/fix-session-fallback-cwd` was rejected by the judge:
- fix loop exhausted (3 attempts) with gates still red: tests,review_skipped
- note: loop: e2e did not run because the sandbox image pull disk-space guard aborted with 60 GB free, below its required 25 GB post-unpack reserve.

## Unblocked
The previous run was rejected only for infrastructure: every e2e failure was the sandbox's image-pull guard after a transient `lume get` blip (fixed in round52), plus one lua_ls readiness sample at 2644 ms. Keep the adopted code and tests; they need no change for those findings.
