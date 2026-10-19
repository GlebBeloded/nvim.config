# Tasks

## 1. Preserve plugin-update test dependencies

Scenarios: `loop: Plugin update data includes Mason tools`, `references: Rust usages in production and test code`

- [ ] 1.1 Write the failing test `loop: Plugin update data includes Mason tools` in `tests/unit/loop/test_plugin_update.lua` and retain the recorded failing evidence for `references: Rust usages in production and test code`: `rust-analyzer is not executable`
- [ ] 1.2 Update the plugin-update isolation to make installed Mason packages available beside its private plugin and parser copies, without mutating the live installation
- [ ] 1.3 Run `make test FILE=tests/unit/loop/test_plugin_update.lua CASE="Plugin update data includes Mason tools"` and `make test FILE=tests/integration/references/test_languages.lua CASE="Rust usages in production and test code"` and see both pass against rustaceanvim `9cb125d`
