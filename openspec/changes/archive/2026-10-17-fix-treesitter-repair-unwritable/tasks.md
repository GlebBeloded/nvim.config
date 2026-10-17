## 1. Keep query-link repair failures non-fatal
Scenarios: `languages: An unwritable query link does not break startup`
- [x] 1.1 Write the test `languages: An unwritable query link does not break startup` in tests/unit/languages/test_site_repair.lua, driving `require("gleb.treesitter.repair").repair(...)` with one read-only invalid link and another repairable invalid link, and see it fail
- [x] 1.2 Replace the asserting filesystem operations in lua/gleb/treesitter/repair.lua with a small named repair helper that warns once with the failed path and filesystem error, then continues scanning later links
- [x] 1.3 Run `make test FILE=tests/unit/languages/test_site_repair.lua CASE="An unwritable query link does not break startup"` and see it pass

## Agent decisions

- Report repair failures as `Treesitter query link repair failed for <path>: <error>` so the warning is concise while naming both required details.
