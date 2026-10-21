## Why

Kind: bug
Priority: high

Loop audit (2026-10-21), under the robust-tests requirement (docs/testing.md, Robust tests: a test must help, not be a
source of problems). `tests/e2e/find-action/test_e2e.lua` ("Physical Find Action workflow persists an assignment")
compares the whole palette screen with a render hard-coded in `tests/e2e/find-action/screens.lua`: the listed action
rows and the total (`54/54`). Every change that adds or renames an action breaks it, though nothing the e2e layer tests
(real key events through Alacritty and zellij) changed: pr-thread-window's full gate was green except this case
(run ea3ef0c8, full-4.log), pr-comments-view hit it too, and the history shows repeated "refresh approved action
counts" commits (f4a51568, fba2631f). The e2e layer runs only in the full gate, so the change's fix passes see it late.

## What Changes

- The e2e case checks what the physical key path proves (the palette opens on the real chord, the query, the assign
  hint and the persisted assignment) with expected rows and totals derived from the live action registry in the child,
  not from a hard-coded list; the exact palette look stays covered by the screen layer (`tests/screen/find-action`).
- No assertion about the key path is weakened.

## Evidence

- `tests/e2e/find-action/test_e2e.lua:46-53` loads a named fixture and retries until the complete terminal dump equals
  that fixed string.
- `tests/e2e/find-action/screens.lua:75-106` embeds concrete action rows and the `53/53` and `7/53` totals, so a live
  catalog change fails the e2e workflow before any physical-key or persistence assertion changes.

## Impact

- `tests/e2e/find-action/test_e2e.lua`, `tests/e2e/find-action/screens.lua`.
- No plugin dependency is added, removed, or upgraded.
- Core keymaps do not change.
- Out of scope: changing the Find Action UI or its screen-layer reference screenshots.
