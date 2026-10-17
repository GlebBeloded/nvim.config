## Why

Kind: bug

`references: Tests filter can leave the tree empty` fails under load: it reads the tree title right after pressing
`t`, before classification finished, and sees `" Usages of OnlyInTests · 0 · classifying "`.

## Evidence

- `FAIL in tests/integration/references/test_keys.lua | references: Tests filter can leave the tree empty:`
  `Left: " Usages of OnlyInTests · 0 · classifying "  Right: " Usages of OnlyInTests · 0 "` (make check while two
  drains ran, 2026-10-17); 5 of 5 isolated runs pass.
- tests/integration/references/test_keys.lua:75-89 asserts the title with no wait for `view.state.classifying`
  to be false, unlike the other references cases that wait for it.

## What Changes

- The case waits for `not view.state.classifying` (the existing wait helper pattern) before reading the title; no
  sleeps, the assertion unchanged.

## Impact

- tests/integration/references/test_keys.lua
