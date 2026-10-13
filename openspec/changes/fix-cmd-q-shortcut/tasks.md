# Cmd+Q and Cmd+H Shortcut Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the already approved Cmd+Q/Cmd+H app-menu fix into current `auto` without losing either branch's shortcut behavior or coverage.

**Architecture:** Keep macOS menu-key configuration in one idempotent `terminal/` script, with the host Make target and the existing per-run sandbox guest restore invoking that same script. Test plist mutation in the chain layer and physical key delivery in the sandbox e2e layer; after the combined tree is green, merge the approved topic branch to preserve its history and resolve its archive move semantically.

**Tech Stack:** Bash, macOS `defaults`/`plutil`, Lua with mini.test, Swift/AppKit key helper, Make, OpenSpec, Git.

**Spec:** `openspec/changes/fix-cmd-q-shortcut/specs/shortcuts/spec.md`

## Global Constraints

- Cmd+Shift+Q remains system-owned and is never pressed by tests.
- Preserve current `auto` behavior and coverage for Cmd+Shift+-/=, Cmd+O/I/D/A, transient zellij retries, guest-state restore, sandbox locking and load-scaled deadlines.
- Neither Cmd+Q/Cmd+H nor Cmd+Shift+-/= may be excluded from the generic passed-shortcut e2e case.
- No existing scenario or test may be removed, skipped, xfailed or weakened to make the gate pass.
- Add, remove or upgrade no plugin dependency; use macOS built-ins and the existing shortcut harness.
- Make no core-keymap change beyond the approved Cmd+Q and Cmd+H behavior.
- Keep `PROVISION_REV` compatible with current `auto`: per-run `tests/sandbox/guest_restore.sh`, not stale one-time guest state, applies the checked-out branch's `terminal/macos_*.sh` scripts before e2e.

## Review Focus

- An existing `NSUserKeyEquivalents` entry could be overwritten; Task 1's idempotence case preserves `Minimize` and replaces only Quit/Hide.
- A prior checkout could leave stale menu keys in the shared VM; Task 1 retains the guest-reset and sync-before-restore mini.test cases.
- Cmd+Q/Cmd+H could reach Neovim while Alacritty is dead or hidden; Task 2 asserts process liveness and window visibility.
- A hand-maintained exception set could silently stop exercising Cmd+Q/Cmd+H or shifted folds; Task 2's generic case includes both groups and the dedicated cases still run.
- A controlled no-setup regression could contaminate later e2e cases; Task 3 restores the menu domain in guaranteed cleanup and reruns the provisioned cases afterward.

---

### Task 1: Versioned menu-key setup and guest restore

**Scenarios:**
- `Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H`
- `Menu key setup is idempotent and keeps other entries`
- `Guest restore drops Alacritty defaults the branch does not define`
- `Guest restore applies the branch's own terminal setup`
- `sandbox.sh e2e restores guest state after syncing and before the e2e layer`

**Files:**
- Modify: `openspec/specs/shortcuts/spec.md`
- Create: `tests/chain/shortcuts/test_menu_keys.lua`
- Create: `terminal/macos_menu_keys.sh`
- Modify: `Makefile`
- Verify: `tests/unit/shortcuts/test_sandbox.lua`
- Verify: `tests/sandbox/guest_restore.sh`
- Verify: `tests/sandbox/sandbox.sh`

**Interfaces:**
- Consumes: `tests/sandbox/guest_restore.sh [domain]`, which runs executable `terminal/macos_*.sh` files after resetting the domain.
- Produces: `terminal/macos_menu_keys.sh [domain]` (default `org.alacritty`) and `make menu-keys`.

- [x] **Step 1: Write the failing mini.test cases**

  Add the requirement and these exact cases to the main spec and `tests/chain/shortcuts/test_menu_keys.lua`:

  ```lua
  T["shortcuts: Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H"] = function()
    eq(read_equivalents(empty_plist), {
      ["Quit alacritty"] = "@~^q",
      ["Hide alacritty"] = "@~^h",
    })
  end

  T["shortcuts: Menu key setup is idempotent and keeps other entries"] = function()
    eq(second_run.code, 0)
    eq(read_equivalents(seed_plist), {
      ["Quit alacritty"] = "@~^q",
      ["Hide alacritty"] = "@~^h",
      Minimize = "@m",
    })
  end
  ```

- [x] **Step 2: Verify the new cases fail for the missing setup script**

  Run: `CASE='Menu key setup' make chain`

  Run separately: `make trace`

  Expected: the two named cases fail because `terminal/macos_menu_keys.sh` is absent; trace reports no orphan case.

- [x] **Step 3: Implement the minimal shared setup path**

  Port the approved topic implementation into `terminal/macos_menu_keys.sh [domain]`: use one `defaults write ... NSUserKeyEquivalents -dict-add` operation for `"Quit alacritty" = "@~^q"` and `"Hide alacritty" = "@~^h"`, preserving other dictionary entries. Add `make menu-keys`; do not add a second plist implementation or bump `PROVISION_REV` merely to carry checkout-specific state.

- [x] **Step 4: Verify setup and per-run restoration**

  Run: `CASE='Menu key setup' make chain`

  Run: `FILE=tests/unit/shortcuts/test_sandbox.lua make test-unit`

  Expected: all listed cases pass, including reset-without-script, apply-current-script, and sync → restore → e2e ordering.

- [x] **Step 5: Commit**

  ```bash
  git add Makefile terminal/macos_menu_keys.sh tests/chain/shortcuts/test_menu_keys.lua openspec/specs/shortcuts/spec.md
  git commit -m "fix(shortcuts): add versioned Alacritty menu keys"
  ```

---

### Task 2: Provisioned Cmd+Q/Cmd+H delivery and safe quit

**Scenarios:**
- `Every passed shortcut reaches its Neovim key from a real key press`
- `Consumed shortcuts never reach Neovim from a real key press`
- `Ctrl+Return reaches Neovim as <C-CR> from a real key press`
- `Cmd+Q reaches Neovim as <M-q> from a real key press`
- `Cmd+H moves to the left Neovim split from a real key press`
- `Cmd+H in a non-Neovim pane moves zellij focus left from a real key press`
- `Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press`
- `Cmd+Shift+- and Cmd+Shift+= close and open all folds from a real key press`
- `Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press`
- `Ctrl+Up grows the current Neovim split from a real key press`
- `Cmd+L at the rightmost Neovim split moves zellij focus right from a real key press`
- `Ctrl+H in a non-Neovim pane moves zellij focus left from a real key press`
- `Ctrl+Q quits zellij and closes the Alacritty window`
- `Cmd+Option+Control+Q quits Alacritty from a real key press`
- `Cmd+Shift+Q is never pressed: the key helper refuses it`

**Files:**
- Modify: `openspec/specs/shortcuts/spec.md`
- Modify: `tests/e2e/shortcuts/test_e2e.lua`
- Modify: `tests/e2e/alacritty.lua`
- Modify: `tests/e2e/keys.swift`
- Verify: `tests/sandbox/guest_restore.sh`

**Interfaces:**
- Consumes: `terminal/macos_menu_keys.sh [domain]` through the per-run guest restore from Task 1.
- Produces: `keys hidden <pid> -> true|false`, `E.hidden(stack: e2e.Stack) -> boolean`, and `E.preflight() -> reason: string?, fatal: boolean?`.

- [x] **Step 1: Write the failing mini.test cases**

  Apply the modified real-key requirement to the main spec. In `tests/e2e/shortcuts/test_e2e.lua`, add these exact cases and assertions, and remove Cmd+Q/Cmd+H and Cmd+Shift+-/= from the generic case's exception set:

  ```lua
  T["shortcuts: Cmd+Q reaches Neovim as <M-q> from a real key press"] = function()
    eq(hits, { "<M-q>" })
    eq(E.alive(s), true)
    eq(E.hidden(s), false)
  end
  T["shortcuts: Cmd+H moves to the left Neovim split from a real key press"] = function()
    eq(current_window(), left_window)
    eq(s:focused_pane(), NEOVIM_PANE)
    eq(E.hidden(s), false)
  end
  T["shortcuts: Cmd+H in a non-Neovim pane moves zellij focus left from a real key press"] = function()
    eq(s:focused_pane(), NEOVIM_PANE)
  end
  T["shortcuts: Cmd+Option+Control+Q quits Alacritty from a real key press"] = function()
    press_until_exit(fresh_stack, "cmd+ctrl+opt+q")
    eq(E.alive(fresh_stack), false)
  end
  ```

  Keep every current-auto recorder and dedicated Cmd+Shift+-/=, fold, Cmd+O/I/D/A, Ctrl, navigation and denylist case.

- [x] **Step 2: Verify the provisioned cases fail before harness support is ported**

  Run: `CASE='Cmd+Q reaches' make e2e E2E=1`

  Expected: the visibility/preflight-dependent cases fail because `keys hidden`, `E.hidden` and the fatal menu-state preflight are not implemented; no case is skipped.

- [x] **Step 3: Port the minimal e2e support**

  Add `hidden` to `tests/e2e/keys.swift` using `NSRunningApplication.isHidden`, wrap it as `E.hidden`, and make `E.preflight()` return a fatal reason when either exact menu equivalent is absent. In the e2e suite, treat that fatal result as a failure, retain existing load-scaled waits and Cmd+O/I/D/A recorders, and keep Cmd+Shift+Q in the denylist.

- [x] **Step 4: Verify the provisioned behavior and preserved coverage**

  Run: `make trace VERBOSE=1 && make e2e E2E=1`

  Expected: all Task 2 scenarios pass; the generic case exercises Cmd+Q, Cmd+H and Cmd+Shift+-/=; the dedicated shifted-fold and Cmd+O/I/D/A cases remain present and green; trace has zero orphans.

- [x] **Step 5: Commit**

  ```bash
  git add openspec/specs/shortcuts/spec.md tests/e2e/alacritty.lua tests/e2e/keys.swift tests/e2e/shortcuts/test_e2e.lua
  git commit -m "fix(shortcuts): deliver Cmd-Q and Cmd-H through Alacritty"
  ```

---

### Task 3: Controlled regressions, documentation and topic integration

**Scenarios:**
- `Cmd+H never reaches Neovim from a real key press`
- `Cmd+Q quits Alacritty from a real key press`
- `Every passed shortcut reaches its Neovim key from a real key press`

**Files:**
- Modify: `tests/e2e/shortcuts/test_e2e.lua`
- Modify: `docs/architecture.md`
- Modify: `docs/workflow.md`
- Modify: `docs/testing.md`
- Merge and resolve: `openspec/specs/shortcuts/spec.md`
- Archive on merge: `openspec/changes/archive/2026-10-13-fix-cmd-q-shortcut/`

**Interfaces:**
- Consumes: Task 1's setup script and Task 2's `E.hidden`, `E.preflight` and fresh-stack lifecycle.
- Produces: local `with_menu_keys_absent(fn: fun(stack: e2e.Stack))` test helper that always restores the menu setup after the callback, including on assertion failure.

- [x] **Step 1: Write the failing mini.test regressions**

  Update the two retained cases to use a deliberately absent menu setup and exact names:

  ```lua
  T["shortcuts: Cmd+H never reaches Neovim from a real key press"] = function()
    eq(E.events, {})
    eq(current_window(), right_window)
    eq(E.hidden(s), true)
  end
  T["shortcuts: Cmd+Q quits Alacritty from a real key press"] = function()
    press_until_exit(fresh_stack, "cmd+q")
    eq(E.alive(fresh_stack), false)
  end
  ```

- [x] **Step 2: Verify the controlled regressions fail without isolated menu-state handling**

  Run: `CASE='Cmd+H never' make e2e E2E=1`

  Run: `CASE='Cmd+Q quits' make e2e E2E=1`

  Expected: both cases fail because the provisioned guest has the setup applied and `with_menu_keys_absent` does not yet exist.

- [x] **Step 3: Isolate and restore the no-setup state**

  Implement `with_menu_keys_absent`: stop the active stack, remove only `NSUserKeyEquivalents`, start a fresh Alacritty instance for the callback, stop it, re-run `terminal/macos_menu_keys.sh`, and restore a provisioned stack in guaranteed cleanup. Assert the restored domain before returning so later cases cannot inherit the regression state.

- [x] **Step 4: Verify both old failures and the provisioned fix**

  Run: `make e2e E2E=1`

  Expected: controlled no-setup cases and provisioned cases all pass in the same run.

- [x] **Step 5: Reconcile operating documentation and validate the live change**

  Preserve current load-scaled deadlines and guest-restore wording while documenting `make menu-keys`, the required Alacritty relaunch, Cmd+Option+Control+Q, and why the app menu must release Cmd+Q/Cmd+H. Run `openspec validate fix-cmd-q-shortcut --strict` and `make check E2E=1`; both pass with zero missing or orphan shortcut scenarios.

- [ ] **Step 6: Merge the approved topic history and resolve semantically**

  Run `git merge --no-ff loop/fix-cmd-q-shortcut`. Resolve `docs/testing.md`, `openspec/specs/shortcuts/spec.md` and `tests/e2e/shortcuts/test_e2e.lua` by keeping the now-green combined versions: all current-auto scenarios/recorders, all approved menu-key scenarios, no generic exceptions for Cmd+Q/Cmd+H or Cmd+Shift+-/=, and both controlled no-setup regressions. Preserve the topic's `design.md` and archive move, update the archived proposal/spec/tasks to this final change, and leave no stale live `openspec/changes/fix-cmd-q-shortcut/` copy.

- [ ] **Step 7: Verify the merge result**

  Run: `git diff --check && ! git grep -nE '^(<<<<<<<|=======|>>>>>>>)' && make trace VERBOSE=1 && make check E2E=1`

  Expected: no conflict markers or whitespace errors; all topic and current-auto shortcut scenarios are tested; the complete gate is green.

## Workflow Follow-up

- On the host, run `make menu-keys`, then fully quit and relaunch Alacritty.
- Confirm the final merge commit is reachable from `auto`; never push.
