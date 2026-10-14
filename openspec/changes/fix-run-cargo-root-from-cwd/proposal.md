## Why
After fix-run-cargo-root (add1af6), `lua/gleb/run/init.lua` checks `Cargo.lock` in the cwd but finds the crate root with `vim.fs.root(0, "Cargo.toml")`, which searches from the current buffer's path. With the cwd in a crate and the current buffer outside any Cargo project (e.g. `~/.zshrc`), the root is nil and `vim.fn.shellescape(nil)` raises (review note, run 7012c9fd).

Kind: bug

## Evidence
- Review note in run 7012c9fd escalation.md; `rg -n 'vim.fs.root' lua/gleb/run/init.lua`.

## What Changes
- Search the Cargo root from the cwd (`vim.fs.root(vim.fn.getcwd(), "Cargo.toml")`), falling back to the cwd itself, so the marker check and the run directory agree.
- Test: cwd in a crate, current buffer a file outside it → `:Run` runs `cargo run` from the crate root with no error. Task 1.1 shows it erroring on the current code.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `lua/gleb/run/init.lua`, `tests/unit/run/test_run.lua`.
- Plugins: none.
- `run: Run ignores a directory without a supported project marker` still holds because the fix only changes Cargo root discovery after a readable `Cargo.lock` has selected the Cargo runner.
- `run: Run executes cargo run when Cargo.lock is readable` still holds because the fix makes Cargo root discovery follow the cwd where the readable marker was found, independently of the current buffer.
- `run: Run opens the browser when index.html is readable` still holds because HTML dispatch occurs before Cargo root discovery and is unchanged.
