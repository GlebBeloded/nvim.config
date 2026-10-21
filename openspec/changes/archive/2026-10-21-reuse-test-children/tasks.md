## 1. Add the reusable child lifecycle
Scenarios: `loop: Reusable child resets case state`, `loop: Fresh child remains the default`
- [x] 1.1 Write the tests `loop: Reusable child resets case state` and `loop: Fresh child remains the default` in `tests/unit/loop/test_harness.lua`, driving `H.child_set` with real child processes, and see them fail
- [x] 1.2 Extend `tests/helpers.lua` with an explicit one-child-per-file mode that starts in `pre_once`, resets buffers, tabs, cwd and test globals before later cases, and leaves fresh-per-case behavior as the default
- [x] 1.3 Run `make test FILE=tests/unit/loop/test_harness.lua CASE="Reusable child resets case state|Fresh child remains the default"` and see it pass

## Agent decisions

- Opt in with `H.child_set(child, start, { reuse = true })` so existing callers retain fresh children without changes.
- Reuse children in ownership; keep assign, hidden, apply, plugin-ownership, open, adapters, context, and run fresh because the isolation trials exposed mutable fixture globals, stale picker callbacks, one-shot events, terminated children, retained invocation history, a deleted startup fixture, and stale MiniPick buffers respectively.
- Reuse children in paste, dashboard, and PR statusline; keep input, core keymaps, and the main statusline fresh because input retains mutable globals and an active blank-query picker, child restarts remove the installed reset, and a later statusline case requires the startup dashboard.
- Measure the gate-shaped integration layer with `JOBS=12`: base `d60a6e5f` ran 767 cases in 247.09 s with 759 full-config starts; after the safe opt-ins `31e8c375` ran 768 cases in 252.30 s with 757 starts.

## 2. Enable cached Lua loading before configuration imports
Scenarios: `loop: Cached loader precedes configuration modules`
- [x] 2.1 Write the test `loop: Cached loader precedes configuration modules` in `tests/integration/loop/test_startup.lua`, starting the real config with a startup hook that records loader activation and the first configuration require, and see it fail
- [x] 2.2 Move `vim.loader.enable()` in `init.lua` ahead of the first configuration `require`
- [x] 2.3 Run `make test FILE=tests/integration/loop/test_startup.lua CASE="Cached loader precedes configuration modules"` and see it pass

## 3. Reuse children in actions and find-action suites
Scenarios: `actions: Invocation captures editor state`, `actions: Global bindings exist after VeryLazy`, `find-action: Find Action opens from its shortcut`, `find-action: Catalog rows use standalone Title Case labels`, `find-action: Assign float captures a free shortcut`
- [x] 3.1 Run the named cases through their real mappings and pickers; temporarily disable the reusable lifecycle's case reset, opt the candidate files into reuse, run `make test FILE=tests/integration/actions` and `make test FILE=tests/integration/find-action`, see state-leak failures, record them, then restore the reset
- [x] 3.2 Opt safe files in `tests/integration/actions/` and `tests/integration/find-action/` into the reusable lifecycle, leaving any file that touches non-resettable state on fresh children
- [x] 3.3 Run `make test FILE=tests/integration/actions` and `make test FILE=tests/integration/find-action` and see them pass

## 4. Reuse children in keymaps, picker and statusline suites
Scenarios: `keymaps: Core mappings resolve through actions`, `keymaps: Terminal paste edits a normal buffer`, `picker: Dashboard opens shared list pickers`, `picker: Input prompt submits its query`, `statusline: statusline is global`
- [x] 4.1 Run the named cases through their real mappings, populated pickers and statusline; temporarily disable the reusable lifecycle's case reset, opt the candidate files into reuse, run `make test FILE=tests/integration/keymaps`, `make test FILE=tests/integration/picker` and `make test FILE=tests/integration/statusline`, see state-leak failures, record them, then restore the reset
- [x] 4.2 Opt safe files in `tests/integration/keymaps/`, `tests/integration/picker/` and `tests/integration/statusline/` into the reusable lifecycle, leaving any file that touches non-resettable state on fresh children
- [x] 4.3 Run `make test FILE=tests/integration/keymaps`, `make test FILE=tests/integration/picker` and `make test FILE=tests/integration/statusline` and see them pass

## 5. Measure the integration layer
Scenarios: `loop: Reusable child resets case state`
- [x] 5.1 Record the integration layer's elapsed time and full-config child-start count on the base revision, run the same measurement after the safe opt-ins, and include both results in the implementation handoff
