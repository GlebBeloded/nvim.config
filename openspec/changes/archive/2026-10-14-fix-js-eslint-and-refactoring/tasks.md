## 1. Enable the configured JavaScript language servers
Scenarios: `lsp: JavaScript config enables vtsls and eslint`
- [x] 1.1 Write the test `lsp: JavaScript config enables vtsls and eslint` in tests/integration/lsp/test_config.lua and see it fail
- [x] 1.2 Expose both `vtsls` and `eslint` from the JavaScript LSP config so the shared loader enables them
- [x] 1.3 Run `make test FILE=tests/integration/lsp/test_config.lua CASE="JavaScript config enables vtsls and eslint"` and see it pass

## 2. Remove the unavailable refactoring source
Scenarios: `lsp: Ranged Lua code action does not log generator failure`
- [x] 2.1 Write the test `lsp: Ranged Lua code action does not log generator failure` in tests/integration/lsp/test_config.lua and see it fail
- [x] 2.2 Remove the none-ls refactoring source whose runtime dependency is not installed
- [x] 2.3 Run `make test FILE=tests/integration/lsp/test_config.lua CASE="Ranged Lua code action does not log generator failure"` and see it pass
