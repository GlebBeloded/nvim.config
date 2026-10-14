## 1. Fix Telescope prompt navigation
Scenarios: `telescope: Telescope prompt maps move selection`
- [x] 1.1 Write the test `telescope: Telescope prompt maps move selection` in tests/unit/telescope/test_mappings.lua and see it fail
- [x] 1.2 Correct the malformed `<C-j>` key in the Telescope insert-mode mappings
- [x] 1.3 Run `make test FILE=tests/unit/telescope/test_mappings.lua CASE="Telescope prompt maps move selection"` and see it pass

## 2. Fix Run project detection
Scenarios: `run: Run ignores a directory without a supported project marker`
- [x] 2.1 Write the test `run: Run ignores a directory without a supported project marker` in tests/unit/run/test_run.lua and see it fail
- [x] 2.2 Require `filereadable("Cargo.lock")` to equal `1` before executing Cargo
- [x] 2.3 Run `make test FILE=tests/unit/run/test_run.lua CASE="Run ignores a directory without a supported project marker"` and see it pass

## 3. Fix code-action menu mappings
Scenarios: `select: Code action menu receives picker mappings`
- [x] 3.1 Write the test `select: Code action menu receives picker mappings` in tests/unit/select/test_code_action.lua and see it fail
- [x] 3.2 Pass the picker's `default_keymap()` result to the menu
- [x] 3.3 Run `make test FILE=tests/unit/select/test_code_action.lua CASE="Code action menu receives picker mappings"` and see it pass

## 4. Remove the stale quick route
Scenarios: `loop: Literal quick routes exist`
- [x] 4.1 Write the test `loop: Literal quick routes exist` in tests/unit/loop/test_quick.lua and see it fail
- [x] 4.2 Remove the `lua/gleb/lualine.lua` route from tests/quick.sh
- [x] 4.3 Run `make test FILE=tests/unit/loop/test_quick.lua CASE="Literal quick routes exist"` and see it pass
