# Tasks

## 1. Fetch before cleanup

Scenarios: "loop: Cleanup sees the merge the run shipped"

- [x] 1.1 Add the failing unit test "loop: Cleanup sees the merge the run shipped" in `tests/unit/loop/test_cleanup.lua` (bare child, `H.new_child()` + `child.start_bare`). Small named helpers, LuaCATS-typed, run in the child via `child.lua`:
  - `make_repo()`: `git init` a temp dir, branch `auto`, one commit (set `GIT_AUTHOR_*`/`GIT_COMMITTER_*` in the env), no `local` remote. Symlink the checkout's `Makefile` into it as `Makefile`: `loop-setup` calls `$(MAKE) -s loop-register` without `-f`, so the sub-make must find it in the cwd. For `queue`, copy `.archon/scripts/queue_pick.py` into `.archon/scripts/` and put a stub `openspec` first on `PATH` that prints `{"changes":[{"name":"t-change"}]}`.
  - `write_stub(dir, log)`: executable `archon` shell stub. `workflow run …` reads the value after `--branch`, creates that branch with one commit and merges it into `auto` with `git merge --no-ff`; `isolation cleanup --merged` appends `git rev-parse local/auto auto` and `git branch --merged local/auto` to `log`; any other call (`doctor`) exits 0.
  - `run_target(repo, args)`: `vim.system({ "make", unpack(args) }, { cwd = repo, env = { HOME = <temp>, ARCHON = <stub>, PATH = <stub dir>:$PATH, … } }):wait(30000)`; a temp `HOME` keeps `loop-register` away from the real `~/.archon`.
  - For each of `fix BUG=x`, `feature IDEA=x`, `queue CHANGE=t-change`, `update PLUGIN=x` (fresh repo each): assert exit code 0, both logged revs equal, and the run's `loop/*` branch listed.

  Verify: `make test CASE="loop: Cleanup sees the merge the run shipped"` fails on the current `Makefile` (`local/auto` is the pre-run commit).
- [x] 1.2 Create `openspec/specs/loop/spec.md` from the delta (`# loop Specification`, its `## Purpose`, then `## Requirements` with the "Shipped run is cleaned up" requirement verbatim), so `make trace` links the new case instead of reporting an orphan. The archive's ADDED step is then a no-op ("Specs already in sync"), checked by the gate's trial archive.
- [x] 1.3 In `Makefile`, make `CLEANUP` run `git fetch -q local` before `$(ARCHON) isolation cleanup --merged`, still silent and never failing the target (e.g. `{ git fetch -q local; $(ARCHON) isolation cleanup --merged; } >/dev/null 2>&1 || true`); update the comment above it to say why it fetches. Verify: the 1.1 test passes, `make trace` lists the scenario as tested with no orphans, `make check` is green, `openspec validate fix-loop-cleanup-fetch --strict` passes.

## Workflow follow-up

- Manual acceptance: after the next shipped `make fix`, `git worktree list` and `git branch --list 'loop/*'` in `~/.config/nvim` no longer show that run.
