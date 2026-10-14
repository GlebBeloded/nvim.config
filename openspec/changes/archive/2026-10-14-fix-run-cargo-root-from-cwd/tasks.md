## 1. Resolve the Cargo root from the cwd
Scenarios: `run: Run executes cargo run when Cargo.lock is readable`
- [x] 1.1 Add or tighten the assertion in `tests/unit/run/test_run.lua`; with a temporary fault (resolve the Cargo root from buffer `0` while that buffer is outside the Cargo project) run `make test FILE=tests/unit/run/test_run.lua CASE="Run executes cargo run when Cargo.lock is readable"`, see it fail and record the failure, then remove the fault by resolving from the cwd with a cwd fallback
  - Red: emitted `!cd 'v:null' && cargo run` instead of the crate path.
- [x] 1.2 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run executes cargo run when Cargo.lock is readable"` and see it pass
