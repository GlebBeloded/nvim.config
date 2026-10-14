## 1. Prove Cargo runs from the git root
Scenarios: `run: Run executes cargo run when Cargo.lock is readable`
- [x] 1.1 Update the existing test in `tests/unit/run/test_run.lua` to initialize a git root, enter a child directory containing `Cargo.lock`, temporarily expect that child directory in the command, and see the assertion fail because Run selects the git root
- [x] 1.2 Change the assertion to expect `!cd <git root>;cargo run`
- [x] 1.3 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run executes cargo run when Cargo.lock is readable"` and see it pass
