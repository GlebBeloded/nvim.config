## 1. Run Cargo from the nearest crate root safely
Scenarios: `run: Run executes cargo run when Cargo.lock is readable`
- [x] 1.1 Update `tests/unit/run/test_run.lua` for `run: Run executes cargo run when Cargo.lock is readable` to create a nested Cargo project beneath a different git root in a path containing spaces, assert that the command uses the shell-escaped nearest `Cargo.toml` root, and see it fail
- [x] 1.2 Replace git-root resolution in `lua/gleb/run/init.lua` with a small named Cargo-root helper using the nearest `Cargo.toml`, and shell-escape that root when constructing the command
- [x] 1.3 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run executes cargo run when Cargo.lock is readable"` and see it pass
