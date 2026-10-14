## 1. Stop plugin-spec writes from syncing dependencies
Scenarios: `plugins: Writing plugins.lua runs no Lazy command`
- [x] 1.1 Write the test `plugins: Writing plugins.lua runs no Lazy command` in tests/integration/plugins/test_autosync.lua and see it fail
- [x] 1.2 Remove the config-owned `plugins.lua` write autocmd and its callback
- [x] 1.3 Run `make test FILE=tests/integration/plugins/test_autosync.lua CASE="Writing plugins.lua runs no Lazy command"` and see it pass
