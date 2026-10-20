## Why

Kind: feature
Adopt: loop/deterministic-perf-tests
Priority: high

Loop audit (2026-10-20): wall-clock bounds flake under the gate's load (load average 25–60 on 14 cores):
`tests/integration/file-tree/test_performance.lua` — "re-roots without waiting for repository discovery" (8 runs),
"coalesces a save burst" (5), "unfold all meets the large-tree bound", "save leaves the main path promptly" — plus
`lsp: Type-check toggle reattaches every Python buffer without reloading`. Independent review: the bounds span several
RPC round trips, `H.load_factor()` uses the lagging 1-minute load average, the coalesce case races a 150 ms git debounce
against late fs events, and several waits (`child.wait` 2000 ms default, `ASYNC_MS=3000`, re-root's 1000 ms settle)
are not load-scaled.

## What Changes

- Performance assertions measure what they mean without RPC noise: time inside one `child.lua` call, CPU time
  (`vim.uv.getrusage`) or operation counts (scans, `set_lines`, synchronous `vim.system():wait()` calls) as the main
  assertion; structural assertions where the intent is "does not wait" (re-root: discovery not complete right after `cd`).
- Debounce-coalescing cases use an injected/manual debounce clock instead of real timers.
- Pure wall-time bounds move to a serial `make perf` layer that `make check` runs alone; the parallel layer keeps the
  correctness assertions. `child.wait`'s default timeout and the unscaled waits scale with load.
- No bound is loosened without a load-scaled reason.

## Capabilities

- `file-tree`: make large-tree, coalescing and deferred-maintenance performance checks deterministic while preserving their bounds.
- `shortcuts`: extend the shared test-harness deadline policy to child-Neovim waits.

## Impact

- `tests/integration/file-tree/test_performance.lua`, `tests/helpers.lua`, `lua/gleb/util/debounce.lua` (a test hook),
  `Makefile`/`tests/check.sh` (the `perf` layer).
## Rejected run
Run on `loop/deterministic-perf-tests` was rejected by the judge:
- fix loop exhausted with gates still red: full
- last failures:
  full make check E2E=1 is red:
  full log: /Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/42ab1c75-f5be-4a6e-86b1-961252fefa5d/full-6.log
  check: waiting for the check lock held by pid 87298 (/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/worktrees/loop/reuse-test-children-20261020-205042) at /Users/hlebbeladzed/.cache/nvim-check-lock
  ok   e2e             36.6 s
  ok   specs            0.5 s
  ok   lint             1.1 s
  ok   trace            0.7 s
  ok   types            2.6 s
  ok   chain            6.3 s
  ok   smoke-health    14.5 s
  FAIL stack           35.6 s
  FAIL test           322.3 s
- review findings:
  No new findings. Pass 5 approved the branch code, and that code has not changed since. The only new commit is f2387530, a merge of auto. It brings in only openspec/changes/fix-remaining-flaky-tests/ (a queued proposal), which is outside this branch's diff against the new merge-base.
  [minor] Gate check-6.log line 778: `pr: Comments tab matches the approved render` (tests/screen/pr/test_comments.lua) failed once and passed on rerun (rerun-6-1.log). This change does not touch that file. All performance cases in tests/integration/file-tree/test_performance.lua passed (check-6.log:157-166).
  Carried over, still open: the pass 3 minors (the typecheck deadline record is tautological, test_typecheck.lua:24,62; the save-burst scenario wording does not describe the two-stage debounce advance; the vim.system override is not restored when no discovery runs) and the pass 5 minor (the unfold PERF wall sample includes up to one 20 ms poll, test_performance.lua:195-198).
  Checked with no finding: every edited file is listed in proposal Impact, no test was deleted or weakened, case names are unique, and the agent decisions agree with the spec and design.
- note: flaky test cases (failed, then passed on rerun): tests/screen/pr/test_comments.lua | pr: Comments tab matches the approved render
- note: loop: FAIL in tests/chain/shortcuts/test_chain.lua | shortcuts: zellij routes every shortcut as in the table: vim/_core/system:324: ENOENT: no such file or directory (cmd): '/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/worktrees/loop/deterministic-perf-tests/.tests/venv/bin/python'
- note: loop: FAIL in tests/integration/file-tree/test_performance.lua | file-tree: Unchanged git status does not redraw the project tree: tests/integration/file-tree/test_performance.lua:431: unchanged git status did not finish
- note: loop: FileNotFoundError: [Errno 2] No such file or directory: '/var/folders/9c/yg1yg4td727dkq_blbwbwn1w0000gn/T/tmptbvjg5xt/check-1.log'
- note: loop: ERROR: test_check_past_the_timeout_is_infra_with_its_log (test_gate_timeout.GateTimeout.test_check_past_the_timeout_is_infra_with_its_log)

- `tests/integration/lsp/test_typecheck.lua`; `lsp: Type-check toggle reattaches every Python buffer without reloading` still holds because only its wait budget changes, not the command or attachment assertions.
- `file-tree: Expanded ignored folder lists ignored children` still holds because manual debounce control changes when the existing callback runs, not ignored-folder expansion, colouring or git calls.
- `statusline: Statusline pull request component runs nothing on redraw` still holds because the shared wait and performance-test changes do not touch statusline redraw code.
- No plugin dependency is added, removed or upgraded. Core keymaps do not change.
- Out of scope: changing project-tree behavior or its numeric performance bounds, changing LSP behavior, and changing editor UI.
