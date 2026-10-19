## 1. Allow rustaceanvim v9
Scenarios: `references: Rust usages in production and test code`
- [x] 1.1 Run `make test FILE=tests/integration/references/test_languages.lua CASE="Rust usages in production and test code"` and see it pass, change rustaceanvim's constraint in `lua/gleb/plugins/plugins.lua` from `version = "^6"` to `version = "^9"`, then run it again and see it pass
