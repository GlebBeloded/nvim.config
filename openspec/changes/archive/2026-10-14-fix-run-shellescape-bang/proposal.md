## Why
`:Run` (`lua/gleb/run/init.lua`, `rg -n shellescape lua/gleb/run`) builds `vim.cmd("!cd " .. vim.fn.shellescape(root) .. ";cargo run")`. For a `:!` command Vim still expands `%`, `#` and `!` inside the single quotes, so it needs `shellescape(p, 1)`: verified headless with a crate at `sp/a%b c`, the `cd` went to `afoo.txtb c` (the buffer name replaced `%`), failed, and cargo would have run in the old cwd. Also `;` runs `cargo run` even when `cd` fails.

Kind: bug

## Evidence
- Review of run 7012c9fd (headless probe with path `sp/a%b c`).

## What Changes
- Use `vim.fn.shellescape(root, 1)` for every path in a `:!` command in `run/init.lua` (also the browser branch if it builds one) and join with `&&` so a failed `cd` stops.
- Test: a crate path containing `%` and `#` yields a command that cds into the exact directory (assert the command string escapes them as `\%`/`\#`), and the command uses `&&`. Task 1.1 shows it failing on the current code.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `lua/gleb/run/init.lua`, `tests/unit/run/test_run.lua`.
- Plugins: none.
