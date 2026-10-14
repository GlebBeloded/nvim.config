## Why
Review of fix-consistency-bugs (847554c) found two weak tests:
- `tests/unit/loop/test_quick.lua` ("Literal quick routes exist") only checks that the removed `lualine.lua` route adds no statusline caps, with a hard-coded stdout; it does not prove the scenario's THEN that every literal route in `tests/quick.sh` names an existing file.
- `tests/unit/run/test_run.lua` covers only the case without `Cargo.lock`; nothing proves `Cargo.lock` present still runs `cargo run`.

Kind: bug

## What Changes
- `test_quick.lua`: collect every literal `lua/...` / `init.lua` route from `tests/quick.sh` and assert each exists under the repo root; drop the exact-stdout match.
- `test_run.lua`: add the positive case (a temp dir with `Cargo.lock` runs `cargo run`).
- Locate code with `rg -n`, not line numbers.

## Capabilities
### Modified Capabilities
None. `skip_specs: true` (both cases test existing scenarios).

## Impact
- Code: `tests/unit/loop/test_quick.lua`, `tests/unit/run/test_run.lua`.
- Plugins: none. Core keymaps: unchanged.
