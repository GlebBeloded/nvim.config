## Why
The make loop targets (`make fix`, `feature`, `queue`, `update`) end with `$(CLEANUP)` (`archon isolation cleanup --merged`, `Makefile:129`). Archon judges "merged" against the self-remote ref `local/auto` and does not fetch it; ship merges into the local branch `auto` only, and the last `git fetch local` ran in `loop-setup` before the run. So the run that just shipped looks unmerged, and its worktree under `~/.archon/workspaces/GlebBeloded/nvim.config/worktrees/` and its `loop/*` branch are never removed (root cause: `artifacts/runs/aed94ce7-4856-4ac7-8090-62bcd5a0f044/root-cause.md`).

Kind: bug

## What Changes
- `CLEANUP` in `Makefile` refreshes `local/auto` (`git fetch -q local`) before it runs `archon isolation cleanup --merged`, so all four loop targets reclaim the run they shipped.
- New capability `loop` with the scenario that pins this; the test drives the real `Makefile` with a stub `ARCHON` in a throwaway repo.

## Capabilities
### New Capabilities
- `loop`: the local AI loop's make targets (`docs/workflow.md`): what they do around an Archon workflow run.

### Modified Capabilities
None

## Impact
- Code: `Makefile` (`CLEANUP`); new test `tests/unit/loop/`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: changing Archon itself (a fetch inside `isolation cleanup --merged` would be an upstream fix); `ship.py` and the workflows; cleaning worktrees of runs that did not ship (unmerged branches stay, as today); runs whose cleanup Archon skips for other reasons (live run, uncommitted changes).
