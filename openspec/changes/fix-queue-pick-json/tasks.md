Layer: unit (docs/testing.md step 1), in `tests/unit/loop/test_cleanup.lua`, reusing its `make_repo`, `write_stub`, `system`, `GIT_ENV` and `run_target` helpers. Design skipped: no visible UI, no structural change.

## 1. Queue picker prints one JSON document

Scenarios: "loop: Queue skips a taken change".

- [x] 1.1 Make the stubs configurable without changing what the existing case sees: `OPENSPEC_STUB` echoes `$OPENSPEC_LIST` when set (default stays `{"changes":[{"name":"t-change"}]}`); `ARCHON_STUB` appends its `workflow run` arguments to `$ARCHON_RUNS` when set (not to `LOOP_LOG`, whose first two lines the existing case compares). Extract the bin/env setup of `run_target` into a typed `stub_env(extra?)` helper so the new case can run `queue_pick.py` directly with the same PATH; `run_target` takes an optional `env` merged on top and returns the runs log in a new `runs` field of `test.LoopRun`. Run `make test FILE=tests/unit/loop/test_cleanup.lua`; the existing case still passes
- [ ] 1.2 Failing test: add the case "loop: Queue skips a taken change". In a `make_repo()` repo, write `openspec/changes/t-change/.openspec.yaml` (`created: 2026-01-01`) and `openspec/changes/t-next/.openspec.yaml` (`created: 2026-01-02`), commit them, run `git branch loop/t-change`, then `run_target(repo, { "queue" }, { OPENSPEC_LIST = <both changes> })`. Expect exit 0, `Working on t-next` in the output, no `JSONDecodeError`, and a runs line containing `--branch loop/t-next`. Then run `python3 .archon/scripts/queue_pick.py` in the repo with `stub_env` and assert `vim.json.decode(stdout).change == "t-next"`. Keep these steps in small named, typed helpers (e.g. `write_change`, `expect_picks`). Run the file: the new case fails (today make prints `JSONDecodeError`, says "Queue is empty" and exits 0, and the direct decode fails on the leading hash line); the existing case passes
- [ ] 1.3 In `.archon/scripts/queue_pick.py` `taken()`, pass `stdout=subprocess.DEVNULL` to `subprocess.run` so git's hash never reaches the script's stdout; keep the return-code check
- [ ] 1.4 Rerun the file; both cases pass

## 2. Verify

- [ ] 2.1 `make trace` lists "loop: Queue skips a taken change" as `tested`, no orphans
- [ ] 2.2 `make test CASE=loop` and `make check` are green
