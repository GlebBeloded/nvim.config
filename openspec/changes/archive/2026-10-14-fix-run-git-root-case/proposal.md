## Why
The `run` scenario "Run executes cargo run when Cargo.lock is readable" says `cargo run` runs from the git root, but its case in `tests/unit/run/test_run.lua` (find with `rg -n 'cargo run' tests/unit/run`) uses a temp dir without `.git`, so `git_root()` falls back to `.` and the expectation `!cd .;cargo run` does not prove the git-root part.

Kind: bug

## What Changes
- In that case, `git init` the temp dir, `:cd` into a subdirectory holding (or under) the `Cargo.lock` setup the scenario needs, and assert `!cd <root>;cargo run`. Task 1.1 shows the new assertion failing once (e.g. temporarily expect the subdirectory), then fixes the expectation.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/unit/run/test_run.lua`.
- Plugins: none. Core keymaps: unchanged.
- `run: Run ignores a directory without a supported project marker` still holds because this change only strengthens the Cargo test fixture.
- `run: Run executes cargo run when Cargo.lock is readable` still holds because the expected behavior is unchanged; the test will now prove that execution starts at the git root.
- `run: Run opens the browser when index.html is readable` still holds because browser dispatch and its test fixture are unchanged.
