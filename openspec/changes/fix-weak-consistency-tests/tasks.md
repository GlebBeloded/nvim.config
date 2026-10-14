## 1. Strengthen literal quick-route coverage
Scenarios: `loop: Literal quick routes exist`
- [x] 1.1 Run `make test FILE=tests/unit/loop/test_quick.lua CASE="Literal quick routes exist"` and see it pass, change the test to collect every literal `lua/...` and `init.lua` route from `tests/quick.sh` and assert that each path exists under the repository root without matching exact script stdout, then run it again and see it pass

## 2. Cover Cargo project dispatch
Scenarios: `run: Run ignores a directory without a supported project marker`
- [x] 2.1 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run ignores a directory without a supported project marker"` and see it pass, extend the test with a temporary directory containing `Cargo.lock` and assert that `:Run` executes `cargo run`, then run it again and see it pass
