## 1. Build the action catalog
Scenarios: `actions: Valid actions are available by id`, `actions: Invalid action ids are rejected`, `actions: Duplicate action ids are rejected`, `actions: Scoped actions are filtered by context`
- [x] 1.1 Write the tests for these scenarios in `tests/unit/actions/test_registry.lua` and run each with `make test FILE=tests/unit/actions/test_registry.lua CASE="<scenario title>"` to see it fail
- [x] 1.2 Add the typed action model and pure catalog under `lua/gleb/actions/`, and update the `docs/architecture.md` module map and convention. Concrete feature-owned `actions.lua` lists and their collection are owned by `keymaps-migration`.
- [x] 1.3 Run each scenario with `make test FILE=tests/unit/actions/test_registry.lua CASE="<scenario title>"` and see it pass

## 2. Persist shortcuts deterministically
Scenarios: `actions: Shortcut file round-trips deterministically`, `actions: Invalid shortcut JSON preserves bindings`, `actions: Unknown action ids are skipped once`, `actions: Hidden actions cannot receive shortcuts`
- [x] 2.1 Write the tests for these scenarios in `tests/unit/actions/test_store.lua` and run each with `make test FILE=tests/unit/actions/test_store.lua CASE="<scenario title>"` to see it fail
- [x] 2.2 Add the JSON shortcut store and repository `settings/keymap.json`, including stable encoding, validation, warnings, and last-good-state handling; encode an empty shortcut map as a JSON object with `vim.empty_dict()`
- [x] 2.3 Run each scenario with `make test FILE=tests/unit/actions/test_store.lua CASE="<scenario title>"` and see it pass

## 3. Apply global and filetype shortcuts
Scenarios: `actions: Global bindings exist after VeryLazy`, `actions: Filetype bindings are buffer-local`, `actions: Reapplying removes stale bindings`, `actions: Failed reload keeps applied bindings`
- [x] 3.1 Write the tests for these scenarios in `tests/integration/actions/test_apply.lua` and run each with `make test FILE=tests/integration/actions/test_apply.lua CASE="<scenario title>"` to see it fail
- [x] 3.2 Add re-entrant global and filetype binding application and wire `init.lua` to apply it after `VeryLazy`
- [x] 3.3 Run each scenario with `make test FILE=tests/integration/actions/test_apply.lua CASE="<scenario title>"` and see it pass

## 4. Adapt plugin-window mappings
Scenarios: `actions: Adapter output follows current shortcuts`, `actions: Adapter reassignment applies on reopen`
- [x] 4.1 Write the tests for these scenarios in `tests/integration/actions/test_adapters.lua` and run each with `make test FILE=tests/integration/actions/test_adapters.lua CASE="<scenario title>"` to see it fail
- [x] 4.2 Add adapters under `lua/gleb/actions/adapters/` for differ, codediff, dap-ui, neotest, mason, lazy, blink, copilot, and neo-tree; keep diffview on filetype-scoped actions
- [x] 4.3 Run each scenario with `make test FILE=tests/integration/actions/test_adapters.lua CASE="<scenario title>"` and see it pass

## 5. Preserve action invocation context
Scenarios: `actions: Invocation captures editor state`, `actions: Actions run in the invocation window`, `actions: Visual actions restore the selection`, `actions: Availability and toggles share the context`
- [x] 5.1 Write the tests for these scenarios in `tests/integration/actions/test_context.lua` and run each with `make test FILE=tests/integration/actions/test_context.lua CASE="<scenario title>"` to see it fail
- [x] 5.2 Add context capture and guarded restoration for action availability, toggles, and execution
- [x] 5.3 Run each scenario with `make test FILE=tests/integration/actions/test_context.lua CASE="<scenario title>"` and see it pass

## 6. Capture shortcuts and detect conflicts
Scenarios: `actions: Enter finishes a normalized key sequence`, `actions: Esc cancels capture`, `actions: Backspace removes the last captured key`, `actions: Exact and prefix overlaps conflict in one scope`, `actions: Separate scopes do not conflict`
- [x] 6.1 Write the tests for these scenarios in `tests/unit/actions/test_capture.lua` and run each with `make test FILE=tests/unit/actions/test_capture.lua CASE="<scenario title>"` to see it fail
- [x] 6.2 Add key capture normalization, editing controls, cancellation, and scope-aware exact and prefix conflict detection
- [x] 6.3 Run each scenario with `make test FILE=tests/unit/actions/test_capture.lua CASE="<scenario title>"` and see it pass

## 7. Discover hidden Ex-command actions
Scenarios: `actions: Ex commands become humanized hidden actions`, `actions: Registered commands are not duplicated`, `actions: Hidden command discovery is cached`
- [x] 7.1 Write the tests for these scenarios in `tests/unit/actions/test_commands.lua` and run each with `make test FILE=tests/unit/actions/test_commands.lua CASE="<scenario title>"` to see it fail
- [x] 7.2 Add lazy, session-cached Ex-command discovery, title humanization, registered-command deduplication, and hidden-action enforcement
- [x] 7.3 Run each scenario with `make test FILE=tests/unit/actions/test_commands.lua CASE="<scenario title>"` and see it pass
