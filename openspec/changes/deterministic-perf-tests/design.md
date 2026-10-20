# Design

## Context

See `proposal.md` for the gate failures. The current tests mix child RPC, scheduler delay and the operation under test in one elapsed-time sample. Save coalescing also races real timers, while timeout scaling is applied inconsistently.

## Goals / Non-Goals

**Goals:** Keep the existing bounds meaningful under parallel gate load and retain an isolated wall-clock regression check.

**Non-Goals:** Change project-tree, LSP or UI behavior; change numeric performance bounds; expose test controls as user configuration.

## Decisions

1. Measure process CPU around one child-side operation with `vim.uv.getrusage`, and keep operation counts such as buffer replacements and synchronous process waits as primary assertions. This excludes RPC and descheduling noise while still detecting extra work. Elapsed time alone was rejected because it reproduces the current flake.
2. Add a resettable test scheduler to the shared debounce utility and advance it explicitly in coalescing tests. Sleeping longer was rejected because late filesystem events can still cross the timer boundary.
3. Keep correctness and CPU assertions in the normal integration run. A `make perf` target reruns only wall-clock cases after parallel targets, with existing bounds and host-load scaling. Dropping wall-clock coverage was rejected because CPU time does not detect blocking waits.
4. Scale `child.wait`'s default and the cited explicit async waits through the existing load-factor policy. Performance bounds are not enlarged; scaling applies only where the existing contract already calls for it.
5. Prove re-root deferral structurally by holding repository discovery and observing that `DirChanged` returns before discovery completes. Timing alone was rejected because it cannot distinguish deferral from a fast synchronous discovery.
6. Keep test instrumentation observable and bounded: intercept the actual wait argument, restore temporary process overrides unconditionally, record unfold timing at the child-side notification boundary, and advance the unchanged-status debounce clock manually.

## Risks / Trade-offs

- [Process CPU includes unrelated child work] → measure immediately around one operation after settling the fixture.
- [A test scheduler could leak between cases] → expose an explicit reset and restore the real scheduler during teardown.
- [A temporary wait or process override could make its own assertion tautological or leak] → observe the real call and register restoration before driving the operation.
- [Serial wall-clock checks lengthen the gate] → select only cases with wall-time contracts and run the layer once after parallel work.
