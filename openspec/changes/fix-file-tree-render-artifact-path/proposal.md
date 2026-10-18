## Why

Kind: bug

`file-tree: Project tree render text matches the ANSI artifact` reads its approved render from
`openspec/changes/file-tree-view/renders/f1_proposed.ansi`. Shipping archived the change, the file moved to
`openspec/changes/archive/2026-10-18-file-tree-view/renders/`, and the test now fails on auto with E484, so every
gate in the loop is red on it.

## Evidence

- tests/screen/file-tree/test_project_tree.lua:140 joins `openspec/changes/file-tree-view/renders/f1_proposed.ansi`
- `make test FILE=tests/screen/file-tree/test_project_tree.lua` on auto: `Vim:E484: Can't open file
  .../openspec/changes/file-tree-view/renders/f1_proposed.ansi`

## What Changes

- The approved render moves into the test tree (e.g. `tests/screen/file-tree/f1_proposed.ansi`, byte-identical),
  and the test reads it from there, so archiving a change never breaks a test. The assertion is unchanged.

## Impact

- tests/screen/file-tree/test_project_tree.lua, tests/screen/file-tree/f1_proposed.ansi
