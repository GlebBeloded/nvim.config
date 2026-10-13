# Tasks: fix-git-status-map-shadowing (port onto `auto`)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the `git_status` tree, revert moves to `X`, the AI commit moves to `gc` with commit-check's async exit-code reporting, `gr` is the global Telescope `lsp_references` map and `c` is `copy`.

**Architecture:** Merge `loop/fix-git-status-map-shadowing` (mappings, tests, help screenshot) into this branch off `auto`. Keep `auto`'s async `vim.system` commit (`run_commit` / `on_commit_exit`) and rekey its tests from `c` to `gc` (design.md: Decisions, Port onto `auto`). Write the failing tests on `auto` first and commit them, then merge so that the tests turn green.

**Tech Stack:** Lua, neo-tree `git_status` mappings (`"none"`, `git_revert_file`, `{ fn, desc = ... }`), mini.test child Neovim (integration and screen layers), OpenSpec.

**Spec:** `openspec/changes/fix-git-status-map-shadowing/` (proposal.md Decision, design.md, specs/file-tree/spec.md)

## Global Constraints

- Keys: `X = "git_revert_file"`, `gr = "none"`, `gc = { git_commit, desc = "commit (AI)" }`, and no `c` entry in the `git_status` mappings, so the common `c = "copy"` applies.
- Revert confirms through neo-tree's own prompt `Are you sure you want to revert <name>?`. Add no custom confirmation code.
- Commit stays `auto`'s: `git commit -m <msg>` as an argument list via `vim.system`; `Committed: <subject>` at INFO and a refresh on exit 0, otherwise `Commit failed: <stderr>` at ERROR.
- Test names are exactly `"file-tree: <scenario title>"`. Never delete or weaken an assertion from `auto` or from the branch.
- Every commit test waits for its `Committed:` / `Commit failed:` note (`wait_note`) before it reads `git log`.
- No plugin added, removed or upgraded.

## Review Focus

- A failed commit must not refresh or report success. Pinned by "gc reports commit failure" (exactly one ERROR note, no `Committed:`, subject `init`).
- A message with shell metacharacters must reach git verbatim. Pinned by the second commit `fix: it's $HOME` in "gc commits confirmed message".
- A declined revert must keep the working-tree change. Pinned by "X keeps a file when revert is declined".
- `gcc` must not wait for `timeoutlen` after `gc`. neo-tree maps with `nowait`, so this needs no test: `gc` fires within the `wait_note` budget in Task 1.
- Glyph rows in the help screenshot differ between the branch base and `auto`. Task 1, step 6 regenerates and checks the screenshot.

---

### Task 1: Rekey git_status maps (X, gr, c, gc) by merging the branch

Scenarios: "X reverts a file after confirmation", "X keeps a file when revert is declined", "gr keeps its global meaning in git status tree", "c is copy in git status tree", "gc commits confirmed message", "gc reports commit failure", "Help lists the moved git status keys".

**Files:**
- Modify: `tests/integration/file-tree/test_tree.lua` (helpers and cases)
- Create (from branch): `tests/screen/file-tree/test_git_status_help.lua`, `tests/screenshots/tests-screen-file-tree-test_git_status_help.lua---file-tree--Help-lists-the-moved-git-status-keys`
- Modify (by merge): `lua/gleb/file_tree/init.lua` (`git_status.window.mappings`), `openspec/specs/file-tree/spec.md`, `tests/sandbox/sandbox.sh`, `tests/integration/file-tree/test_diff_preview.lua`
- Delete (merged in): `openspec/changes/archive/2026-10-13-fix-git-status-map-shadowing/`

**Interfaces:**
- Consumes `auto`'s test helpers `modified_repo()`, `commit_from_tree(dir, message)`, `last_subject(dir) -> string`, `wait_note(prefix) -> boolean` and `notes_with(prefix) -> table[]`, plus the branch's `git(dir, args) -> string`, `open_git_status(dir)` and `revert_with_answer(answer: "y"|"n")`.
- Produces the `git_status` mappings listed under Global Constraints.

Notes for the tests:
- Find `a.txt` with `vim.fn.search("a.txt")`, never with `j`: in this tree `j` opens a diff preview.
- Call `child.wait_very_lazy()` before reading the global `gr`. `open_git_status` already does this.

- [x] 1.1 Write the failing tests in `test_tree.lua` on `auto`:
  - Add the branch's helpers `git`, `open_git_status` and `revert_with_answer`, and its cases "file-tree: X reverts a file after confirmation", "file-tree: X keeps a file when revert is declined", "file-tree: gr keeps its global meaning in git status tree" and "file-tree: c is copy in git status tree", taken verbatim from `git show loop/fix-git-status-map-shadowing:tests/integration/file-tree/test_tree.lua`.
  - In `commit_from_tree`, press `gc` instead of `c` and update its doc comment.
  - Rename "file-tree: c commits confirmed message" to "file-tree: gc commits confirmed message". Keep all of its assertions, and press `gc` for the second commit. This case replaces the branch's `gc` case. The branch case's only assertions, the `Committed: feat: x` INFO note and the `feat: x` subject, are already in it, so the union adds nothing.
  - Rename "file-tree: c reports commit failure" to "file-tree: gc reports commit failure" without changing its assertions.
  - Add `tests/screen/file-tree/test_git_status_help.lua` and its reference screenshot from the branch (`git show loop/fix-git-status-map-shadowing:<path> > <path>`).
- [x] 1.2 Run `make test FILE=tests/integration/file-tree/test_tree.lua` and `make test FILE=tests/screen/file-tree/test_git_status_help.lua`. Expected: FAIL in the four X/gr/c cases, in both gc cases (on `auto`, `gc` is neo-tree's plain `git_commit`, so no `Committed:` note arrives) and in the help screenshot. The other 3 cases pass.
- [x] 1.3 Commit the failing tests: `git commit -m "test(file-tree): git_status keys X, gc, gr, c (failing)"`.
- [x] 1.4 Run `git merge --no-ff loop/fix-git-status-map-shadowing` and resolve:
  - `lua/gleb/file_tree/init.lua`: take `auto`'s whole file (async `run_commit`, glyphs, diagnostics) plus only the branch's mapping lines: `gc`, `X`, `gr = "none"`, and no `c`.
  - `tests/integration/file-tree/test_tree.lua`: keep the 1.1 version. Drop the branch's `gc commits confirmed message` body.
  - `openspec/specs/file-tree/spec.md`: `auto`'s spec with this change's delta applied. That means no `gr` in "Git status open, close and staging actions"; "Git status revert and key ownership"; "Git status AI commit" with its three scenarios; "Git status push". Everything else stays as on `auto`.
  - `tests/sandbox/sandbox.sh`: keep `auto`'s `sandbox_lock`, and drop `E2E_LOCK`, `lock_e2e` and its call.
  - `tests/integration/file-tree/test_diff_preview.lua`: `ASYNC_MS = 10000` with `auto`'s comment.
  - `git rm -r openspec/changes/archive/2026-10-13-fix-git-status-map-shadowing/`: ship's `openspec archive` recreates it.
- [x] 1.5 Run `make test FILE=tests/integration/file-tree/test_tree.lua`. Expected: all 9 cases PASS, and `grep -n '"file-tree: c ' tests/integration/file-tree/test_tree.lua` matches only "c is copy in git status tree".
- [x] 1.6 Run `make test FILE=tests/screen/file-tree/test_git_status_help.lua`. Expected: PASS, with the screenshot rows matching the Proposed render in design.md (apart from the header path). If `auto`'s glyphs change the tree rows, delete the reference, run once to write it, check it against the render, then run again. Expected: PASS.
- [x] 1.7 Run `openspec validate fix-git-status-map-shadowing --strict --no-interactive`. Expected: valid. Then run a trial `openspec archive fix-git-status-map-shadowing --yes` on a scratch copy of `openspec/`. Expected: the specs are already in sync, and `openspec validate --specs --strict` passes there.
- [x] 1.8 Commit the merge (`git commit`, keeping the default merge message plus `fix: fix-git-status-map-shadowing`).

### Task 2: Stale references and the gate

Scenarios: none new. This task checks that the Task 1 scenarios trace and that the full suite stays green, so it has no failing-test step.

**Files:**
- Modify: `openspec/changes/fill-trace-scenario-gaps/proposal.md:33`

- [ ] 2.1 Rename the entry "c commits confirmed message" to "gc commits confirmed message" in `fill-trace-scenario-gaps/proposal.md`. Verify with `grep -rn "c commits confirmed\|c reports commit failure" openspec tests | grep -v "changes/archive/"`. Expected: only this change's REMOVED/Migration text.
- [ ] 2.2 Run `make trace`. Expected: all 7 scenarios of this delta are `tested`, and there are no orphans.
- [ ] 2.3 Run `make check E2E=1`. Expected: green, with no case or scenario removed or weakened compared with `auto` or with the branch. Commit: `git commit -m "chore(openspec): gc rename in fill-trace-scenario-gaps"`.

## Workflow follow-up

- Ship runs `openspec archive fix-git-status-map-shadowing`. The main spec already holds the delta, so archiving only moves the change directory.
