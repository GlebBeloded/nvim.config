## Why

Kind: bug

`references: Terraform usage types match the approved render` fails under load: the screenshot is taken before the
`type = string` line settles, so the `type` cell's highlight differs (`attr` 3 vs 4 at line 3, column 8). It passes
alone (3 of 3) and failed twice during full checks while a drain ran.

## Evidence

- `FAIL in tests/screen/references/test_view.lua | references: Terraform usage types match the approved render:`
  `different attr cell at line 3 column 8, reference = "3", observed = "4"` (make check, 2026-10-17, twice)
- The case screenshots once the view opens, with no wait for terraformls semantic tokens / treesitter highlight of
  the background buffer to settle, unlike the TS/Python/Rust cases that wait for references readiness.

## What Changes

- The case waits until the background buffer's highlights are stable (terraformls semantic tokens applied, or two
  identical consecutive screenshots of the background rows) before comparing; no sleeps, no change to the reference.

## Impact

- tests/screen/references/test_view.lua
