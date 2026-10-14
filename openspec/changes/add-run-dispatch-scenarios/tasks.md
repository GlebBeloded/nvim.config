## 1. Give Cargo dispatch its own scenario test
Scenarios: `run: Run executes cargo run when Cargo.lock is readable`
- [x] 1.1 Write the test `run: Run executes cargo run when Cargo.lock is readable` in tests/unit/run/test_run.lua and see it fail
- [x] 1.2 Split the existing positive Cargo setup and assertion out of the no-marker case into the new scenario-named case
- [x] 1.3 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run executes cargo run when Cargo.lock is readable"` and see it pass

## 2. Cover browser dispatch and marker precedence
Scenarios: `run: Run opens the browser when index.html is readable`
- [x] 2.1 Write the test `run: Run opens the browser when index.html is readable` in tests/unit/run/test_run.lua and see it fail
- [x] 2.2 Stub command execution and cover both index-only and both-marker directories, asserting the browser command runs and `cargo run` does not
- [x] 2.3 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run opens the browser when index.html is readable"` and see it pass
