## 1. Remove the stale Copilot module cache reset
Scenarios: `actions: Plugin-window mappings are action-owned`
- [x] 1.1 Run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="Plugin-window mappings are action-owned"` and see it pass, remove the stale `package.loaded["gleb.copilot.setup"]` reset, run it again and see it pass
