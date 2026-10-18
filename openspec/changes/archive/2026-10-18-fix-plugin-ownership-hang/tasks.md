## 1. Make plugin-surface ownership checks non-blocking
Scenarios: `actions: Plugin-window mappings are action-owned`
- [x] 1.1 Run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="Plugin-window mappings are action-owned"` and see it pass, probe each plugin surface individually with `make probe`, schedule surface opening so the parent can enforce the existing wait timeout, report the surface name plus child mode and messages on timeout, make any blocking surface open offline, then run the test again and see it pass
