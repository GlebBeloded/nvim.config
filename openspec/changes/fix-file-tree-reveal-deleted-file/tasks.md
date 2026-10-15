## 1. Guard filesystem toggle against a deleted current file
Scenarios: `file-tree: Toggle tolerates a deleted current file`
- [x] 1.1 Write the test `file-tree: Toggle tolerates a deleted current file` in tests/integration/file-tree/test_tree.lua; open a real file, delete it from disk, press the configured normal-mode `<A-e>` mapping, and see it fail
- [x] 1.2 Make `smart_toggle` reveal only an existing current buffer path and otherwise focus the filesystem tree without reveal
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_tree.lua CASE="Toggle tolerates a deleted current file"` and see it pass

## Agent decisions
- Use the proposal's no-reveal option for missing paths because it is the smallest safe fallback and preserves reveal behavior for existing files.
