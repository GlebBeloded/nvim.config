## 1. Escape shell-command paths and stop after a failed directory change
Scenarios: `run: Run executes cargo run when Cargo.lock is readable`
- [x] 1.1 Add or tighten the assertion in `tests/unit/run/test_run.lua`; with a temporary fault (the current one-argument `shellescape(root)` and `;` separator) run `make test FILE=tests/unit/run/test_run.lua CASE="Run executes cargo run when Cargo.lock is readable"`, see it fail and record the failure, then remove the fault
- [x] 1.2 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run executes cargo run when Cargo.lock is readable"` and see it pass
