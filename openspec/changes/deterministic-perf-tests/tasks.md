## 1. Scale shared child waits
Scenarios: `shortcuts: The load factor is 1 on an idle host`, `shortcuts: The load factor is the load per CPU on a busy host`, `shortcuts: Child wait default stretches with host load`
- [x] 1.1 Write the test `shortcuts: Child wait default stretches with host load` in `tests/unit/shortcuts/test_stack_cli.lua`, run `make test FILE=tests/unit/shortcuts/test_stack_cli.lua CASE="Child wait default stretches with host load"`, and see it fail while retaining the existing idle and busy load-factor cases
- [x] 1.2 Make `child.wait` apply `H.load_factor()` to its 2000 ms default, without scaling an explicit timeout twice
- [x] 1.3 Run `make test FILE=tests/unit/shortcuts/test_stack_cli.lua CASE="load factor"` and `make test FILE=tests/unit/shortcuts/test_stack_cli.lua CASE="Child wait default stretches with host load"` and see them pass

## 2. Scale the Python type-check wait
Scenarios: `lsp: Type-check toggle reattaches every Python buffer without reloading`
- [x] 2.1 Tighten `tests/integration/lsp/test_typecheck.lua` so the real `:PyTypeCheckOn` case records its load-scaled attachment deadline; temporarily restore the unscaled deadline, run `make test FILE=tests/integration/lsp/test_typecheck.lua CASE="Type-check toggle reattaches every Python buffer without reloading"`, see the cited loaded-gate timeout fail and record it, then remove the temporary fault
- [x] 2.2 Apply the shared load factor to the test's asynchronous wait budget without changing its attachment or unsaved-buffer assertions
- [x] 2.3 Run `make test FILE=tests/integration/lsp/test_typecheck.lua CASE="Type-check toggle reattaches every Python buffer without reloading"` and see it pass

## 3. Make bounded redraw measurements deterministic
Scenarios: `file-tree: Project tree redraw meets the large-tree bound`, `file-tree: Project tree expansion meets the large-tree bound`
- [x] 3.1 Replace elapsed-only assertions in `tests/integration/file-tree/test_performance.lua` with child-side process-CPU assertions while preserving the elapsed assertions behind perf mode; temporarily add one extra buffer replacement, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="large-tree bound"`, see it fail and record the failure, then remove the fault
- [x] 3.2 Add reusable child-side CPU measurement and keep the 100 ms bounds, row state, selection and one-replacement assertions unchanged
- [x] 3.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="large-tree bound"` and see it pass

## 4. Control save-burst debounce deterministically
Scenarios: `file-tree: Project tree coalesces a save burst`, `file-tree: Project tree save leaves the main path promptly`
- [x] 4.1 Update the real-write cases in `tests/integration/file-tree/test_performance.lua` to advance an injected debounce scheduler and assert child-side CPU time; with the scheduler held before its 50 ms deadline, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree coalesces a save burst"`, see it fail and record the failure, then remove the fault
- [x] 4.2 Add a resettable scheduler hook to `lua/gleb/util/debounce.lua`, use it through the real file-tree watcher/write path, and preserve the 50 ms debounce, one replacement, one git command, 100 ms CPU/wall bounds and 1000 ms final-state deadline
- [x] 4.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree coalesces a save burst"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree save leaves the main path promptly"` and see them pass

## 5. Measure listed-row following inside the child
Scenarios: `file-tree: Project tree follows an already listed row promptly`
- [x] 5.1 Change `tests/integration/file-tree/test_performance.lua` to assert process CPU and operation counts for the real `:edit`; temporarily force one tree-buffer replacement, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree follows an already listed row promptly"`, see it fail and record the failure, then remove the fault
- [x] 5.2 Keep the 50 ms CPU/wall bounds and the existing focus, selection and zero-replacement assertions
- [x] 5.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree follows an already listed row promptly"` and see it pass

## 6. Prove maintenance work is deferred
Scenarios: `file-tree: Project tree re-roots without waiting for repository discovery`, `file-tree: Project tree persists folds off the action path`
- [x] 6.1 Update `tests/integration/file-tree/test_performance.lua` to hold real repository discovery across `:cd` and to measure child-side CPU for real `:cd` and `za`; temporarily complete discovery synchronously, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="re-roots without waiting for repository discovery"`, see it fail and record the failure, then remove the fault
- [x] 6.2 Assert discovery is pending when `DirChanged` returns, retain the 100 ms CPU/wall bounds, and load-scale both existing 1000 ms settle waits
- [x] 6.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="re-roots without waiting for repository discovery"` and `make test FILE=tests/integration/file-tree/test_performance.lua CASE="persists folds off the action path"` and see them pass

## 7. Measure unfold work without scheduler noise
Scenarios: `file-tree: Project tree unfold all meets the large-tree bound`
- [x] 7.1 Replace the cross-RPC elapsed assertion in `tests/integration/file-tree/test_performance.lua` with process CPU measured around the real `zR`; temporarily reduce the allowed row count below the generated result, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"`, see it fail and record the failure, then remove the fault
- [x] 7.2 Preserve the 500 ms CPU/wall bounds, 5001-row ceiling and exact WARN notification, and load-scale the setup waits
- [x] 7.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"` and see it pass

## 8. Run wall-clock performance checks serially
Scenarios: `file-tree: Project tree redraw meets the large-tree bound`, `file-tree: Project tree expansion meets the large-tree bound`, `file-tree: Project tree save leaves the main path promptly`, `file-tree: Project tree follows an already listed row promptly`, `file-tree: Project tree re-roots without waiting for repository discovery`
- [x] 8.1 Add a `make perf` selection for the real populated-tree cases in `tests/integration/file-tree/test_performance.lua`; temporarily set one elapsed bound to zero, run `make perf`, see it fail and record the failure, then remove the fault
- [x] 8.2 Wire `perf` as a serial `tests/check.sh` target after parallel tests, while normal integration runs retain correctness and process-CPU assertions
- [x] 8.3 Run `make perf` and see it pass

## 9. Cover the remaining serial wall-clock bounds
Scenarios: `file-tree: Project tree persists folds off the action path`, `file-tree: Project tree unfold all meets the large-tree bound`
- [x] 9.1 Add both real-key cases to the `make perf` selection; temporarily set one elapsed bound to zero, run `make perf`, see it fail and record the failure, then remove the fault
- [x] 9.2 Keep the original 100 ms and 500 ms load-scaled wall bounds and avoid duplicating either scenario in another test file
- [x] 9.3 Run `make perf` and see it pass

## 10. Observe the real type-check attachment deadline
Scenarios: `lsp: Type-check toggle reattaches every Python buffer without reloading`
- [x] 10.1 Tighten `tests/integration/lsp/test_typecheck.lua` to record the timeout received by the real `child.wait`; temporarily pass the unscaled timeout from `basedpyright_mode`, run `make test FILE=tests/integration/lsp/test_typecheck.lua CASE="Type-check toggle reattaches every Python buffer without reloading"`, see the deadline assertion fail and record it, then remove the fault
- [x] 10.2 Replace the self-recorded deadline with an observation of the actual attachment wait while retaining the real `:PyTypeCheckOn`, both loaded buffers and the unsaved-buffer assertion
- [x] 10.3 Run `make test FILE=tests/integration/lsp/test_typecheck.lua CASE="Type-check toggle reattaches every Python buffer without reloading"` and see it pass

## 11. Specify and trace both save debounce stages
Scenarios: `file-tree: Project tree save burst observes both debounce deadlines`
- [x] 11.1 Write the test `file-tree: Project tree save burst observes both debounce deadlines` in `tests/integration/file-tree/test_performance.lua` through the real write, watcher, git refresh and draw path; temporarily advance only 149 ms of the watcher deadline, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree save burst observes both debounce deadlines"`, see it fail and record the failure, then remove the fault
- [x] 11.2 Reuse the manual scheduler to prove the 149+1 ms watcher deadline and the following 49+1 ms draw deadline independently, with no early git request or replacement
- [x] 11.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree save burst observes both debounce deadlines"` and see it pass

## 12. Restore repository-discovery instrumentation on every path
Scenarios: `file-tree: Project tree re-roots without waiting for repository discovery`
- [x] 12.1 Tighten `tests/integration/file-tree/test_performance.lua` to assert that the real `vim.system` is restored after the re-root case; temporarily suppress the matching discovery call, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree re-roots without waiting for repository discovery"`, see the restoration assertion fail and record it, then remove the fault
- [x] 12.2 Return and register an unconditional cleanup from the discovery hold helper before driving real `:cd`, while preserving the pending-discovery assertion and existing 100 ms and 1000 ms bounds
- [x] 12.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree re-roots without waiting for repository discovery"` and see it pass

## 13. End unfold timing at child-side completion
Scenarios: `file-tree: Project tree unfold all meets the large-tree bound`
- [x] 13.1 Tighten `tests/integration/file-tree/test_performance.lua` to assert that the sample is captured when the real WARN notification is emitted; temporarily capture it only after the host poll, run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"`, see it fail and record the failure, then remove the fault
- [x] 13.2 Finish the process-CPU and elapsed sample at the child-side completion boundary so the serial 500 ms wall sample excludes host polling, while retaining the real `zR`, 5001-row ceiling and exact warning
- [x] 13.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree unfold all meets the large-tree bound"` and see it pass

## 14. Drive unchanged-status refresh without a real timer
Scenarios: `file-tree: Unchanged git status does not redraw the project tree`
- [ ] 14.1 Use the recorded gate failure `FAIL in tests/integration/file-tree/test_performance.lua | file-tree: Unchanged git status does not redraw the project tree: tests/integration/file-tree/test_performance.lua:431: unchanged git status did not finish` as the failing evidence
- [ ] 14.2 In `tests/integration/file-tree/test_performance.lua`, run the real `require("gleb.file_tree.git").refresh(root)` with the manual debounce scheduler, advance its deadline explicitly, restore the scheduler, and retain the zero-replacement assertion for equal status and ignored maps
- [ ] 14.3 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Unchanged git status does not redraw the project tree"` and see it pass

## Agent decisions

- Round a scaled default deadline up to the next millisecond so host-load scaling never shortens the intended wait.
- Use `PERF=1` to enable retained wall-clock assertions because the later serial target can pass it directly to the existing test process.
- Expose `use_test_scheduler`, `advance` and `reset` on the debounce utility so tests control its clock without adding user configuration.
- Hold the real repository-discovery process result at its callback boundary so the re-root test observes pending state without replacing Git discovery.
- Let the shared CPU measurement installer target either child so the unfold fixture uses the same instrumentation as the populated-tree cases.
- Before a save-burst write, wait for the edit's follow draw, watch reconciliation and a sentinel event on a later watch, because libuv drops events while it rebuilds its single macOS FSEvents stream.
- Wrap `child.wait` only around the type-check mode poll and restore it immediately so the test observes the real timeout without recording unrelated waits.
- Capture unfold timing in a wrapper for the exact row-limit WARN so unrelated notifications cannot end the sample.
