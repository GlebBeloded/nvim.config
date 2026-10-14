## 1. Accept omitted selection options
Scenarios: `select: Selection accepts omitted options`
- [x] 1.1 Write the test `select: Selection accepts omitted options` in `tests/unit/select/test_init.lua` and see it fail
- [x] 1.2 Normalize omitted options before routing the selection
- [x] 1.3 Run `make test FILE=tests/unit/select/test_init.lua CASE="Selection accepts omitted options"` and see it pass

## 2. Complete cancelled code-action selections
Scenarios: `select: Cancelling a code action completes selection`
- [x] 2.1 Write the test `select: Cancelling a code action completes selection` in `tests/unit/select/test_code_action.lua` and see it fail
- [x] 2.2 Add the menu close callback that completes the selection once with `(nil, nil)`
- [x] 2.3 Run `make test FILE=tests/unit/select/test_code_action.lua CASE="Cancelling a code action completes selection"` and see it pass
