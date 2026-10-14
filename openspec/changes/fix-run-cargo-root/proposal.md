## Why
`:Run` (`lua/gleb/run/init.lua`) checks `Cargo.lock` in the cwd but runs `cargo run` from the git root without escaping, so in a monorepo crate it runs in the wrong dir, and a path with spaces breaks.
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Run from the nearest `Cargo.toml` root (`vim.fs.root(0, "Cargo.toml")`), shell-escaped; update the `run` scenarios' wording only if they pin 'git root' (MODIFIED delta) and the existing test; add a path-with-spaces case.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- `run`: a scenario for the fixed behaviour (add one if none covers it).

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
