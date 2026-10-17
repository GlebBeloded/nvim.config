## 1. Wait for references classification before asserting the empty tree
Scenarios: `references: Tests filter can leave the tree empty`
- [x] 1.1 Use `FAIL in tests/integration/references/test_keys.lua | references: Tests filter can leave the tree empty:` as the pre-change failing evidence; run `make test FILE=tests/integration/references/test_keys.lua CASE="references: Tests filter can leave the tree empty"` and see it pass, update the real `t` key case to wait for `not view.state.classifying`, then run it again and see it pass
