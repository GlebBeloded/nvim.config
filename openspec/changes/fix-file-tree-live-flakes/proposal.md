## Why

Kind: bug

Two file-tree cases fail in every full `make check` on auto since file-tree-ignored shipped (2 of 2 runs,
2026-10-18, load average 22–31), and pass alone:

```
FAIL in tests/integration/file-tree/test_ignored.lua | file-tree: First paint waits for ignored status | omits ignored entries from the first frame:
  Left:  true
  Right: false
    tests/integration/file-tree/test_ignored.lua:334
FAIL in tests/integration/file-tree/test_project_live.lua | file-tree: A compact chain splits when a folder gains an entry:
  Left:  false
  Right: true
    tests/integration/file-tree/test_project_live.lua:344
```

## What Changes

- For each case, log with a headless probe under parallel load (`make test CAPS=file-tree`) what the case observes
  at the failing line and when the tree's async work (git ignored status, the filesystem watch, the redraw) lands.
- Fix the cause: the code paints before the ignored status is known, or misses the watch event; or the test reads
  before an event it can await (a real redraw or status signal, never a sleep). The assertions stay as they are.

## Impact

- lua/gleb/file_tree/ (view, watch or git status) or the two test files' waits.
- `file-tree: First paint waits for ignored status` and `file-tree: A compact chain splits when a folder gains an entry`
  still hold, now under a full parallel run.
