# fix-mapleader-port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the approved, archived `fix-mapleader` branch on `auto` by a real merge, without losing `auto`'s debug-log `setup()`, sandbox and fold work, and pin the `init.lua` order with tests.

**Architecture:** Two pinning tests are written on the change branch first. Then `git merge loop/fix-mapleader` (tip `87ae8bc`) runs, and its three conflicts (`init.lua`, `openspec/specs/shortcuts/spec.md`, `tests/e2e/shortcuts/test_e2e.lua`) are resolved by keeping both sides. No new code beyond the conflict resolution.

**Tech Stack:** Neovim Lua config, lazy.nvim, mini.test (unit/integration), OpenSpec, sandbox-VM e2e.

**Spec:** `openspec/changes/fix-mapleader-port/` (proposal.md with the approval-gate feedback "keep both sides; keep nvim_debug_log.setup()", design.md, specs/keymaps, specs/nvim-debug-log). Chords, shortcut rows and branch tests are governed by `openspec/changes/archive/2026-10-13-fix-mapleader/` (arrives with the merge).

## Global Constraints

- `init.lua` order, verbatim: `vim.g.mapleader = " "` / `vim.g.maplocalleader = "\\"` block, then `require("gleb.nvim_debug_log").setup()`, then `require("gleb.plugins")`. Never the branch's bare `require("gleb.nvim_debug_log")`.
- The `fix-mapleader` Decision is not changed: no `<leader>` maps in the config, diffview conflict choices on `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`, `maplocalleader` stays `\`.
- No archived `fix-mapleader` artifact is edited; no commit of the branch is rewritten (merge, not cherry-pick or rebase).
- No plugin added, removed or upgraded; nothing under `terminal/` changes.
- Never delete or weaken a test or scenario from either side to get green.
- Out of scope: the `tests/unit/shortcuts/test_sandbox.lua` flake "A second sandbox lock waits for the first and says so" (rerun; queue a change if it keeps failing).

## Review Focus

- Branch side of `init.lua` taken by mistake → debug log silently off. Pinned by Task 1 (red against the branch's line).
- `setup()` called twice (e.g. both sides kept literally) → Task 2's test asserts the setup wrapper ran exactly once.
- A conflict hunk resolved by dropping one side in `test_e2e.lua` (fold case or its closing `end`, `OWN_CASE`, `CMD_CHORDS` / `CMD_CHORD_RECORDERS`) → Task 2 step 7 diffs against both parents.
- A requirement or scenario dropped from `openspec/specs/shortcuts/spec.md` → Task 2 step 6 counts scenarios against both parents and runs `openspec validate --specs --strict`.
- Stale load-order notes in `docs/architecture.md` (auto-merged, 146 commits old) → Task 2 step 9.

---

### Task 1: Full config starts the debug log

Scenarios: "nvim-debug-log: Full config starts the log".

**Files:**
- Test: `tests/integration/nvim-debug-log/test_debug_log.lua`

**Interfaces:**
- Consumes: existing locals in that file: `child`, `pid`, `expect_logged(needle)`, `log_file()`; `child.start_config()` from `tests/helpers.lua`.
- Produces: nothing for Task 2 beyond the green case.

- [x] **Step 1: Write the failing test**

```lua
T["nvim-debug-log: Full config starts the log"] = function()
	child.start_config()
	pid = child.fn.getpid()
	child.cmd('echom "FULL_CONFIG_LOG"')
	expect_logged("FULL_CONFIG_LOG")

	eq(vim.fs.basename(log_file()):match("^%d+_" .. pid .. "%.txt$") ~= nil, true)
end
```

- [x] **Step 2: Verify it fails for the expected reason**

`auto`'s `init.lua` already calls `setup()`, so prove the red against the branch's side: replace `require("gleb.nvim_debug_log").setup()` in `init.lua` with `require("gleb.nvim_debug_log")`.
Run: `make test FILE=tests/integration/nvim-debug-log/test_debug_log.lua CASE="Full config starts the log"`
Expected: FAIL with `expected log to contain "FULL_CONFIG_LOG"`.
Then `git checkout -- init.lua`.

- [x] **Step 3: Verify it passes on the real `init.lua`**

Run the same command. Expected: PASS. Then `make quick` green and `make trace` lists the scenario as tested.

- [x] **Step 4: Commit**

```bash
git add tests/integration/nvim-debug-log/test_debug_log.lua
git commit -m "test(nvim-debug-log): full config starts the log"
```

### Task 2: Merge loop/fix-mapleader, conflicts kept from both sides

Scenarios: "keymaps: Leader is set before the debug log starts", "keymaps: Leader values after startup", "keymaps: Leader is set before lazy.nvim loads plugins", "nvim-debug-log: Full config starts the log" (stays green), and every scenario the archived `fix-mapleader` adds or changes in `git` ("Diffview view mappings") and `shortcuts` ("Cmd chords reach Neovim through real zellij", "Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press"), plus `auto`'s fold case "Cmd+Shift+- and Cmd+Shift+= close and open all folds from a real key press".

**Files:**
- Test: `tests/integration/keymaps/test_keymaps.lua` (new case; the branch adds the lazy.setup hook and two leader cases here)
- Modify (merge resolution): `init.lua`, `openspec/specs/shortcuts/spec.md`, `tests/e2e/shortcuts/test_e2e.lua`
- Arrive with the merge: `lua/gleb/keymaps.lua`, `lua/gleb/git/diffview.lua`, `docs/architecture.md`, `openspec/specs/{keymaps,git}/spec.md`, `tests/integration/git/test_diffview.lua`, `tests/stack/shortcuts/test_stack.lua`, `openspec/changes/archive/2026-10-13-fix-mapleader/`
- Possibly modify: `docs/architecture.md` (step 9)

**Interfaces:**
- Consumes: `H.isolate()`, `H.config_args()`, `H.DISABLED_PLUGINS`, `child.disable_plugin`, `H.xfail(reason, case)` from `tests/helpers.lua`.
- Produces: in `test_keymaps.lua`, `RECORD_LEADER_AT_DEBUG_LOG_SETUP` (string, a `--cmd` Lua hook) and `start_recording_leader_at_debug_log_setup()`, shaped like the branch's `RECORD_LEADER_AT_LAZY_SETUP` / `start_recording_leader_at_lazy_setup()`.

- [x] **Step 1: Write the failing test**

`RECORD_LEADER_AT_DEBUG_LOG_SETUP`: a `lua package.preload["gleb.nvim_debug_log"] = function() … end` hook that clears its own preload entry, requires the real module, and wraps `setup` to append `vim.g.mapleader` to `_G.leaders_at_debug_log_setup` (create the table on first call) before calling the original. `start_recording_leader_at_debug_log_setup()` restarts the child with `vim.list_extend({ "--cmd", RECORD_LEADER_AT_DEBUG_LOG_SETUP }, H.config_args())` after `H.isolate()`, then disables `H.DISABLED_PLUGINS`.

```lua
T["keymaps: Leader is set before the debug log starts"] = H.xfail("fix-mapleader-port", function()
	start_recording_leader_at_debug_log_setup()

	eq(child.lua_get("_G.leaders_at_debug_log_setup"), { " " })
end)
```

Place it in the "Mapping options and leaders" area, where the branch adds "Leader is set before lazy.nvim loads plugins". `H.xfail` is there only so the red case can be committed before the merge; step 8 removes it.

- [x] **Step 2: Verify it fails for the expected reason**

Temporarily drop the `H.xfail(...)` wrapper. Run: `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Leader is set before the debug log starts"`
Expected: FAIL, equality of `{}` (leader still unset at `setup()` on `auto`) vs `{ " " }`. If it fails with `nil` instead, the hook never ran: fix the hook, not the assertion. Restore the wrapper; rerun; expected: skipped with `XFAIL: fix-mapleader-port`.

- [x] **Step 3: Commit**

```bash
git add tests/integration/keymaps/test_keymaps.lua
git commit -m "test(keymaps): leader is set before the debug log starts (xfail until merge)"
```

- [x] **Step 4: Merge**

Run: `git merge --no-ff --no-commit loop/fix-mapleader`
Expected: conflicts in exactly `init.lua`, `openspec/specs/shortcuts/spec.md`, `tests/e2e/shortcuts/test_e2e.lua`. If `tests/integration/keymaps/test_keymaps.lua` also conflicts, keep both sides' cases and helpers.

- [x] **Step 5: Resolve `init.lua`**

Top of file: the branch's comment and leader block, then `auto`'s comment and `require("gleb.nvim_debug_log").setup()`, then `require("gleb.plugins")`; the rest from the branch (its `gleb.keymaps` comment). No bare `require("gleb.nvim_debug_log")` left: `grep -c 'nvim_debug_log' init.lua` prints `1`.

- [x] **Step 6: Resolve `openspec/specs/shortcuts/spec.md`**

Keep `auto`'s requirements "Concurrent sandbox runs never share the guest" and "Test harness deadlines scale with host load" and the branch's "Cmd chords reach Neovim as <D-…>", every scenario under each, plus the Cmd+O/I/D/A table rows and `auto`'s "Known gaps" paragraph.
Verify: `grep -c '^#### Scenario:'` on the result equals the count on `auto` plus the scenarios only the branch adds (`git diff auto...loop/fix-mapleader -- openspec/specs/shortcuts/spec.md | grep -c '^+#### Scenario:'`); `openspec validate --specs --strict` passes.

- [x] **Step 7: Resolve `tests/e2e/shortcuts/test_e2e.lua`**

Keep `auto`'s fold fixture and case "Cmd+Shift+- and Cmd+Shift+= close and open all folds from a real key press" with its closing `end`, `auto`'s `OWN_CASE` (Cmd+Q, Cmd+H), and the branch's `CMD_CHORDS` / `CMD_CHORD_RECORDERS` and case "Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press".
Verify: `git diff auto -- tests/e2e/shortcuts/test_e2e.lua` and `git diff loop/fix-mapleader -- tests/e2e/shortcuts/test_e2e.lua` show no `-` line that is not re-added unchanged elsewhere; `make lint` passes.

- [x] **Step 8: Remove the xfail and verify the leader tests pass**

Unwrap `H.xfail("fix-mapleader-port", …)` from "keymaps: Leader is set before the debug log starts".
Run: `make test FILE=tests/integration/keymaps/test_keymaps.lua` and `make test FILE=tests/integration/nvim-debug-log/test_debug_log.lua`
Expected: PASS, including "Leader values after startup", "Leader is set before lazy.nvim loads plugins", "Leader is set before the debug log starts", "Full config starts the log".

- [x] **Step 9: Check the archive and the docs**

Verify `openspec/changes/fix-mapleader/` is gone and `git diff loop/fix-mapleader -- openspec/changes/archive/2026-10-13-fix-mapleader/` is empty. Reread the leader notes in `docs/architecture.md` (load order, rules 3.7/3.8); fix any statement that contradicts the resolved `init.lua` (leader, then debug-log `setup()`, then lazy.nvim).

- [ ] **Step 10: Full gate** (left to the gate after this pass, which runs it once)

Run: `make check E2E=1` (sandbox VM).
Expected: every layer green; e2e runs (not `skip`) and both the Cmd+O/I/D/A and fold cases pass; `make trace` reports no orphans.

- [x] **Step 11: Commit the merge**

```bash
git add -A init.lua openspec/specs/shortcuts/spec.md tests/e2e/shortcuts/test_e2e.lua tests/integration/keymaps/test_keymaps.lua docs/architecture.md
git commit -m "Merge loop/fix-mapleader: leader Space before debug-log setup, conflicts kept from both sides"
```

## Workflow follow-up

- Archive `fix-mapleader-port` after review; verify `openspec/specs/nvim-debug-log/spec.md` and `openspec/specs/keymaps/spec.md` hold the new scenarios.
