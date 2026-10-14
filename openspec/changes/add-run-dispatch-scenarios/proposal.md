## Why
The `run` capability's requirement "Run dispatches by readable project marker" has only the "no marker" scenario. `tests/unit/run/test_run.lua` now also checks that a readable `Cargo.lock` runs `cargo run`, but inside the no-marker case, so that behaviour has no scenario of its own; the `index.html` branch has neither scenario nor test.

Kind: bug

## What Changes
- `run` spec delta: add scenarios "Run executes cargo run when Cargo.lock is readable" and "Run opens the browser when index.html is readable" (and that index.html wins when both exist), without changing the requirement text.
- Split the positive Cargo case out of the no-marker test into its own case named after its scenario; add the index.html cases. Stub the commands; never open a browser on the host.

## Capabilities
### Modified Capabilities
- `run`: two or three added scenarios.

## Impact
- Code: `tests/unit/run/test_run.lua`, `run` spec delta.
- Plugins: none. Core keymaps: unchanged.
