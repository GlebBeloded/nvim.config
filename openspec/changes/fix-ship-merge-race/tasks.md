# Tasks

## 1. Lock and clean abort in ship.py

Scenarios: "loop: Concurrent ships merge one at a time", "loop: Stale ship lock is taken over", "loop: Failed merge leaves auto clean"

- [x] 1.1 Add the failing unit tests "loop: Concurrent ships merge one at a time", "loop: Stale ship lock is taken over" and "loop: Failed merge leaves auto clean" in a new `tests/unit/loop/test_ship.lua`.
  - Setup: bare child, `H.new_child()` + `child.start_bare`. Reuse the `system`/`tempdir`/`GIT_ENV` pattern of `test_cleanup.lua`; move the shared helpers into `tests/helpers.lua` only if both files need them. All helpers are small, named and LuaCATS-typed.
  - `make_repo()`: `git init -b auto`, one commit.
  - `add_run(repo, name, file, line)`: `git worktree add -b loop/<name>` plus one commit.
  - `ship(worktree, env)`: `vim.system({ "python3", <H.root>/.archon/scripts/ship.py }, { cwd = worktree, env = GIT_ENV + BASE_BRANCH=auto, INPUTS_CHANGE="" })`.
  - `expect_auto_clean(repo)`: no `.git/MERGE_HEAD`, empty `git status --porcelain --untracked-files=no`, no `.git/nvim-ship.lock`.
  - Concurrent: start four `vim.system` ships without waiting, then `:wait()` on all of them. Give each branch enough files (about 200) that merges overlap, as in the reproduction.
  - Stale lock: write the pid of a finished `vim.system({ "true" })` into `.git/nvim-ship.lock` first.
  - Failed merge: write an executable `.git/hooks/pre-merge-commit` that exits 1, and record `git rev-parse auto` before the ship. Use mini.test `parametrize` over `{ abort = "works" }` and `{ abort = "fails" }`. For `"fails"`, put a `git` shim first on `PATH` that exits 1 for `merge --abort` and otherwise `exec`s the real git (resolve its path with `vim.fn.exepath("git")` in the parent before writing the shim). That runs the `git reset --merge` fallback. A plain hook failure is already cleaned up by today's `git merge --abort`.

  Verify: `make test FILE=tests/unit/loop/test_ship.lua` fails on the current `ship.py`:
  - concurrent: lost merges or a `MERGE_HEAD`;
  - stale lock: the lock file is still there, because ship ignores it;
  - failed merge: `abort = "fails"` leaves a `MERGE_HEAD` (`abort = "works"` already passes and stays as a regression guard).

  Run the concurrent case a few times to confirm it fails reliably; if it does not, raise the per-branch workload.
- [x] 1.2 In `.archon/scripts/ship.py`, add the lock: small typed functions `acquire_lock(path, timeout)` and `release_lock(path)`, with the pid file in `git rev-parse --git-common-dir`, stale-pid takeover and `SHIP_LOCK_TIMEOUT`. Hold the lock around the clean-tree check, the merge and the abort, releasing it in a `finally`. Verify: the concurrent and stale-lock tests pass.
- [x] 1.3 In `ship.py`, replace the unchecked `git merge --abort` with an `abort_merge(target, before)` that aborts, verifies there is no `MERGE_HEAD` and the tracked tree is clean, and otherwise runs `git reset --merge <before>`. Verify: both parameter sets of "loop: Failed merge leaves auto clean" pass.

## 2. Report conflicts and reconcile in the workflow

Scenarios: "loop: Conflicting ship is reported for reconcile"

- [ ] 2.1 Add the failing test "loop: Conflicting ship is reported for reconcile" to `tests/unit/loop/test_ship.lua`. The setup commits a change to line 1 of `f.txt` on `auto` after cutting a `loop/*` worktree that changes the same line, then runs ship with `INPUTS_ON_CONFLICT=report`. Decode stdout with `vim.json.decode` and assert `merged == false`, `conflict == true`, `files` containing `f.txt`, `auto` unchanged, and `expect_auto_clean`. Verify: it fails on the current `ship.py` (exit 1, no JSON).
- [ ] 2.2 In `ship.py`, after a failed merge and the abort, detect conflicts with `git merge-tree --write-tree --name-only`. When `on_conflict` is `report`, print `{"merged": false, "conflict": true, "branch", "commit": "", "files": [...]}` and exit 0; otherwise fail as before. Add `"conflict": false` to the success output. Update the module docstring. Verify: 2.1 passes and all of `tests/unit/loop/` is green.
- [ ] 2.3 Wire the reconcile loop in `.archon/workflows/nvim-deliver.yaml`:
  - Pass `on_conflict: report` to `ship`, and add `conflict: { type: boolean }` to its `output_format` (also in `plugin-update.yaml`'s ship, which is not required there).
  - Add the `reconcile` `loop_group` (`resolve` → `regate` → `reship`, `max_iterations: 2`), run when `$ship.output.conflict == true`.
  - Make the workflow's result the merged ship. Use a `shipped` script node if `returns` cannot pick between `ship` and `reship`.
  - Add `.archon/commands/resolve-conflict.md`: merge `auto` into the run branch in the worktree, resolve the conflicts keeping both changes' intent and every test and scenario, run `make quick`, commit, and never touch the `auto` checkout.

  Verify: `make loop-validate` passes.
- [ ] 2.4 Add one line to `docs/workflow.md` on the ship lock (`.git/nvim-ship.lock`, delete it only if its pid is not running) and the reconcile loop. Verify: `make check` is green, and `openspec validate fix-ship-merge-race --strict` passes.

## Workflow follow-up

- Manual acceptance: start two `make queue CHANGE=…` runs whose changes touch the same line. One ships directly; the other goes through `reconcile` and ships. `~/.config/nvim` stays clean throughout.
