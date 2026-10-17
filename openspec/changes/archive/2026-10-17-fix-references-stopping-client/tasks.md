## 1. Complete references when one client refuses its request
Scenarios: `references: gr continues when one client refuses the request`
- [x] 1.1 Write the integration test `references: gr continues when one client refuses the request` in `tests/integration/references/test_open.lua`; drive the real normal-mode `gr` mapping on the populated `gomod` fixture with gopls returning its usages and a second attached references-capable client's `request` returning false, then see it fail because the Find Usages view does not open
- [x] 1.2 Count a false `client:request` return as a completed empty result in `lua/gleb/references/request.lua`
- [x] 1.3 Run `make test FILE=tests/integration/references/test_open.lua CASE="gr continues when one client refuses the request"` and see it pass
