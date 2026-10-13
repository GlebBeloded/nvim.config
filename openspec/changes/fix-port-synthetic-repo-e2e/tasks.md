# Synthetic Repository E2E Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the approved synthetic-repository LSP and Git e2e workflows on current `auto` while retaining both branches' later harness, sandbox, spec, and test behavior.

**Architecture:** Add the five archived mini.test cases first so current `auto` has a red baseline, then merge `loop/feat-20261012-232024` with `--no-ff` so its history remains an ancestor. Resolve the coupled harness and spec conflicts by composing the archived fixture options with current load handling, sandbox serialization/restoration, types, and newer scenarios; do not reimplement editor behavior.

**Tech Stack:** Lua, mini.test, Neovim RPC, Alacritty, zellij, tmux, POSIX shell, Git, Go 1.27.1, gopls 0.23.0, OpenSpec

**Spec:** `openspec/changes/fix-port-synthetic-repo-e2e/proposal.md`, `openspec/changes/fix-port-synthetic-repo-e2e/specs/lsp/spec.md`, `openspec/changes/fix-port-synthetic-repo-e2e/specs/git/spec.md`

## Global Constraints

- Merge `loop/feat-20261012-232024` into the current branch and preserve it as an ancestor; do not squash or cherry-pick it.
- Preserve every current `auto` improvement to stack retries, load-scaled deadlines, sandbox locking/restoration, type annotations, testing documentation, and all later scenarios.
- Preserve the archived fixture builder, all five e2e cases, quick-test routing, Go/gopls provisioning, archived change record, and queued `fix-lsp-references-current-line` change.
- Preserve `H.xfail("fix-lsp-references-current-line: gr drops the declaration under the cursor", ...)`; fixing that bug is out of scope.
- No plugin dependency is added, removed, or upgraded. Go 1.27.1 and gopls 0.23.0 are test-only sandbox tools.
- Core keymaps and visible UI are unchanged.
- Real key events run only through `make e2e` in the sandbox VM, never on the host.
- Synthetic e2e part 2, new languages or workflows, Differ staging/conflicts, neo-tree/codediff, diffview, PR review, screenshots, and unrelated refactoring are out of scope.

## Review Focus

- A Go references result that omits the declaration must remain the one approved `fix-lsp-references-current-line` xfail, while selecting `summary` still passes (Steps 1, 9).
- The dirty manifest must distinguish staged and unstaged `d.txt` entries and include the untracked file exactly once (Steps 1, 9).
- Fixture-specific cwd, environment, layout, and terminal size must coexist with load-scaled waits and transient zellij CLI retries (Steps 6, 8).
- Go/gopls provisioning must coexist with the cross-worktree sandbox lock and per-run guest restoration (Steps 7, 10).
- The combined LSP and Git specs must retain all current scenarios, and the archived history, queued bug, tests, and docs must not be dropped by an automatic merge resolution (Steps 4, 5, 10).

---

### Task 1: Reconcile the approved synthetic-repository workflows

Scenarios:

- `lsp: References of a Go function list call sites across packages`
- `lsp: Selecting a reference opens its file at the call site`
- `git: Cmd+G opens differ listing every change of a dirty repo`
- `git: ]f steps to the next changed file in differ`
- `git: ]c steps to the next hunk in differ`

**Files:**

- Create: `tests/e2e/lsp/test_go_references.lua`
- Create: `tests/e2e/git/test_differ_review.lua`
- Create: `tests/fixtures.lua`
- Create: `tests/fixtures/build.sh`
- Create: `openspec/changes/archive/2026-10-13-add-synthetic-repo-e2e/**`
- Create: `openspec/changes/fix-lsp-references-current-line/.openspec.yaml`
- Create: `openspec/changes/fix-lsp-references-current-line/proposal.md`
- Modify: `tests/shortcuts/stack.lua`
- Modify: `tests/e2e/alacritty.lua`
- Modify: `tests/e2e/shortcuts/test_e2e.lua`
- Modify: `tests/sandbox/sandbox.sh`
- Modify: `tests/quick.sh`
- Modify: `openspec/specs/lsp/spec.md`
- Modify: `openspec/specs/git/spec.md`
- Modify: `docs/testing.md`

**Interfaces:**

- Consumes: current `H.load_factor()`, `Stack:retry_cli(attempt)`, `Stack:query_focused_pane()`, `M.Stack`, `tests/sandbox/lock.sh`, `tests/sandbox/guest_restore.sh`, and every current LSP/Git scenario.
- Produces: `fixtures.go_env() -> table<string, string>`; `fixtures.copy(name: string, dest: string) -> string, fixtures.Manifest`; `tests/fixtures/build.sh <gomod|dirty> -> cache-directory`; `shortcuts.StackOpts`; `shortcuts.start(frontend?: shortcuts.Frontend, opts?: shortcuts.StackOpts) -> shortcuts.Stack`; `e2e.start(opts?: shortcuts.StackOpts) -> e2e.Stack`; `e2e.start_or_skip(opts?: shortcuts.StackOpts) -> e2e.Stack?, string?`.

- [x] **Step 1: Write the five failing mini.test cases with the exact scenario names**

  Add the archived case files before the fixture module and harness options. Keep their named helpers, RPC predicates, real-key input, and these exact assertions:

  ```lua
  T["lsp: References of a Go function list call sites across packages"] = H.xfail(CURRENT_LINE, function()
    local s = get()
    open_references(s)
    wait_picker(s, #manifest.references.Format)
    eq(sorted(s:lua(PICKER_ENTRIES, { root })), sorted(manifest.references.Format))
    eq(paths(manifest.references.Format), {
      "billing/invoice.go",
      "billing/invoice.go",
      "internal/money/money.go",
      "internal/money/money_test.go",
      "report/summary.go",
    })
  end)

  T["lsp: Selecting a reference opens its file at the call site"] = function()
    local s = get()
    ensure_references(s)
    local call = reference_in("report/summary.go")
    E.burst(s, function()
      E.press(s, { "s", "u", "m", "m", "a", "r", "y" })
      wait_picker(s, 1)
      E.press(s, "return")
      S.wait_for(function()
        return s:lua("return vim.bo.filetype") ~= "TelescopePrompt"
      end, "Telescope picker closed")
    end)
    eq(s:lua(CURRENT_FILE), {
      path = vim.uv.fs_realpath(root .. "/" .. call.path),
      line = call.line,
      col = call.col,
    })
  end

  T["git: Cmd+G opens differ listing every change of a dirty repo"] = function()
    local s = get()
    local entries = ensure_differ(s)
    eq(s:lua(PANEL_COLUMN), 1)
    eq(sorted(entries), sorted(manifest.files))
    eq(sorted_paths(paths(manifest.files)), { "a.txt", "b.txt", "d.txt", "d.txt", "lib/c.lua", "new.txt" })
  end

  T["git: ]f steps to the next changed file in differ"] = function()
    local s = get()
    local entries = ensure_differ(s)
    local view = wait_view(s)
    local first = s:lua(PANEL_CURRENT)
    s:lua(FOCUS_DIFF)
    local visited = { view.path }
    E.burst(s, function()
      for _ = 2, #entries do
        view = next_file(s, view)
        table.insert(visited, view.path)
      end
    end)
    eq(visited, rotated(paths(entries), first))
    eq(sorted_paths(visited), sorted_paths(paths(manifest.files)))
  end

  T["git: ]c steps to the next hunk in differ"] = function()
    local s = get()
    local entries = ensure_differ(s)
    local view = wait_view(s)
    s:lua(FOCUS_DIFF)
    E.burst(s, function()
      for _ = 1, #entries do
        if view.path == "b.txt" then break end
        view = next_file(s, view)
      end
    end)
    eq(view.path, "b.txt")
    s:lua(FOCUS_DIFF)
    local hunks = manifest.hunks["b.txt"]
    local state = s:lua(DIFF_STATE, hunks)
    s:lua("vim.api.nvim_win_set_cursor(...)", { state.win, { state.from_new[1], 0 } })
    E.burst(s, function()
      E.press(s, { "]", "c" })
      S.wait_for(function()
        return s:lua(DIFF_STATE, hunks).cursor == state.from_new[2]
      end, "cursor on the second hunk of b.txt")
    end)
    eq(s:lua(WINBAR, { state.win }):find("hunk 2/2", 1, true) ~= nil, true)
  end
  ```

  The helper calls above describe the assertions; restore their complete implementations from the approved files at commit `da29df2` rather than creating alternate abstractions.

- [x] **Step 2: Run the red baseline**

  Run: `make e2e CASE='lsp:'`

  Expected: FAIL during collection because `tests.fixtures` does not exist on current `auto`.

  Run: `make e2e CASE='git:'`

  Expected: FAIL during collection for the same missing module. A sandbox-down skip is not a red baseline; start the sandbox and rerun.

- [x] **Step 3: Include the restored cases in the green merge commit**

  The controlling invocation requires commits only when green. Observe both RED
  collection failures, remove the temporary untracked test copies, and bring the
  exact cases back through the approved-history merge in Step 4. Commit them only
  after the focused suites, `make fmt`, and `make quick` pass; no separate RED commit.

- [x] **Step 4: Merge the approved branch and preserve its history**

  Run: `git merge --no-ff loop/feat-20261012-232024`

  Resolve only the coupled files named below; accept clean additions from the archived branch. Complete the merge with a merge commit, then run:

  ```bash
  git merge-base --is-ancestor da29df2 HEAD
  ```

  Expected: exit 0.

- [x] **Step 5: Compose the capability specs without losing either side**

  In `openspec/specs/lsp/spec.md`, keep the current Purpose, diagnostic-sign requirement, and both diagnostic scenarios, then append the archived Go references requirement and its two scenarios. In `openspec/specs/git/spec.md`, keep every current requirement and scenario—including the Cmd conflict choices, empty Ollama output, and comment-line handling—and append the Differ review requirement and its three scenarios.

  Run: `openspec validate fix-port-synthetic-repo-e2e --strict && make trace`

  Expected: PASS; all five new titles are tested, no current scenario is orphaned, and no scenario from either parent is absent.

- [x] **Step 6: Compose the stack and Alacritty harness interfaces**

  In `tests/shortcuts/stack.lua`, add `StackOpts`, `self.opts`, resolved fixture `cwd`, merged `opts.env`, and `default|nvim` layouts to current `M.start(frontend, opts)` while retaining `table<string, string>` environment typing, `H.load_factor()` deadlines, transient zellij CLI retries, `query_focused_pane()`, and exported `M.Stack`. In `tests/e2e/alacritty.lua`, pass `opts` through `M.start`, honor optional columns/lines, add `M.start_or_skip(opts)`, and retain the `nvim_get_mode` liveness probe. Update `tests/e2e/shortcuts/test_e2e.lua` to use `start_or_skip()` while retaining all current shortcut scenarios.

  Run: `make stack && make types`

  Expected: PASS.

- [x] **Step 7: Compose fixture provisioning with sandbox isolation**

  Retain the archived `tests/fixtures.lua`, `tests/fixtures/build.sh`, Go 1.27.1 and gopls 0.23.0 provisioning, and `PROVISION_REV=4`. In `tests/sandbox/sandbox.sh`, also retain current `sandbox_lock` acquisition for every guest-mutating command and `restore_guest` after each sync. Retain the archived fixture and LSP/Git e2e triggers in `tests/quick.sh`.

  Run: `make sandbox-provision`

  Expected: PASS; the provisioned marker is revision 4 and `go version`/`gopls version` in the guest report the pinned versions.

- [x] **Step 8: Reconcile testing documentation and audit both parents**

  In `docs/testing.md`, retain current type-library dependencies, color helpers, load-scaled timing, sandbox locking, and guest restoration. Add the archived fixture layout and builder contract, fixture-triggered quick routing, pinned Go/gopls provisioning, and measured warm e2e time. Audit `git diff auto...HEAD` and both merge parents to confirm the archived change record, `fix-lsp-references-current-line`, fixture helpers, five cases, and every current test/scenario are present; keep the original archive as historical evidence.

  Run: `make quick`

  Expected: PASS, with e2e included when the sandbox is running.

- [x] **Step 9: Run the focused scenario suites**

  Run: `make e2e CASE='lsp:'`

  Expected: both LSP cases execute; selecting the reference passes and only `lsp: References of a Go function list call sites across packages` is the approved `fix-lsp-references-current-line` xfail.

  Run: `make e2e CASE='git:'`

  Expected: all three Differ cases pass.

- [x] **Step 10: Run the pass-local gate and commit any post-merge resolution fixes**

  The controlling invocation reserves `make check E2E=1` for the downstream gate;
  do not run the full gate in this implementation pass.

  Run the required focused suites from Steps 5–9, then `make fmt` and `make quick`
  before committing. Expected: PASS; e2e is serialized through the shared sandbox
  lock and no key event is posted on the host.

  If conflict-resolution fixes remain after the merge commit:

  ```bash
  git add docs/testing.md openspec tests
  git commit -m "fix: reconcile synthetic repository e2e"
  ```

  Finally rerun `git merge-base --is-ancestor da29df2 HEAD` and `git diff --check`; both must succeed.

## Workflow Follow-up

- Archive `fix-port-synthetic-repo-e2e` only after review confirms both parent histories' tests and scenarios are present.
- Merge the verified port into `auto`; do not recreate or delete `openspec/changes/archive/2026-10-13-add-synthetic-repo-e2e/`.
