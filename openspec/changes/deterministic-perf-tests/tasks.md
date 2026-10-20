## 1. Scale shared child waits
Scenarios: `shortcuts: The load factor is 1 on an idle host`, `shortcuts: The load factor is the load per CPU on a busy host`, `shortcuts: Child wait default stretches with host load`
- [x] 1.1 Write the test `shortcuts: Child wait default stretches with host load` in `tests/unit/shortcuts/test_stack_cli.lua`, run `make test FILE=tests/unit/shortcuts/test_stack_cli.lua CASE="Child wait default stretches with host load"`, and see it fail while retaining the existing idle and busy load-factor cases
- [x] 1.2 Make `child.wait` apply `H.load_factor()` to its 2000 ms default, without scaling an explicit timeout twice
- [x] 1.3 Run `make test FILE=tests/unit/shortcuts/test_stack_cli.lua CASE="load factor"` and `make test FILE=tests/unit/shortcuts/test_stack_cli.lua CASE="Child wait default stretches with host load"` and see them pass

## 2. Scale the Python type-check wait
Scenarios: `lsp: Type-check toggle reattaches every Python buffer without reloading`
- [ ] 2.1 Tighten `tests/integration/lsp/test_typecheck.lua` so the real `:PyTypeCheckOn` case records its load-scaled attachment deadline; temporarily restore the unscaled deadline, run `make test FILE=tests/integration/lsp/test_typecheck.lua CASE="Type-check toggle reattaches every Python buffer without reloading"`, see the cited loaded-gate timeout fail and record it, then remove the temporary fault
- [ ] 2.2 Apply the shared load factor to the test's asynchronous wait budget without changing its attachment or unsaved-buffer assertions
- [ ] 2.3 Run `make test FILE=tests/integration/lsp/test_typecheck.lua CASE="Type-check toggle reattaches every Python buffer without reloading"` and see it pass

## 3. Make bounded redraw measurements deterministic
Scenarios: `file-tree: Project tree redraw meets the large-tree bound`, `file-tree: Project tree expansion meets the large-tree bound`
- [ ] 3.1 Replace elapsed-only assertions in `tests/integration/file-tree/test_performance.lua` with child-side process-CPU assertions while preserving the elapsed assertions behind perf mode; temporarily add one extra buffer replacement, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="large-tree bound"`, see it fail and record the failure, then remove the fault
- [ ] 3.2 Add reusable child-side CPU measurement and keep the 100 ms bounds, row state, selection and one-replacement assertions unchanged
- [ ] 3.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="large-tree bound"` and see it pass

## 4. Control save-burst debounce deterministically
Scenarios: `file-tree: Project tree coalesces a save burst`, `file-tree: Project tree save leaves the main path promptly`
- [ ] 4.1 Update the real-write cases in `tests/integration/file-tree/test_performance.lua` to advance an injected debounce scheduler and assert child-side CPU time; with the scheduler held before its 50 ms deadline, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree coalesces a save burst"`, see it fail and record the failure, then remove the fault
- [ ] 4.2 Add a resettable scheduler hook to `lua/gleb/util/debounce.lua`, use it through the real file-tree watcher/write path, and preserve the 50 ms debounce, one replacement, one git command, 100 ms CPU/wall bounds and 1000 ms final-state deadline
- [ ] 4.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree coalesces a save burst"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree save leaves the main path promptly"` and see them pass

## 5. Measure listed-row following inside the child
Scenarios: `file-tree: Project tree follows an already listed row promptly`
- [ ] 5.1 Change `tests/integration/file-tree/test_performance.lua` to assert process CPU and operation counts for the real `:edit`; temporarily force one tree-buffer replacement, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree follows an already listed row promptly"`, see it fail and record the failure, then remove the fault
- [ ] 5.2 Keep the 50 ms CPU/wall bounds and the existing focus, selection and zero-replacement assertions
- [ ] 5.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree follows an already listed row promptly"` and see it pass

## 6. Prove maintenance work is deferred
Scenarios: `file-tree: Project tree re-roots without waiting for repository discovery`, `file-tree: Project tree persists folds off the action path`
- [ ] 6.1 Update `tests/integration/file-tree/test_performance.lua` to hold real repository discovery across `:cd` and to measure child-side CPU for real `:cd` and `za`; temporarily complete discovery synchronously, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="re-roots without waiting for repository discovery"`, see it fail and record the failure, then remove the fault
- [ ] 6.2 Assert discovery is pending when `DirChanged` returns, retain the 100 ms CPU/wall bounds, and load-scale both existing 1000 ms settle waits
- [ ] 6.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="re-roots without waiting for repository discovery"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="persists folds off the action path"` and see them pass

## 7. Measure unfold work without scheduler noise
Scenarios: `file-tree: Project tree unfold all meets the large-tree bound`
- [ ] 7.1 Replace the cross-RPC elapsed assertion in `tests/integration/file-tree/test_performance.lua` with process CPU measured around the real `zR`; temporarily reduce the allowed row count below the generated result, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"`, see it fail and record the failure, then remove the fault
- [ ] 7.2 Preserve the 500 ms CPU/wall bounds, 5001-row ceiling and exact WARN notification, and load-scale the setup waits
- [ ] 7.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"` and see it pass

## 8. Run wall-clock performance checks serially
Scenarios: `file-tree: Project tree redraw meets the large-tree bound`, `file-tree: Project tree expansion meets the large-tree bound`, `file-tree: Project tree save leaves the main path promptly`, `file-tree: Project tree follows an already listed row promptly`, `file-tree: Project tree re-roots without waiting for repository discovery`
- [ ] 8.1 Add a `make perf` selection for the real populated-tree cases in `tests/integration/file-tree/test_performance.lua`; temporarily set one elapsed bound to zero, run `make perf`, see it fail and record the failure, then remove the fault
- [ ] 8.2 Wire `perf` as a serial `tests/check.sh` target after parallel tests, while normal integration runs retain correctness and process-CPU assertions
- [ ] 8.3 Run `make perf` and see it pass

## 9. Cover the remaining serial wall-clock bounds
Scenarios: `file-tree: Project tree persists folds off the action path`, `file-tree: Project tree unfold all meets the large-tree bound`
- [ ] 9.1 Add both real-key cases to the `make perf` selection; temporarily set one elapsed bound to zero, run `make perf`, see it fail and record the failure, then remove the fault
- [ ] 9.2 Keep the original 100 ms and 500 ms load-scaled wall bounds and avoid duplicating either scenario in another test file
- [ ] 9.3 Run `make perf` and see it pass

## Agent decisions

- Round a scaled default deadline up to the next millisecond so host-load scaling never shortens the intended wait.
